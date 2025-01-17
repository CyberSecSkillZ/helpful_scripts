#!/bin/bash

# Generate a date string for the output files
DATE_STRING=$(date +%Y%m)
OUTPUT_FILE="images-$DATE_STRING.txt"
FLAGGED_OUTPUT_FILE="flaggedImages-$DATE_STRING.txt"
LAST_RUN_FILE="last_run_images.txt"

# Clear the output files at the start
> "$OUTPUT_FILE"
> "$FLAGGED_OUTPUT_FILE"

# Create the last run file if it doesn't exist
if [ ! -f "$LAST_RUN_FILE" ]; then
    touch "$LAST_RUN_FILE"
fi

# Function to retrieve images from all EKS clusters
fetch_images_from_eks() {
    local CLUSTERS="$1"
    local CURRENT_DATE=$(date +%Y-%m-%d)

    # Loop through each cluster and fetch images
    for CLUSTER in $CLUSTERS; do
        echo "Fetching images from cluster: $CLUSTER" >> "$OUTPUT_FILE"
        
        # Set the context for kubectl
        kubectl config use-context "$CLUSTER" || { echo "Failed to set context for cluster: $CLUSTER" >> "$OUTPUT_FILE"; continue; }

        # Get all images from all namespaces and append to the output file
        kubectl get pods --all-namespaces -o jsonpath="{..image}" | tr -s '[[:space:]]' '\n' | sort -u | while read -r IMAGE; do
            echo "$IMAGE $CURRENT_DATE" >> "$OUTPUT_FILE"
            check_unchanged_images "$IMAGE" "$CURRENT_DATE"
        done
    done
}

# Function to check for unchanged images
check_unchanged_images() {
    local IMAGE_VERSION="$1"
    local LAST_RUN_DATE="$2"
    
    if grep -q "$IMAGE_VERSION" "$LAST_RUN_FILE"; then
        local LAST_DATE=$(grep "$IMAGE_VERSION" "$LAST_RUN_FILE" | awk '{print $2}')

        # Convert dates to seconds since epoch for comparison
        LAST_DATE_EPOCH=$(date -j -f "%Y-%m-%d" "$LAST_DATE" +"%s" 2>/dev/null)
        CURRENT_DATE_EPOCH=$(date -j -f "%Y-%m-%d" "$LAST_RUN_DATE" +"%s" 2>/dev/null)

        # Check if dates were parsed correctly
        if [[ -z "$LAST_DATE_EPOCH" || -z "$CURRENT_DATE_EPOCH" ]]; then
            echo "Error parsing dates: LAST_DATE='$LAST_DATE', CURRENT_DATE='$LAST_RUN_DATE'" >> "$OUTPUT_FILE"
            return
        fi

        # Calculate the difference in months
        local DIFF_MONTHS=$(( (CURRENT_DATE_EPOCH - LAST_DATE_EPOCH) / 2592000 ))

        if [ "$DIFF_MONTHS" -ge 3 ]; then
            echo "$IMAGE_VERSION $LAST_DATE" >> "$FLAGGED_OUTPUT_FILE"
            echo "Flagged unchanged image version: $IMAGE_VERSION (Last updated: $LAST_DATE)" >> "$OUTPUT_FILE"
        fi
    fi
}

# Specify the production account
PROFILE="proddnp"

echo "Processing profile: $PROFILE" >> "$OUTPUT_FILE"

# Get all EKS clusters in the production account
if ! CLUSTERS=$(aws eks list-clusters --profile "$PROFILE" --query "clusters" --output text); then
    echo "Error retrieving clusters for profile: $PROFILE" >> "$OUTPUT_FILE"
    exit 1
fi

# Check if CLUSTERS is empty
if [ -z "$CLUSTERS" ]; then
    echo "No EKS clusters found for profile: $PROFILE." >> "$OUTPUT_FILE"
    exit 1
fi

# Fetch images from all clusters
fetch_images_from_eks "$CLUSTERS"

# Create or update the last run images file
cp "$OUTPUT_FILE" "$LAST_RUN_FILE"

echo "All images and their versions have been saved to $OUTPUT_FILE."
echo "Flagged images have been saved to $FLAGGED_OUTPUT_FILE."
