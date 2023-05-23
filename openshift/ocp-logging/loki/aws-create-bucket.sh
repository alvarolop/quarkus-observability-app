#!/bin/sh

source $1

# User defined variables
AWS_S3_BUCKET="logging-loki-s3-bucket"

# Print environment variables
echo -e "\n=============="
echo -e "ENVIRONMENT VARIABLES:"
echo -e " * AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID"
echo -e " * AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY"
echo -e " * AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"
echo -e " * AWS_S3_BUCKET: $AWS_S3_BUCKET"
echo -e "==============\n"

aws s3api create-bucket \
    --bucket $AWS_S3_BUCKET \
    --region $AWS_DEFAULT_REGION \
    --create-bucket-configuration LocationConstraint=$AWS_DEFAULT_REGION
