#!/bin/bash

set -e

source ./aws-env-vars

#####################################
# Set your environment variables here
#####################################

# Random suffix generator
generate_random_suffix() {
    tr -dc 'a-z0-9' </dev/urandom | head -c 5
}

# S3 Buckets
LOKI_BUCKET="s3-bucket-loki-$(generate_random_suffix)"
LOKI_SECRET_NAMESPACE=openshift-logging

TEMPO_BUCKET="s3-bucket-tempo-$(generate_random_suffix)"
TEMPO_SECRET_NAMESPACE=openshift-tempo

DEPLOY_GENERATOR_APPS=true

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
# Check if the Loki secret exists in the specified namespace
if ! oc get secret s3-bucket-loki -n $LOKI_SECRET_NAMESPACE &>/dev/null; then
    echo "Secret 's3-bucket-loki' not found in namespace '$LOKI_SECRET_NAMESPACE'. Creating it now..."
    oc process -f prerequisites/aws-s3-secret-loki.yaml \
        --param-file aws-env-vars --ignore-unknown-parameters=true \
        -p SECRET_NAMESPACE=$LOKI_SECRET_NAMESPACE \
        -p SECRET_NAME="s3-bucket-loki" \
        -p AWS_S3_BUCKET=$LOKI_BUCKET | oc apply -f -
else
    echo "Secret 's3-bucket-loki' already exists in namespace '$LOKI_SECRET_NAMESPACE'. Skipping creation."
fi


echo -e "\n=================="
echo -e "=     TRACING    ="
echo -e "==================\n"

echo -e "Create the Tempo Bucket and Secret"
# Create an AWS S3 Bucket to store traces
./prerequisites/aws-create-bucket.sh $TEMPO_BUCKET
# Check if the secret exists in the specified namespace
if ! oc get secret s3-bucket-tempo -n $TEMPO_SECRET_NAMESPACE &>/dev/null; then
    echo "Secret 's3-bucket-tempo' not found in namespace '$TEMPO_SECRET_NAMESPACE'. Creating it now..."
    oc process -f prerequisites/aws-s3-secret-tempo.yaml \
        --param-file aws-env-vars --ignore-unknown-parameters=true \
        -p SECRET_NAMESPACE=$TEMPO_SECRET_NAMESPACE \
        -p SECRET_NAME="s3-bucket-tempo" \
        -p AWS_S3_BUCKET=$TEMPO_BUCKET | oc apply -f -
else
    echo "Secret 's3-bucket-tempo' already exists in namespace '$TEMPO_SECRET_NAMESPACE'. Skipping creation."
fi

if [[ "$DEPLOY_GENERATOR_APPS" =~ ^([Tt]rue|[Yy]es|[1])$ ]]; then

    oc apply -f application-ocp-dist-tracing-gen.yaml
fi


echo -e "\n=================="
echo -e "= INFRA ALERTING ="
echo -e "==================\n"

if [ -f ./gmail-app-vars ]; then

    # Create the Quarkus Obs Alerting Pass
    echo -e "Create the Quarkus Obs Alerting Pass"

    source ./gmail-app-vars
    SECRET_NAMESPACE=quarkus-observability
    # Check if the alert routing secret exists in the specified namespace
if ! oc get secret alert-routing-to-mail -n $SECRET_NAMESPACE &>/dev/null; then
    echo "Secret 'alert-routing-to-mail' not found in namespace '$SECRET_NAMESPACE'. Creating it now..."
    oc process -f prerequisites/secret-alert-routing-to-mail.yaml \
        -p SECRET_NAMESPACE=$SECRET_NAMESPACE \
        -p SECRET_NAME="alert-routing-to-mail" \
        -p AUTH_PASSWORD=$GMAIL_PASSWORD | oc apply -f -
else
    echo "Secret 'alert-routing-to-mail' already exists in namespace '$SECRET_NAMESPACE'. Skipping creation."
fi
else 
    echo -e "\The file with Gmail vars is missing. Skipping creation of the Alerts secret"
fi


echo -e "\n======================="
echo -e "=     CONSOLELINKS    ="
echo -e "=======================\n"

ROUTE_SUFIX=$(oc get route console -n openshift-console -o jsonpath='{.spec.host}' | sed 's/^console-openshift-console\.//')

# Create the ConsoleLink to Grafana
oc process -f prerequisites/consolelink.yaml \
    -p NAME=openshift-tempo-tempo \
    -p SPEC_HREF="https://tempo-tempo-gateway-openshift-tempo.$ROUTE_SUFIX" \
    -p SPEC_TEXT="Jaeger UI" \
    -p SECTION="Observability" \
    -p IMAGE_URL="https://api.nuget.org/v3-flatcontainer/jaeger/1.0.3/icon" | oc apply -f -

# Create the ConsoleLink to Tempo
oc process -f prerequisites/consolelink.yaml \
    -p NAME=grafana-grafana \
    -p SPEC_HREF="https://grafana-route-grafana.$ROUTE_SUFIX" \
    -p SPEC_TEXT="Grafana" \
    -p SECTION="Observability" \
    -p IMAGE_URL="https://img.icons8.com/fluency/256/grafana.png" | oc apply -f -


echo -e "\n=================="
echo -e "=     GITOPS     ="
echo -e "==================\n"

echo -e "Trigger the app of apps creation"
oc apply -f app-of-apps.yaml
