
# EMR Advisor Containerized

## Overview

This repository provides a containerized solution for the [AWS EMR Advisor](https://github.com/aws-samples/aws-emr-advisor/tree/main), a tool designed to analyze and optimize Amazon EMR logs. By containerizing the existing EMR Advisor code, this solution simplifies the setup process, making it portable and easier to deploy in any environment that supports Docker.

---

## Why Containerize?

The original AWS EMR Advisor code requires dependencies like Hadoop, Spark, and Scala, which can be challenging to configure in different environments. This containerized approach provides:

- **Portability**: Run the solution on any platform with Docker support.
- **Ease of Setup**: Avoid manual installation of complex dependencies.
- **Consistency**: Eliminate issues caused by environment differences.

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
