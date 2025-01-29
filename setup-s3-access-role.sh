#!/bin/bash

# Check if required parameters are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <INSTANCE_ID> <S3_BUCKET_NAME>"
    echo "Example: $0 i-0f35f6647cc72e3c9 emr-advisor-1234567890"
    exit 1
fi

# Assign parameters
INSTANCE_ID=$1
S3_BUCKET_NAME=$2
TIMESTAMP=$(date +%s)  # Generate a unique timestamp
ROLE_NAME="S3AccessRole-${TIMESTAMP}"
INSTANCE_PROFILE_NAME="S3AccessInstanceProfile-${TIMESTAMP}"

echo "Using unique role: $ROLE_NAME and instance profile: $INSTANCE_PROFILE_NAME"

# Step 1: Create the IAM Role with EC2 Trust Relationship
echo "Creating IAM Role: $ROLE_NAME"
cat <<EOF > trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://trust-policy.json

# Step 2: Attach S3 and EMR Pricing Access Policy to the Role (INLINE)
echo "Attaching S3 and EMR Pricing access policy to role: $ROLE_NAME"
cat <<EOF > emr-s3-pricing-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::${S3_BUCKET_NAME}/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticmapreduce:ListReleaseLabels",
                "elasticmapreduce:DescribeCluster",
                "elasticmapreduce:ListClusters",
                "elasticmapreduce:RunJobFlow",
                "elasticmapreduce:AddJobFlowSteps",
                "elasticmapreduce:TerminateJobFlows",
                "elasticmapreduce:DescribeStep",
                "elasticmapreduce:ListSteps"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "pricing:GetProducts"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam put-role-policy --role-name $ROLE_NAME --policy-name S3AccessPolicy-${TIMESTAMP} --policy-document file://emr-s3-pricing-policy.json

# Step 2.1: Attach LimitedEMRAccess Policy INLINE
echo "Attaching LimitedEMRAccess policy to role: $ROLE_NAME"
cat <<EOF > pricing-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "pricing:GetProducts",
                "elasticmapreduce:ListReleaseLabels",
                "elasticmapreduce:DescribeReleaseLabel",
                "elasticmapreduce:ListClusters",
                "elasticmapreduce:DescribeCluster",
                "elasticmapreduce:ListSteps",
                "elasticmapreduce:DescribeStep"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam put-role-policy --role-name $ROLE_NAME --policy-name LimitedEMRAccess --policy-document file://pricing-policy.json

# Step 3: Create an Instance Profile and Attach the Role
echo "Creating instance profile: $INSTANCE_PROFILE_NAME"
aws iam create-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME

# Wait for IAM instance profile propagation
echo "Waiting for IAM instance profile to become available..."
sleep 10

# Attach the role to the instance profile
echo "Attaching role $ROLE_NAME to instance profile $INSTANCE_PROFILE_NAME"
aws iam add-role-to-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --role-name $ROLE_NAME

# Wait for IAM role propagation
echo "Waiting for IAM role to be active..."
sleep 10

# Step 4: Attach the Instance Profile to the EC2 Instance
echo "Associating instance profile $INSTANCE_PROFILE_NAME with instance $INSTANCE_ID"
aws ec2 associate-iam-instance-profile --instance-id $INSTANCE_ID --iam-instance-profile Name=$INSTANCE_PROFILE_NAME

echo "S3 Access Role setup completed successfully!"
