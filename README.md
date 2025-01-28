
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
- **AWS CLI Credentials**: Ensure the instance has access to the required S3 bucket and log files.

---

## Installation and Setup

### Step 1: Install Docker on EC2

Run the following commands on your EC2 instance:
```bash
sudo dnf install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
```

**Note**: After adding the user to the `docker` group, log out and log back in for the changes to take effect.

---

### Step 2: Set Up AWS Credentials

Transfer your AWS credentials to the EC2 instance. For example:
```bash
scp -i emr-advisor.pem -r ~/.aws ec2-user@your-ec2-ip:/home/ec2-user/
```

---

### Step 3: Clone the Repository

Clone this repository to your working directory on the EC2 instance:
```bash
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
  -v $HOME/.aws:/root/.aws \
  -e BUCKET_NAME=emr-advisor-1234567890 \
  -e LOG_PATH=logs/ \
  emr-advisor
```

- Replace `BUCKET_NAME` with the name of your S3 bucket containing the logs.
- Replace `LOG_PATH` with the path to the logs in the bucket.

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
