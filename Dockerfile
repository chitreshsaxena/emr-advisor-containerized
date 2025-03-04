# Use Amazon Corretto 17 as the base image
FROM amazoncorretto:17

# Set environment variables for Java
ENV JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
ENV PATH=$JAVA_HOME/bin:$PATH

# Set environment variables for Hadoop and Spark
ENV HADOOP_VERSION=3.4.1
ENV SPARK_VERSION=3.5.4
ENV HADOOP_HOME=/opt/hadoop
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$HADOOP_HOME/bin:$SPARK_HOME/bin

# Install necessary tools
RUN yum -y update && \
    yum -y install unzip wget tar gzip git procps && \
    yum clean all

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Install Hadoop
RUN wget https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz && \
    mv hadoop-${HADOOP_VERSION} ${HADOOP_HOME} && \
    rm hadoop-${HADOOP_VERSION}.tar.gz

# Install Spark
RUN wget https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop3 ${SPARK_HOME} && \
    rm spark-${SPARK_VERSION}-bin-hadoop3.tgz

# Install SBT
RUN curl -L https://www.scala-sbt.org/sbt-rpm.repo -o /etc/yum.repos.d/sbt-rpm.repo && \
    yum -y install sbt && \
    yum clean all

# Clone the repository and set the working directory
RUN git clone https://github.com/aws-samples/aws-emr-advisor.git /aws-emr-advisor
WORKDIR /aws-emr-advisor

# Build the project
RUN sbt clean compile assembly

# Create a script to run the application
RUN echo '#!/bin/bash' > /run_commands.sh && \
    echo 'if [ -z "$BUCKET_NAME" ] || [ -z "$LOG_PATH" ]; then' >> /run_commands.sh && \
    echo '  echo "Please provide both BUCKET_NAME and LOG_PATH"' >> /run_commands.sh && \
    echo '  exit 1' >> /run_commands.sh && \
    echo 'fi' >> /run_commands.sh && \
    echo 'mkdir -p /tmp/logs' >> /run_commands.sh && \
    echo 'aws s3 sync s3://${BUCKET_NAME}/${LOG_PATH} /tmp/logs/' >> /run_commands.sh && \
    echo 'if [ "$(ls -A /tmp/logs)" ]; then' >> /run_commands.sh && \
    echo '  echo "Logs downloaded successfully."' >> /run_commands.sh && \
    echo 'else' >> /run_commands.sh && \
    echo '  echo "No logs found in s3://${BUCKET_NAME}/${LOG_PATH}"' >> /run_commands.sh && \
    echo '  exit 1' >> /run_commands.sh && \
    echo 'fi' >> /run_commands.sh && \
    echo 'timestamp=$(date +%Y%m%d_%H%M%S)' >> /run_commands.sh && \
    echo 'for log_file in /tmp/logs/*; do' >> /run_commands.sh && \
    echo '  echo "Processing $log_file"' >> /run_commands.sh && \
    echo '  filename=$(basename "$log_file")' >> /run_commands.sh && \
    echo '  export EMR_ADVISOR_OUTPUT_FILE="/tmp/emr_advisor_${filename%.*}_${timestamp}.html"' >> /run_commands.sh && \
    echo '  spark-submit --deploy-mode client \' >> /run_commands.sh && \
    echo '    --conf "spark.emr.advisor.output.file=${EMR_ADVISOR_OUTPUT_FILE}" \' >> /run_commands.sh && \
    echo '    --class com.amazonaws.emr.SparkLogsAnalyzer \' >> /run_commands.sh && \
    echo '    /aws-emr-advisor/target/scala-2.12/aws-emr-advisor-assembly-0.3.0.jar $log_file' >> /run_commands.sh && \
    echo 'done' >> /run_commands.sh && \
    echo 'for report in /tmp/emr_advisor_*.html; do' >> /run_commands.sh && \
    echo '  if [ -f "$report" ]; then' >> /run_commands.sh && \
    echo '    aws s3 cp "$report" s3://${BUCKET_NAME}/emr_advisor_output/' >> /run_commands.sh && \
    echo '    echo "Report uploaded to s3://${BUCKET_NAME}/emr_advisor_output/$(basename $report)"' >> /run_commands.sh && \
    echo '  fi' >> /run_commands.sh && \
    echo 'done' >> /run_commands.sh

# Make the script executable
RUN chmod +x /run_commands.sh

# Set the entry point to the script
ENTRYPOINT ["/bin/bash", "/run_commands.sh"]
