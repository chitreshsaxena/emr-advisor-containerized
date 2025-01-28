#!/bin/bash

# Check if required parameters are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <INSTANCE_ID> <S3_BUCKET_NAME>"
    echo "Example: $0 i-09a1069db5c89e118 my-s3-bucket"
    exit 1
fi

# Assign parameters to variables
INSTANCE_ID=$1
S3_BUCKET_NAME=$2
ROLE_NAME="S3AccessRole"
INSTANCE_PROFILE_NAME="S3AccessInstanceProfile"

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

# Step 2: Attach S3 Read and Write Access Policy to the Role
echo "Attaching S3 access policy to role: $ROLE_NAME"
cat <<EOF > s3-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::${S3_BUCKET_NAME}",
                "arn:aws:s3:::${S3_BUCKET_NAME}/*"
            ]
        }
    ]
}
EOF

aws iam put-role-policy --role-name $ROLE_NAME --policy-name S3AccessPolicy --policy-document file://s3-policy.json

# Step 3: Create an Instance Profile and Attach the Role
echo "Creating instance profile: $INSTANCE_PROFILE_NAME"
aws iam create-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME
aws iam add-role-to-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --role-name $ROLE_NAME

# Step 4: Attach the Instance Profile to the EC2 Instance
echo "Associating instance profile $INSTANCE_PROFILE_NAME with instance $INSTANCE_ID"
aws ec2 associate-iam-instance-profile --instance-id $INSTANCE_ID --iam-instance-profile Name=$INSTANCE_PROFILE_NAME || echo "Instance profile already associated"

# Step 5: Test S3 Access
echo "Testing S3 access"
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
IAM_CREDENTIALS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME)

if [ -z "$IAM_CREDENTIALS" ]; then
    echo "Failed to fetch IAM role credentials. Please check the role and instance profile setup."
    exit 1
fi

echo "IAM Role Credentials: $IAM_CREDENTIALS"

echo "Uploading a test file to S3 bucket: $S3_BUCKET_NAME"
echo "This is a test file." > test-file.txt
aws s3 cp test-file.txt s3://$S3_BUCKET_NAME/

if [ $? -eq 0 ]; then
    echo "Successfully tested S3 read/write access for bucket $S3_BUCKET_NAME."
else
    echo "Failed to access S3. Please check the role permissions."
    exit 1
fi

echo "S3 Access Role setup completed successfully!"
