#!/bin/bash

echo "Running EMR Advisor..."

# Check for required env vars
if [ -z "$BUCKET_NAME" ] || [ -z "$LOG_PATH" ]; then
  echo "Please provide both BUCKET_NAME and LOG_PATH"
  exit 1
fi

# Create log download directory
mkdir -p /tmp/logs

# Download logs from S3
echo "Syncing logs from s3://${BUCKET_NAME}/${LOG_PATH}"
aws s3 sync s3://${BUCKET_NAME}/${LOG_PATH} /tmp/logs/

if [ "$(ls -A /tmp/logs)" ]; then
  echo "Logs downloaded successfully."
else
  echo "No logs found in s3://${BUCKET_NAME}/${LOG_PATH}"
  exit 1
fi

# Process each log file
for log_file in /tmp/logs/*; do
  echo "Processing $log_file"
  filename=$(basename "$log_file")

  # Clean filename for HTML report
  case "$filename" in
    *html) ;; 
    *) filename="${filename}.html" ;;
  esac

  # Run EMR Advisor with Sparklens
  $SPARK_HOME/bin/spark-submit \
    --jars /app/sparklens-0.3.2-s_2.11.jar \
    --class com.amazonaws.emr.SparkLogsAnalyzer \
    /app/aws-emr-advisor-assembly-0.3.0.jar \
    --bucket "$BUCKET_NAME" \
    "$log_file" || true

  sleep 5

  # Find generated report
  report=$(ls /tmp/emr-advisor.spark.*.html 2>/dev/null | head -n 1)

  if [ -n "$report" ] && [ -f "$report" ]; then
    newname="/tmp/$filename"
    mv "$report" "$newname"
    aws s3 cp "$newname" s3://${BUCKET_NAME}/emr_advisor_output/ > /dev/null
    echo "Report uploaded: s3://${BUCKET_NAME}/emr_advisor_output/$(basename "$newname")"
  else
    echo "No report found for $log_file"
  fi
done
