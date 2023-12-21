#!/bin/sh

set -e

source ./gmail-app-vars

#####################################
# Set your environment variables here
#####################################

# QUARKUS APP
APP_NAMESPACE=quarkus-observability
APP_NAME=app


# MONITORING
GRAFANA_NAMESPACE=grafana
GRAFANA_DASHBOARD_NAME="quarkus-observability-dashboard"
GRAFANA_DASHBOARD_KEY="dashboard.json"

# ALERTING
ALERTING_USERNAME=$GMAIL_USERNAME
ALERTING_PASSWORD=$GMAIL_PASSWORD

# LOGGING
LOGGING_NAMESPACE=openshift-logging
LOKISTACK_NAME=logging-loki

# DISTRIBUTED TRACING
TRACING_OPERATOR_PROJECT=openshift-tempo-operator
TRACING_DEPLOYMENT_PROJECT=openshift-tempo
TRACING_DEPLOYMENT=tempo


#############################
## Do not modify anything from this line
#############################

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


##
# 0) INITIAL TASKS THAT REQUIRE TIME
## 

# User workload monitoring

echo -e "\n[0/13]Configuring User Workload Monitoring"
oc apply -f openshift/ocp-monitoring/10-cm-cluster-monitoring-config.yaml
oc apply -f openshift/ocp-monitoring/11-cm-user-workload-monitoring-config.yaml
oc process -f openshift/ocp-monitoring/12-secret-alertmanager-main.yaml \
    -p AUTH_USERNAME=$ALERTING_USERNAME \
    -p AUTH_PASSWORD=$ALERTING_PASSWORD | oc apply -f - -n openshift-monitoring


# Create an AWS S3 Bucket to store the logs
./openshift/ocp-logging/loki/aws-create-bucket.sh ./aws-env-vars

# Create an AWS S3 Bucket to store the logs
./openshift/ocp-distributed-tracing/tempo/aws-create-bucket.sh ./aws-env-vars


##
# 1) Quarkus application
## 
echo -e "\n[1/13]Deploying the Quarkus application"

oc process -f openshift/quarkus-app/10-project.yaml \
    -p APP_NAMESPACE=$APP_NAMESPACE | oc apply -f -

oc create configmap $APP_NAME-config -n $APP_NAMESPACE --dry-run=client --output yaml \
    --from-file=application.yml=src/main/resources/application-ocp.yml \
    | oc apply -f -

oc process -f openshift/quarkus-app/20-app.yaml \
    -p APP_NAMESPACE=$APP_NAMESPACE \
    -p APP_NAME=$APP_NAME | oc apply -f -




##
# 2) Monitoring
## 

# Add Service Monitor to collect metrics from the App
echo -e "\n[2/13]Configure Prometheus to monitor the App"
oc process -f openshift/ocp-monitoring/20-service-monitor.yaml \
    -p APP_NAMESPACE=$APP_NAMESPACE \
    -p APP_NAME=$APP_NAME | oc apply -f -



##
# 3) Alerting
## 

# Add Alert to monitorize requests to the API
echo -e "\n[3/13]Configure Alert to monitorize requests to the API"
oc process -f openshift/ocp-alerting/10-prometheus-rule.yaml \
    -p APP_NAMESPACE=$APP_NAMESPACE \
    -p APP_NAME=$APP_NAME | oc apply -f -

oc process -f openshift/ocp-alerting/20-alertmanagerconfig.yaml \
    -p APP_NAMESPACE=$APP_NAMESPACE \
    -p AUTH_USERNAME=$ALERTING_USERNAME \
    -p AUTH_PASSWORD=$ALERTING_PASSWORD | oc apply -f -


##
# 4) Grafana
## 

# Deploy the Grafana Operator
echo -e "\n[4/13]Deploying the Grafana operator"
oc process -f openshift/grafana/10-operator.yaml \
    -p OPERATOR_NAMESPACE=$GRAFANA_NAMESPACE | oc apply -f -

echo -n "Waiting for pods ready..."
while [[ $(oc get pods -l control-plane=controller-manager -n $GRAFANA_NAMESPACE -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"


# Create a Grafana instance
echo -e "\n[5/13]Creating a grafana instance"
oc process -f openshift/grafana/20-instance.yaml \
    -p OPERATOR_NAMESPACE=$GRAFANA_NAMESPACE | oc apply -f -

echo -n "Waiting for ServiceAccount ready..."
while ! oc get sa grafana-sa -n $GRAFANA_NAMESPACE &> /dev/null; do   echo -n "." && sleep 1; done; echo -n -e " [OK]\n"

# --- In OCP 4.11 or higher ---
BEARER_TOKEN=$(oc get secret $(oc describe sa grafana-sa -n $GRAFANA_NAMESPACE | awk '/Tokens/{ print $2 }') -n $GRAFANA_NAMESPACE --template='{{ .data.token | base64decode }}')

# Create a Grafana data source
echo -e "\n[6/13]Creating the Grafana datasource"
oc process -f openshift/grafana/30-datasource.yaml \
    -p BEARER_TOKEN=$BEARER_TOKEN \
    -p OPERATOR_NAMESPACE=$GRAFANA_NAMESPACE | oc apply -f -

# Create the Grafana dashboard
echo -e "\n[7/13]Creating the Grafana dashboard"
oc process -f openshift/grafana/40-dashboard.yaml \
    -p DASHBOARD_GZIP="$(cat openshift/grafana/app-observability-dashboard.json | gzip | base64 -w0)" \
    -p DASHBOARD_NAME=$GRAFANA_DASHBOARD_NAME \
    -p OPERATOR_NAMESPACE=$GRAFANA_NAMESPACE \
    -p CUSTOM_FOLDER_NAME="App Observability"  | oc apply -f -


echo -e "\n[7.5/13]Creating the Grafana development instance"
oc process -f openshift/grafana/90-dev-instance.yaml \
    -p BEARER_TOKEN=$BEARER_TOKEN \
    -p OPERATOR_NAMESPACE=$GRAFANA_NAMESPACE | oc apply -f -

##
# 5) Logging
##

# Install the Openshift Logging operator
echo -e "\n[8/13]Deploying the Openshift Logging operator"
oc apply -f openshift/ocp-logging/00-subscription.yaml

echo -n "Waiting for operator pods to be ready..."
while [[ $(oc get pods -l "name=cluster-logging-operator" -n $LOGGING_NAMESPACE -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"


# Install the Openshift Logging operator
echo -e "\n[9/13]Deploying the Loki operator"
oc apply -f openshift/ocp-logging/loki/10-operator.yaml

echo -n "Waiting for operator pods to be ready..."
while [[ $(oc get pods -l "name=loki-operator-controller-manager" -n openshift-operators-redhat -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

echo -e "\n[10/13]Create the Logging instance"
oc process -f openshift/ocp-logging/loki/20-instance.yaml \
    --param-file aws-env-vars --ignore-unknown-parameters=true \
    -p LOGGING_NAMESPACE=$LOGGING_NAMESPACE \
    -p LOKISTACK_NAME=$LOKISTACK_NAME | oc apply -f -

# Enable the console plugin
# -> This plugin adds the logging view into the 'observe' menu in the OpenShift console. It requires OpenShift 4.10.

if oc get console.operator.openshift.io cluster -o template='{{.spec.plugins}}' | grep logging-view-plugin &> /dev/null; then
    echo -e "\tChecked. The logging plugin was already enabled."
else
    echo -e "\tChecked. The logging plugin was not enabled. Enabling..."
    oc patch console.operator.openshift.io cluster --type json \
    --patch '[{"op": "add", "path": "/spec/plugins/-", "value": "logging-view-plugin"}]'
fi

##
# 6) Red Hat build of OpenTelemetry
## 


# Install the operator
echo -e "\n[11/13]Deploying the Red Hat build of OpenTelemetry for the telemetry collector (Tracing)"
oc apply -f openshift/ocp-opentelemetry/10-subscription.yaml

echo -n "Waiting for operator pods to be ready..."
while [[ $(oc get pods -l "app.kubernetes.io/name=tempo-operator" -n $TRACING_OPERATOR_PROJECT -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"


##
# 7) Distributed Tracing
## 

# Install the operator
echo -e "\n[12/13]Deploying the Distributed Tracing operator for Grafana Tempo"
oc apply -f openshift/ocp-distributed-tracing/tempo/10-subscription.yaml

echo -n "Waiting for operator pods to be ready..."
while [[ $(oc get pods -l "app.kubernetes.io/name=tempo-operator" -n $TRACING_OPERATOR_PROJECT -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo -n "." && sleep 1; done; echo -n -e "  [OK]\n"

# Deploy TempoStack
echo -e "\n[13/13]Deploying the Grafana Tempo Instance"

oc process -f openshift/ocp-distributed-tracing/tempo/20-tempostack.yaml \
    --param-file aws-env-vars --ignore-unknown-parameters=true \
    -p TRACING_DEPLOYMENT_PROJECT=$TRACING_DEPLOYMENT_PROJECT \
    -p DEPLOYMENT_NAME=$TRACING_DEPLOYMENT | oc apply -f -

sleep 10


##
# 8) Wrap Up
##

# URLs
QUARKUS_ROUTE=$(oc get route $APP_NAME -n $APP_NAMESPACE --template='https://{{ .spec.host }}')
TRACING_ROUTE=$(oc get route -l app.kubernetes.io/name=$TRACING_DEPLOYMENT -n $TRACING_DEPLOYMENT_PROJECT --template='https://{{(index .items 0).spec.host }}')
LOKI_ROUTE=$(oc whoami --show-console)/monitoring/logs
GRAFANA_ROUTE=$(oc get routes -l app=grafana -n $GRAFANA_NAMESPACE --template='https://{{(index .items 0).spec.host }}')

# Grafana credentials
GRAFANA_ADMIN=$(oc get secret grafana-admin-credentials -n $GRAFANA_NAMESPACE -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 --decode)
GRAFANA_PASSW=$(oc get secret grafana-admin-credentials -n $GRAFANA_NAMESPACE -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 --decode)

# TODO: Init the Grafana Dashboard. Needs to change the dashboard logic
echo -e "\nInitializing the Grafana dashbaord with the first API request..."
curl $QUARKUS_ROUTE/api/hello

echo -e "\nURLS:"
echo -e " * Quarkus: $QUARKUS_ROUTE/q/swagger-ui"
echo -e " * Grafana: $GRAFANA_ROUTE"
echo -e " * Loki: $LOKI_ROUTE"
echo -e " * Tracing: $TRACING_ROUTE"

echo -e "\nCredentials:"
echo -e " * Grafana (User / Pass): $GRAFANA_ADMIN / $GRAFANA_PASSW"
