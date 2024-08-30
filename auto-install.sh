#!/bin/sh

set -e

source ./aws-env-vars
source ./gmail-app-vars

#####################################
# Set your environment variables here
#####################################

# S3 Buckets
LOKI_BUCKET="s3-bucket-loki-alvaro"
LOKI_SECRET_NAMESPACE=openshift-logging

TEMPO_BUCKET="s3-bucket-tempo-alvaro"
TEMPO_SECRET_NAMESPACE=openshift-tempo

# ALERTING
ALERTING_PASSWORD=$GMAIL_PASSWORD


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
    echo -e "Check. You are not logged out. Please log in and run the script again."
    exit 1
else
    echo -e "Check. You are correctly logged in. Continue..."
    if ! oc project &> /dev/null; then
        echo -e "Current project does not exist, moving to project Default."
        oc project default 
    fi
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
oc process -f prerequisites/aws-s3-secret.yaml \
    --param-file aws-env-vars --ignore-unknown-parameters=true \
    -p SECRET_NAMESPACE=$LOKI_SECRET_NAMESPACE \
    -p SECRET_NAME=$LOKI_BUCKET \
    -p AWS_S3_BUCKET=$LOKI_BUCKET | oc apply -f -

echo -e "\n=================="
echo -e "=     TRACING    ="
echo -e "==================\n"

# Create the Tempo Bucket Secret
echo -e "Create the Tempo Bucket and Secret"
# Create an AWS S3 Bucket to store traces
./prerequisites/aws-create-bucket.sh $TEMPO_BUCKET
oc process -f prerequisites/aws-s3-secret.yaml \
    --param-file aws-env-vars --ignore-unknown-parameters=true \
    -p SECRET_NAMESPACE=$TEMPO_SECRET_NAMESPACE \
    -p SECRET_NAME=$TEMPO_BUCKET \
    -p AWS_S3_BUCKET=$TEMPO_BUCKET | oc apply -f -

echo -e "\n=================="
echo -e "= INFRA ALERTING ="
echo -e "==================\n"

# Create the Quarkus Obs Alerting Pass
echo -e "Create the Quarkus Obs Alerting Pass"
SECRET_NAMESPACE=quarkus-observability
oc process -f prerequisites/secret-alert-routing-to-mail.yaml \
    -p AUTH_PASSWORD=$ALERTING_PASSWORD | oc apply -f -

echo -e "\n=================="
echo -e "=     GITOPS     ="
echo -e "==================\n"

echo -e "Trigger the app of apps creation"
oc apply -f app-of-apps.yaml
