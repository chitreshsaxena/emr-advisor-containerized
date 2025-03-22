# Use Amazon Corretto 17 as base
FROM amazoncorretto:17

# Install dependencies and add sbt repo
RUN yum -y update && \
    yum -y install wget unzip tar gzip git curl java-17-amazon-corretto-devel procps && \
    curl -L -o /etc/yum.repos.d/sbt-rpm.repo https://www.scala-sbt.org/sbt-rpm.repo && \
    yum -y install sbt && \
    yum clean all

# Set environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
ENV PATH="$JAVA_HOME/bin:$PATH"
ENV SPARK_VERSION=3.5.5
ENV SPARK_HOME=/opt/spark

# Install Spark
RUN wget https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    mv spark-${SPARK_VERSION}-bin-hadoop3 ${SPARK_HOME} && \
    rm spark-${SPARK_VERSION}-bin-hadoop3.tgz

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Copy your local JARs if available
COPY app/aws-emr-advisor-assembly-0.3.0.jar /app/
COPY app/sparklens-0.3.2-s_2.11.jar /app/

# Clone and build EMR Advisor project (optional if JAR is already present)
WORKDIR /tmp
RUN git clone https://github.com/aws-samples/aws-emr-advisor

# Bug fix: Copy the updated Scala file into the cloned repo
COPY AppSparkExecutors.scala /tmp/aws-emr-advisor/src/main/scala/com/amazonaws/emr/spark/models/AppSparkExecutors.scala
COPY AppEfficiencyAnalyzer.scala /tmp/aws-emr-advisor/src/main/scala/com/amazonaws/emr/spark/analyzer/
COPY PageSummary.scala /tmp/aws-emr-advisor/src/main/scala/com/amazonaws/emr/report/spark/PageSummary.scala
COPY EmrOnEc2Env.scala /tmp/aws-emr-advisor/src/main/scala/com/amazonaws/emr/spark/models/runtime/EmrOnEc2Env.scala
COPY EmrOnEksEnv.scala /tmp/aws-emr-advisor/src/main/scala/com/amazonaws/emr/spark/models/runtime/EmrOnEksEnv.scala
COPY EmrServerlessEnv.scala /tmp/aws-emr-advisor/src/main/scala/com/amazonaws/emr/spark/models/runtime/EmrServerlessEnv.scala


RUN cd /tmp/aws-emr-advisor && \
    sbt clean compile assembly && \
    cp ./target/scala-2.12/aws-emr-advisor-assembly-0.3.0.jar /app/

# Copy execution script
COPY run_commands.sh /run_commands.sh
RUN chmod +x /run_commands.sh

# Set working directory and default command
WORKDIR /app
CMD ["/run_commands.sh"]
