#!/bin/bash

# === CONFIGURATION ===
CSV_DIR="/home/Mgd-IdP/split_csv"  # Directory with CSV files
CONFIG_FILE="/etc/radsecproxy.conf"

# Backup original config file
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Ordered list of CSV → RADIUS server
declare -A SERVER_MAP
SERVER_MAP["schools_aa.csv"]="radius1.mgd-idp.renu.ac.ug"
SERVER_MAP["schools_ab.csv"]="radius2.mgd-idp.renu.ac.ug"
SERVER_MAP["schools_ac.csv"]="radius3.mgd-idp.renu.ac.ug"
SERVER_MAP["schools_ad.csv"]="radius4.mgd-idp.renu.ac.ug"
SERVER_MAP["schools_ae.csv"]="radius5.mgd-idp.renu.ac.ug"
SERVER_MAP["schools_af.csv"]="radius6.mgd-idp.renu.ac.ug"

# Define the order explicitly
ordered_files=(
    "schools_aa.csv"
    "schools_ab.csv"
    "schools_ac.csv"
    "schools_ad.csv"
    "schools_ae.csv"
    "schools_af.csv"
)

# Loop through files in the defined order
for CSV_FILE in "${ordered_files[@]}"; do
    RADIUS_SERVER="${SERVER_MAP[$CSV_FILE]}"
    FULL_PATH="$CSV_DIR/$CSV_FILE"
    SERVER_LABEL=$(echo "$RADIUS_SERVER" | cut -d. -f1)  # e.g., mgd-idp-1

    if [[ -f "$FULL_PATH" ]]; then
        echo "Processing $CSV_FILE → $RADIUS_SERVER"

        # Find 'Domain' column index
        DOMAIN_COL_INDEX=$(head -1 "$FULL_PATH" | tr ',' '\n' | grep -in '^Domain$' | cut -d: -f1)

        if [[ -z "$DOMAIN_COL_INDEX" ]]; then
            echo "❌ 'Domain' column not found in $CSV_FILE. Skipping..."
            continue
        fi

        {
            echo ""
            echo "# ==========================="
            echo "# Start of $SERVER_LABEL Domains"
            echo "# ==========================="
        } >> "$CONFIG_FILE"

        tail -n +2 "$FULL_PATH" | while IFS=, read -ra FIELDS; do
            DOMAIN="${FIELDS[$((DOMAIN_COL_INDEX - 1))]}"
            DOMAIN=$(echo "$DOMAIN" | xargs)  # Trim whitespace

            [[ -z "$DOMAIN" ]] && continue

            {
                echo ""
                echo "realm $DOMAIN {"
                echo "    server $RADIUS_SERVER"
                echo "}"
            } >> "$CONFIG_FILE"

        done

        {
            echo ""
            echo "# ==========================="
            echo "# End of $SERVER_LABEL Domains"
            echo "# ==========================="
            echo ""
        } >> "$CONFIG_FILE"

    else
        echo "⚠️  Warning: '$FULL_PATH' not found, skipping..."
    fi
done

echo "✅ All realms processed in order and added to $CONFIG_FILE"

