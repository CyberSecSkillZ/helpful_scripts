import boto3
import json
import os

# Output file for severe vulnerabilities
output_file = "Severe_Vulns.txt"

# Clear the output file at the start
with open(output_file, 'w') as f:
    f.write("")

# List of AWS accounts (update with your actual account IDs)
accounts = [
    '123456789012',  # Replace with actual account IDs
    '987654321098'
]

def check_image_vulnerabilities(account_id):
    session = boto3.Session(profile_name='default')  # Use your AWS CLI profile
    client = session.client('securityhub', region_name='us-east-1')  # Specify the region

    # Get findings from Security Hub
    findings = []
    try:
        response = client.get_findings()
        findings = response['Findings']
    except Exception as e:
        print(f"Error retrieving findings for account {account_id}: {str(e)}")
        return []

    # Filter for high and critical vulnerabilities
    severe_vulns = []
    for finding in findings:
        if 'Severity' in finding and finding['Severity']['Label'] in ['HIGH', 'CRITICAL']:
            severe_vulns.append(finding)

    return severe_vulns

def main():
    all_severe_vulns = []

    for account_id in accounts:
        print(f"Checking vulnerabilities for account: {account_id}")
        severe_vulns = check_image_vulnerabilities(account_id)
        all_severe_vulns.extend(severe_vulns)

    # Write severe vulnerabilities to output file
    with open(output_file, 'a') as f:
        for vuln in all_severe_vulns:
            f.write(json.dumps(vuln, indent=2) + "\n")

    if all_severe_vulns:
        print(f"Severe vulnerabilities found and saved to {output_file}.")
    else:
        print("No severe vulnerabilities found.")

if __name__ == "__main__":
    main()
