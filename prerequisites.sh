#!/bin/sh

set -e

source ./aws-env-vars
source ./gmail-app-vars

#####################################
# Set your environment variables here
#####################################

# S3 Buckets
LOKI_BUCKET="s3-bucket-loki-alvaro"
TEMPO_BUCKET="s3-bucket-tempo-alvaro"

# ALERTING
ALERTING_PASSWORD=$GMAIL_PASSWORD


#####################################
## Do not modify anything from this line
#####################################

# Print environment variables
echo -e "\n=============="
echo -e "ENVIRONMENT VARIABLES:"
echo -e " * APP_NAMESPACE: $APP_NAMESPACE"
echo -e " * APP_NAME: $APP_NAME"
echo -e " * GRAFANA_NAMESPACE: $GRAFANA_NAMESPACE"
echo -e " * GRAFANA_DASHBOARD_NAME: $GRAFANA_DASHBOARD_NAME"
echo -e " * LOGGING_NAMESPACE: $LOGGING_NAMESPACE"
echo -e " * LOKISTACK_NAME: $LOKISTACK_NAME"
echo -e " * TRACING_OPERATOR_PROJECT: openshift-tempo-operator"
echo -e " * TRACING_DEPLOYMENT_PROJECT: $TRACING_DEPLOYMENT_PROJECT"
echo -e " * TRACING_DEPLOYMENT: $TRACING_DEPLOYMENT"
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
for node in $(oc get nodes -l node-role.kubernetes.io/worker -o name); do
    oc label $node node-role.kubernetes.io/infra=
done


# Create an AWS S3 Bucket to store logs
./prerequisites/aws-create-bucket.sh $LOKI_BUCKET

# Create an AWS S3 Bucket to store traces
./prerequisites/aws-create-bucket.sh $TEMPO_BUCKET

# Create the Logging Bucket Secret
echo -e "\nCreate the Logging Bucket Secret"
SECRET_NAMESPACE=openshift-logging
oc process -f prerequisites/aws-s3-secret.yaml \
    --param-file aws-env-vars --ignore-unknown-parameters=true \
    -p SECRET_NAMESPACE=$SECRET_NAMESPACE \
    -p SECRET_NAME=$LOKI_BUCKET \
    -p AWS_S3_BUCKET=$LOKI_BUCKET | oc apply -f -

# Create the Tempo Bucket Secret
echo -e "\nCreate the Logging Bucket Secret"
SECRET_NAMESPACE=openshift-tempo
oc process -f prerequisites/aws-s3-secret.yaml \
    --param-file aws-env-vars --ignore-unknown-parameters=true \
    -p SECRET_NAMESPACE=$SECRET_NAMESPACE \
    -p SECRET_NAME=$TEMPO_BUCKET \
    -p AWS_S3_BUCKET=$TEMPO_BUCKET | oc apply -f -

# Create the Quarkus Obs Alerting Pass
echo -e "\nCreate the Quarkus Obs Alerting Pass"
SECRET_NAMESPACE=quarkus-observability
oc process -f prerequisites/secret-alert-routing-to-mail.yaml \
    -p AUTH_PASSWORD=$ALERTING_PASSWORD | oc apply -f -

