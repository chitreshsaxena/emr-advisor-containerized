## Clone Repository
First, clone the repository containing the Dockerfile for Mac with an M-series chip:

```sh
git clone https://github.com/chitreshsaxena/emr-advisor-containerized.git
cd emr-advisor-containerized/mac
```

## Build Instructions (for Mac with Apple Silicon)
Use the following command to build the Docker image:

```sh
sudo docker build --platform=linux/arm64 -t emr-advisor .
```


## AWS CLI Setup
Please make sure you have **AWS CLI** set up on your Mac. You can verify the installation by running:

```sh
aws s3 ls
```

## Sample Log File For Testing - Optional
You can use the sample log file available at:

[Sample Log File](https://github.com/aws-samples/aws-emr-advisor/blob/main/src/test/resources/job_spark_pi)

Upload it to your S3 bucket under the `logs/` path before running the container.


## Run Instructions
Once built, run the container using:

```sh
sudo docker run --rm -it -v $HOME/.aws:/root/.aws -e BUCKET_NAME=your-bucket-name -e LOG_PATH=logs/ emr-advisor bash
```

**Note:** Replace `your-bucket-name` with your actual S3 bucket name and ensure the log files are present under the `logs/` path.
