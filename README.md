Handy scripts for inspecting container images and vulnerabilities in AWS cloud.

consolidate_Severe_vulns.py : Crawls all AWS accounts and locates ONLY High/Critical vulnerabilities.
- Explanation of PYTHON the Script:

    1) The script imports boto3 for AWS interactions and json for formatting output.
    2) It creates or clears the Severe_Vulns.txt file at the start.
    3) The script has a list for AWS account IDs where it will check for vulnerabilities.
    4) The check_image_vulnerabilities function:
       - Initializes a boto3 session.
       - Calls the Security Hub API to retrieve findings.
       - Filters the findings for those labeled as HIGH or CRITICAL severity.
    5) The main function iterates through the list of accounts, checks for vulnerabilities in each account, and writes any severe vulnerabilities found to the output file.
    6) The script is executed by calling the main function.

current_eks_version_check.sh : Crawls ALL AWS accounts and retrieves current EKS images, versions and meta data.
- Explanation of the SHELL Script:

    1) The script initializes an output file named current_eks_images.sh to store the image versions.
    2) Customized the PROFILES array with my actual AWS CLI profiles to iterate through different AWS accounts.
    3) The fetch_images_from_eks function:
        - Takes a profile name as an argument.
        - Lists all EKS clusters in the specified profile.
        - Updates the kubeconfig for each cluster.
        - Retrieves all unique images from all namespaces and appends them to the output file.
    4) The script loops through each profile in the PROFILES array and calls the fetch_images_from_eks function.
    5) A message is printed indicating that all images have been saved to the specified output file.

fetch_nonPatched_images.sh : Crawls production account  and fetches images that have not been updated in the past three months.
- Explanation of the SHELL Script:

    1) The script generates a date string in the format YYYYMM for the output filenames.
    2) Two output files are created:
       - images-YYYYMM.txt: This file stores the images and their versions along with the date they were fetched.
       - flaggedImages-YYYYMM.txt: This file contains flagged images that have not changed in three months.
    3) If last_run_images.txt does not exist, the script creates it.
    4) This function retrieves all unique images from the specified EKS clusters. It uses kubectl config use-context to set the context for each cluster.
    5) This function checks if an image version exists in the last_run_images.txt file and flags it if it hasn’t changed in three months.
    6) The script is configured to work with the profile named "prod" to list all EKS clusters in that account.
    7) For each cluster, it fetches images and logs the current date.
    8) At the end, the output file is copied to last_run_images.txt.
    9) The script logs where the images and flagged images have been saved.

inspect_4_zoneTakeOver.sh : Crawls all AWS accounts to detect if they are vulnerable to the "Zone Take Over" flaw.
- Explanation of the SHELL script:

    1) The script initializes the output file flagged_resources.txt and clears its content.
    2) It retrieves all AWS profiles and loops through each profile to perform the checks.
    3) The script lists public hosted zones and extracts Zone IDs.
    4) For each hosted zone, it fetches resource record sets, filtering for A records, S3, and Elastic Beanstalk entries.
    5) It checks if S3 buckets exist for records pointing to S3 URLs.
    6) The script flags any records containing elasticbeanstalk.com.
    7) The check_ip_in_use function checks if an IP is associated with any EC2 instances or Load Balancers.
    8) If an IP is not in use, it performs a WHOIS lookup and flags it if it meets the specified criteria.
    9) The flagged information, including the IP, hosted zone, record name, and profile, is saved to the flagged_resources.txt file.
    10) At the end of execution, the script outputs a message indicating where the flagged resources have been saved.
