#!/bin/bash

# Output file for flagged resources
OUTPUT_FILE="flagged_resources.txt"
# Clear the output file at the start
> "$OUTPUT_FILE"

# Function to check if an IP is in use
check_ip_in_use() {
    local IP="$1"
    # Check EC2 instances
    EC2_CHECK=$(aws ec2 describe-instances --filters "Name=private-ip-address,Values=$IP" --query "Reservations[*].Instances[*].[InstanceId]" --output text)
    # Check Load Balancers
    ELB_CHECK=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(DNSName, '$IP')].{DNSName: DNSName}" --output text)

    if [[ -n "$EC2_CHECK" || -n "$ELB_CHECK" ]]; then
        return 0 # IP is in use
    else
        return 1 # IP is not in use
    fi
}

# Function to check if an S3 bucket exists
check_s3_bucket_exists() {
    local BUCKET_NAME="$1"
    # Try to get the bucket location; if it succeeds, the bucket exists
    aws s3api get-bucket-location --bucket "$BUCKET_NAME" > /dev/null 2>&1
    return $?
}

# Get all profiles from AWS config
PROFILES=$(aws configure list-profiles)

# Loop through each profile
for PROFILE in $PROFILES; do
    echo "Checking hosted zones for profile: $PROFILE"
    
    # Collect all public hosted zones and extract ZoneId
    HOSTED_ZONES=$(aws route53 list-hosted-zones --profile "$PROFILE" --query "HostedZones[?Config.PrivateZone==\`false\`].Id" --output text)

    # Check if HOSTED_ZONES is empty
    if [ -z "$HOSTED_ZONES" ]; then
        echo "No public hosted zones found for profile: $PROFILE."
        continue
    fi

    # Initialize an indexed array to hold records
    RECORDS=()

    # Loop through each hosted zone
    for ZONE_ID in $HOSTED_ZONES; do
        # Get all resource record sets for the current hosted zone
        RECORD_SETS=$(aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" --profile "$PROFILE" --query "ResourceRecordSets[].[Name, Type, ResourceRecords]" --output text)

        # Check if RECORD_SETS is empty
        if [ -z "$RECORD_SETS" ]; then
            echo "No resource record sets found for zone: $ZONE_ID in profile: $PROFILE."
            continue
        fi

        # Loop through each record set
        while read -r NAME TYPE RECORD_ARRAY; do
            # Check for A records, S3, or Elastic Beanstalk
            if [[ "$TYPE" == "A" || "$NAME" == *".s3."* || "$NAME" == *"elasticbeanstalk"* ]]; then
                # Store the record information as a single line entry
                RECORDS+=("$ZONE_ID|$NAME|$RECORD_ARRAY")
                
                # Check S3 bucket existence if the record points to S3
                if [[ "$NAME" == *"s3.amazonaws.com"* || "$NAME" == *"s3-website"* ]]; then
                    BUCKET_NAME=$(echo "$NAME" | awk -F'.' '{print $1}') # Extract the bucket name
                    if ! check_s3_bucket_exists "$BUCKET_NAME"; then
                        echo "S3 bucket: $BUCKET_NAME does not exist for record: $NAME in profile: $PROFILE." >> "$OUTPUT_FILE"
                    fi
                fi

                # Flag Elastic Beanstalk records
                if [[ "$NAME" == *"elasticbeanstalk.com"* ]]; then
                    echo "Flagged Elastic Beanstalk record: $NAME in Zone: $ZONE_ID for profile: $PROFILE." >> "$OUTPUT_FILE"
                fi
            fi
        done <<< "$RECORD_SETS"
    done

    # Loop through each record and check IP usage
    for RECORD in "${RECORDS[@]}"; do
        IFS='|' read -r ZONE_ID NAME RECORD_ARRAY <<< "$RECORD"
        for IP in $RECORD_ARRAY; do
            if ! check_ip_in_use "$IP"; then
                # If IP is not in use, perform WHOIS lookup
                WHOIS_OUTPUT=$(whois "$IP")
                if echo "$WHOIS_OUTPUT" | grep -q -E "NetName:.*AMAZON-EC2-5|OrgName:.*Amazon.com , Inc."; then
                    # Record flagged information
                    echo "Flagged IP: $IP in Zone: $ZONE_ID with Record Name: $NAME for follow-up in profile: $PROFILE." >> "$OUTPUT_FILE"
                fi
            fi
        done
    done
done

echo "Flagged resources have been saved to $OUTPUT_FILE."
