#!/bin/bash

# Output file to store all image versions
OUTPUT_FILE="current_eks_images.sh"

# Clear the output file at the start
> "$OUTPUT_FILE"

# Array of AWS profiles (you can customize this with your account profiles)
PROFILES=("profile1" "profile2" "profile3") # Replace with your actual profile names

# Function to fetch images from all EKS clusters in a given profile
fetch_images_from_eks() {
    local PROFILE="$1"
    echo "Processing profile: $PROFILE" >> "$OUTPUT_FILE"

    # Get all EKS clusters in the account
    if ! CLUSTERS=$(aws eks list-clusters --profile "$PROFILE" --query "clusters" --output text); then
        echo "Error retrieving clusters for profile: $PROFILE" >> "$OUTPUT_FILE"
        return
    fi

    # Check if CLUSTERS is empty
    if [ -z "$CLUSTERS" ]; then
        echo "No EKS clusters found for profile: $PROFILE." >> "$OUTPUT_FILE"
        return
    fi

    # Loop through each cluster and fetch images
    for CLUSTER in $CLUSTERS; do
        echo "Fetching images from cluster: $CLUSTER" >> "$OUTPUT_FILE"
        
        # Update kubeconfig for the cluster
        aws eks update-kubeconfig --name "$CLUSTER" --profile "$PROFILE" >> "$OUTPUT_FILE" 2>&1
        
        # Get all images from all namespaces and append to the output file
        kubectl get pods --all-namespaces -o jsonpath="{..image}" | tr -s '[[:space:]]' '\n' | sort -u >> "$OUTPUT_FILE"
    done
}

# Iterate through all profiles and fetch images
for PROFILE in "${PROFILES[@]}"; do
    fetch_images_from_eks "$PROFILE"
done

echo "All images have been saved to $OUTPUT_FILE."
