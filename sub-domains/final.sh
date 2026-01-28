#!/usr/bin/env bash
# Duplicate each CSV row into a "students" row (CSV-safe, handles quoted fields).
# - Domain     -> prefix with "students."
# - Split      -> "~.+\\\.students\\\.<domain-with-\\\.>$" (double backslashes)
# - LDAP_Name  -> append "-students"
# - Base_DN    -> insert "dc=students," immediately after "ou=people,"
# - School     -> append " students" (e.g., "St Marys College Kisubi students")
# - Other columns remain unchanged
#
# Usage:
#   ./add_student_rows_full_csvsafe.sh input.csv > output.csv
#
# Requires: gawk (GNU awk) for FPAT-based CSV parsing.

set -euo pipefail

INPUT="${1:-}"
if [[ -z "$INPUT" ]]; then
  echo "Usage: $0 input.csv > output.csv" >&2
  exit 1
fi

if ! command -v gawk >/dev/null 2>&1; then
  echo "This script requires gawk. Install it (e.g., sudo apt-get install gawk or brew install gawk)." >&2
  exit 2
fi

gawk '
BEGIN {
  # Proper CSV parsing: fields are quoted strings or unquoted tokens without commas
  FPAT = "([^,]*)|(\"([^\"]|\"\")*\")"
  OFS = ","
  IGNORECASE = 1
}

function trim(s) { sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s }
function unquote(s,   t) {
  t = trim(s)
  if (t ~ /^"/ && t ~ /"$/) { t = substr(t, 2, length(t)-2); gsub(/""/, "\"", t) }
  return t
}
function csv_quote(s,   r) {
  r = s; gsub(/"/, "\"\"", r)
  if (r ~ /[,\n"]/ ) return "\"" r "\""
  return r
}
function canon(h,   t) { t = tolower(unquote(h)); gsub(/[ _-]/, "", t); return t }

NR==1 {
  # Map header names (case-insensitive; spaces/underscores/hyphens ignored)
  for (i=1; i<=NF; i++) { hdr[i]=$i; name2idx[canon($i)] = i }

  # Required columns
  if (!("domain" in name2idx) || !("split" in name2idx) || !("ldapname" in name2idx)) {
    printf("ERROR: Missing required headers. Need Domain, Split, LDAP_Name\n") > "/dev/stderr"; exit 2
  }
  dom_i    = name2idx["domain"]
  split_i  = name2idx["split"]
  ldapnm_i = name2idx["ldapname"]

  # Optional columns we enhance if present
  base_i   = ( "basedn"  in name2idx ? name2idx["basedn"]  : 0 )
  school_i = ( "school"  in name2idx ? name2idx["school"]  : 0 )

  # Print header exactly as-is
  out = hdr[1]; for (i=2; i<=NF; i++) out = out OFS hdr[i]; print out; next
}

{
  # Unquote all fields for safe manipulation
  for (i=1; i<=NF; i++) vals[i] = unquote($i)

  # Emit original row unchanged
  out = csv_quote(vals[1]); for (i=2; i<=NF; i++) out = out OFS csv_quote(vals[i]); print out

  dom = trim(vals[dom_i])
  if (dom == "" || dom ~ /^students[.]/) next

  # Duplicate into b[]
  for (i=1; i<=NF; i++) b[i] = vals[i]

  # Domain -> students.<domain>
  students_dom = "students." dom
  b[dom_i] = students_dom

  # Split -> "~.+\\\.students\\\.<escaped>$" (double backslashes)
  esc = dom
  gsub(/\./, "\\\\.", esc)               # dot => \\\\.
  b[split_i] = "~.+\\\\.students\\\\." esc "$"

  # LDAP_Name -> append -students if not already present
  ldapn = vals[ldapnm_i]
  if (ldapn !~ /-students$/) ldapn = ldapn "-students"
  b[ldapnm_i] = ldapn

  # Base_DN -> insert dc=students, after ou=people,
  if (base_i > 0) {
    bd = vals[base_i]
    if (bd !~ /(^|,)dc=students(,|$)/) {
      if (bd ~ /^ou=people,/) {
        b[base_i] = "ou=people,dc=students," substr(bd, length("ou=people,")+1)
      } else if (match(bd, /,dc=[^,]+/)) {
        b[base_i] = substr(bd, 1, RSTART-1) ",dc=students" substr(bd, RSTART)
      } else {
        b[base_i] = bd ",dc=students"
      }
    }
  }

  # School -> append " students"
  if (school_i > 0) {
    sc = trim(vals[school_i])
    if (sc !~ /[[:space:]]students$/i) sc = sc " students"
    b[school_i] = sc
  }

  # Emit students row
  out2 = csv_quote(b[1]); for (i=2; i<=NF; i++) out2 = out2 OFS csv_quote(b[i]); print out2
}
' "$INPUT"
