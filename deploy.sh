#!/bin/bash

# Set paths
CSV_FILE="/home/Mgd-IdP/schools.csv"
ANSIBLE_PLAYBOOK="/home/Mgd-IdP/mgd-idp-automation.yml"
INVENTORY="/home/Mgd-IdP/inventory.ini"
GENERATED_DIR="/home/Mgd-IdP/generated"
DOCKER_BASE_DIR="/home/Mgd-IdP"
SPLIT_DIR="/home/Mgd-IdP/split_csv"
SOURCE_DIR="/home/Mgd-IdP"  # Directory containing required files

# Start port mappings (increments for each container)
START_PORT1=3000
START_PORT2=4000
CONTAINER_COUNT=1  # Start numbering containers from 1

# Ensure required directories exist
mkdir -p "$SPLIT_DIR" "$GENERATED_DIR"

# ✅ Extract the header from the original CSV
HEADER=$(head -n 1 "$CSV_FILE")

# ✅ Split the CSV into smaller files (excluding the header in splits)
echo "📝 Splitting CSV into batches..."
tail -n +2 "$CSV_FILE" | split -l 50 --additional-suffix=.csv - "$SPLIT_DIR/schools_"

# ✅ Add the header back to each split file
for file in "$SPLIT_DIR"/schools_*.csv; do
    sed -i "1i$HEADER" "$file"
done

# Process one batch at a time
for file in "$SPLIT_DIR"/schools_*.csv; do
    BASENAME=$(basename "$file" .csv)
    BATCH_DIR="$GENERATED_DIR/$BASENAME"
    DOCKER_DIR="/home/Mgd-IdP/docker_builds/$BASENAME"

    echo "🚀 Processing batch: $BASENAME"

    # ✅ Ensure batch directory exists
    rm -rf "$BATCH_DIR" "$DOCKER_DIR"
    mkdir -p "$BATCH_DIR" "$DOCKER_DIR"

    # ✅ Copy required files for this batch from /home/Mgd-IdP
    echo "📂 Copying required base files to $BATCH_DIR..."
    cp "$SOURCE_DIR/proxy.conf" "$BATCH_DIR/"
    cp "$SOURCE_DIR/ldap" "$BATCH_DIR/"
    cp "$SOURCE_DIR/eduroam" "$BATCH_DIR/"
    cp "$SOURCE_DIR/eduroam-inner-tunnel" "$BATCH_DIR/"

    # ✅ Run Ansible playbook for this batch
    echo "🔄 Running Ansible for batch: $BASENAME..."
    ansible-playbook -i "$INVENTORY" "$ANSIBLE_PLAYBOOK" --extra-vars "csv_file_path=$file batch_name=$BASENAME"

    # ✅ Verify that required files were successfully generated
    REQUIRED_FILES=("proxy.conf" "ldap" "eduroam" "eduroam-inner-tunnel")
    MISSING_FILES=0
    for FILE in "${REQUIRED_FILES[@]}"; do
        if [[ ! -f "$BATCH_DIR/$FILE" ]]; then
            echo "❌ Missing $FILE in $BATCH_DIR. Skipping batch $BASENAME."
            MISSING_FILES=1
            break
        fi
    done

    # Skip Docker container creation if any required file is missing
    if [[ $MISSING_FILES -eq 1 ]]; then
        continue
    fi

    # ✅ Copy generated files to the Docker build directory
    cp "$BATCH_DIR"/* "$DOCKER_DIR/"

    # ✅ Copy static Docker configuration files
    cp "$DOCKER_BASE_DIR/Dockerfile" "$DOCKER_DIR/"
    cp "$DOCKER_BASE_DIR/ca.cnf" "$DOCKER_DIR/"
    cp "$DOCKER_BASE_DIR/client.cnf" "$DOCKER_DIR/"
    cp "$DOCKER_BASE_DIR/server.cnf" "$DOCKER_DIR/"
    cp "$DOCKER_BASE_DIR/eap" "$DOCKER_DIR/"
    cp "$DOCKER_BASE_DIR/clients.conf" "$DOCKER_DIR/"

    # ✅ Assign a sequential container name: mgd-idp-1, mgd-idp-2, mgd-idp-3, ...
    CONTAINER_NAME="mgd-idp-${CONTAINER_COUNT}"
    echo "🌐 Assigning ports: Host $START_PORT1 → Container 1812, Host $START_PORT2 → Container 1813"

    # ✅ Build and run the Docker container
    docker build -t "$CONTAINER_NAME" "$DOCKER_DIR"
    docker run -d --name "$CONTAINER_NAME" -p "$START_PORT1:1812/udp" -p "$START_PORT2:1813/udp" "$CONTAINER_NAME"

    echo "✅ Container $CONTAINER_NAME is running on ports $START_PORT1 and $START_PORT2."

    # ✅ Increment for the next container
    ((START_PORT1++))
    ((START_PORT2++))
    ((CONTAINER_COUNT++))

done

echo "🎉 All institutions deployed successfully!"

