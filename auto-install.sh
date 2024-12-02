#!/bin/bash

set -e

source ./aws-env-vars

#####################################
# Set your environment variables here
#####################################

# S3 Buckets
LOKI_BUCKET="s3-bucket-loki-alvaro"
LOKI_SECRET_NAMESPACE=openshift-logging

TEMPO_BUCKET="s3-bucket-tempo-alvaro"
TEMPO_SECRET_NAMESPACE=openshift-tempo

#####################################
## Do not modify anything from this line
#####################################

# Print environment variables
echo -e "\n=============="
echo -e "ENVIRONMENT VARIABLES:"
echo -e " * LOKI_BUCKET: $LOKI_BUCKET"
echo -e " * LOKI_SECRET_NAMESPACE: $LOKI_SECRET_NAMESPACE"
echo -e " * TEMPO_BUCKET: $TEMPO_BUCKET"
echo -e " * TEMPO_SECRET_NAMESPACE: $TEMPO_SECRET_NAMESPACE"
echo -e "==============\n"

# Check if the user is logged in 
if ! oc whoami &> /dev/null; then
    echo -e "Checked. You are not logged in. Please log in and run the script again."
    exit 1
else
    echo -e "Checked. You are correctly logged in. Continue..."
    if ! oc project &> /dev/null; then
        echo -e "Current project does not exist, moving to project Default."
        oc project default 
    fi
fi

# Check if aws cli is installed
if ! which aws &> /dev/null; then 
    echo "You need the AWS CLI to run this Quickstart, please, refer to the official documentation:"
    echo -e "\thttps://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
else 
    echo -e "Checked. You have aws cli installed. Continue..."
fi


# Label Infra nodes
echo -e "\nLabel all worker nodes for simplicity. Not for production use"
for node in $(oc get nodes -l node-role.kubernetes.io/worker -o name); do
    oc label $node node-role.kubernetes.io/infra=
done


echo -e "\n=================="
echo -e "=     LOGGING    ="
echo -e "==================\n"

# Create the Logging Bucket Secret
echo -e "Create the Logging Bucket and Secret"
# Create an AWS S3 Bucket to store logs
./prerequisites/aws-create-bucket.sh $LOKI_BUCKET
oc process -f prerequisites/aws-s3-secret-loki.yaml \
    --param-file aws-env-vars --ignore-unknown-parameters=true \
    -p SECRET_NAMESPACE=$LOKI_SECRET_NAMESPACE \
    -p SECRET_NAME="s3-bucket-loki" \
    -p AWS_S3_BUCKET=$LOKI_BUCKET | oc apply -f -


echo -e "\n=================="
echo -e "=     TRACING    ="
echo -e "==================\n"

# Create the Tempo Bucket Secret
echo -e "Create the Tempo Bucket and Secret"
# Create an AWS S3 Bucket to store traces
./prerequisites/aws-create-bucket.sh $TEMPO_BUCKET
oc process -f prerequisites/aws-s3-secret-tempo.yaml \
    --param-file aws-env-vars --ignore-unknown-parameters=true \
    -p SECRET_NAMESPACE=$TEMPO_SECRET_NAMESPACE \
    -p SECRET_NAME="s3-bucket-tempo" \
    -p AWS_S3_BUCKET=$TEMPO_BUCKET | oc apply -f -


echo -e "\n=================="
echo -e "= INFRA ALERTING ="
echo -e "==================\n"

if [ -f ./gmail-app-vars ]; then

    # Create the Quarkus Obs Alerting Pass
    echo -e "Create the Quarkus Obs Alerting Pass"

    source ./gmail-app-vars
    SECRET_NAMESPACE=quarkus-observability
    oc process -f prerequisites/secret-alert-routing-to-mail.yaml \
        -p AUTH_PASSWORD=$GMAIL_PASSWORD | oc apply -f -
else 
    echo -e "\The file with Gmail vars is missing. Skipping creation of the Alerts secret"
fi


echo -e "\n=================="
echo -e "=     GITOPS     ="
echo -e "==================\n"

echo -e "Trigger the app of apps creation"
oc apply -f app-of-apps.yaml
