
# EMR Advisor Containerized

## Overview

This repository provides a containerized solution for the [AWS EMR Advisor](https://github.com/aws-samples/aws-emr-advisor/tree/main), an existing tool designed to analyze Amazon EMR logs, providing users with insights and recommendations to enable informed decision-making for cost optimization and improved efficiency.

---

## Why Containerize?

The current solution, AWS EMR Advisor, has prerequisites and dependencies such as SBT (Scala Build Tool with Java 17) and Apache Spark. Typically, it is designed to run on an EMR cluster, requiring users to manage and configure these dependencies in the cluster environment.

This containerized approach simplifies the process by packaging all necessary dependencies into a self-contained Docker image, eliminating the need to set up or run an EMR cluster for log analysis. It provides an easy-to-use, portable solution that can be deployed on any platform that supports Docker. 

---

## Requirements

- **EC2 Instance**: Recommended instance type with at least 25 GB disk space.
- **Access to S3**: The instance must have read and write access to the S3 bucket and the log files within it. (Refer step 2 below)

---



### Step 1: Set Up AWS Permissions to Access S3 Bucket

Use an IAM Role: If your EC2 instance has an IAM role attached, ensure the role has sufficient permissions to access the S3 bucket containing the logs. Refer [AWS documentation](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/allow-ec2-instances-write-access-to-s3-buckets-in-ams-accounts.html) for more details.

Optional - In your AWS CloudShell, run the shell script to setup an IAM role with S3 read/write access for an EC2 instance, passing the EC2 instance ID and S3 bucket name as parameters:
```bash
git clone https://github.com/chitreshsaxena/emr-advisor-containerized.git
cd emr-advisor-containerized
chmod +x setup-s3-access-role.sh
./setup-s3-access-role.sh <INSTANCE_ID> <S3_BUCKET_NAME>

```
---

## Installation and Setup on EC2

### Step 2: Install Docker on EC2

Run the following commands on your EC2 instance:
```bash
sudo dnf install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
```

**Note**: After adding the user to the `docker` group, log out and log back in for the changes to take effect.

---
### Step 3: Clone the Repository

Clone this repository to your working directory on the EC2 instance:
```bash
sudo yum install git -y
git clone https://github.com/chitreshsaxena/emr-advisor-containerized.git
cd emr-advisor-containerized
```

---

### Step 4: Build the Docker Image

Build the Docker image using the provided `Dockerfile`:
```bash
sudo docker build -t emr-advisor .
```

---

### Step 5: Run the Container

Run the container to analyze EMR logs:
```bash
docker run --rm \
  -e BUCKET_NAME=your-existing-bucket-name \
  -e LOG_PATH=path/to/logs/ \
  emr-advisor

```

Parameters:
- BUCKET_NAME: The name of your existing S3 bucket where logs are stored and where the output will be saved.
- LOG_PATH: The path within your S3 bucket where the log files are located.


- Replace `BUCKET_NAME` with the name of your S3 bucket containing the logs.
- Replace `LOG_PATH` with the path to the logs in the bucket. E.g. emr-logs/cluster-j-123456ABCDEF

---

## Output

The analyzed HTML reports are uploaded to the S3 bucket under the `emr_advisor_output` folder. You can verify the reports using the AWS CLI:
```bash
aws s3 ls s3://emr-advisor-1234567890/emr_advisor_output/ --recursive
```

---

## Notes

- Ensure your EC2 instance has sufficient disk space (at least 25 GB recommended) for Docker and temporary files.
- This containerized solution is built for environments where EMR logs are stored in S3 and need analysis without complex local setups.

---

## License

This project is licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

---

For any issues or contributions, feel free to submit a pull request or open an issue in this repository.
