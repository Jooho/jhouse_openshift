#!/bin/bash
# Environment variables
# - CHECK_UWM: Set this to "false", if you want to skip the User Workload Configmap check message
# - TARGET_OPERATOR: Set this among odh, rhods or brew, if you want to skip the question in the script.
set -o pipefail
set -o nounset
set -o errtrace
# set -x   #Uncomment this to debug script.

source "$(dirname "$(realpath "$0")")/../env.sh"
source "$(dirname "$(realpath "$0")")/../utils.sh"

echo
info "Let's create required CRs and required setup"

if [[ ! -d ${BASE_DIR} ]]
then
  mkdir ${BASE_DIR}
fi

if [[ ! -d ${BASE_CERT_DIR} ]]
then
  mkdir ${BASE_CERT_DIR}
fi

# Create an istio instance
echo
light_info "[INFO] Create an istio instance"
echo
oc create ns istio-system -oyaml --dry-run=client | oc apply -f-
oc::wait::object::availability "oc get project istio-system" 2 60

oc apply -f ${DEMO_MANIFESTS_HOME}/service-mesh/smcp.yaml
wait_for_pods_ready "app=istiod" "istio-system"
wait_for_pods_ready "app=istio-ingressgateway" "istio-system"
wait_for_pods_ready "app=istio-egressgateway" "istio-system"
wait_for_pods_ready "app=jaeger" "istio-system"

oc wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s
oc wait --for=condition=ready pod -l app=istio-ingressgateway -n istio-system --timeout=300s
oc wait --for=condition=ready pod -l app=istio-egressgateway -n istio-system --timeout=300s
oc wait --for=condition=ready pod -l app=jaeger -n istio-system --timeout=300s

# kserve/knative
echo
light_info "[INFO]Update SMMR"
echo
oc create ns opendatahub -oyaml --dry-run=client | oc apply -f-
oc::wait::object::availability "oc get project opendatahub" 2 60
oc create ns knative-serving -oyaml --dry-run=client | oc apply -f-
oc::wait::object::availability "oc get project knative-serving" 2 60

oc apply -f ${DEMO_MANIFESTS_HOME}/service-mesh/smmr-${TARGET_OPERATOR_TYPE}.yaml

# Create a Knative Serving installation
echo
light_info "[INFO] Create a Knative Serving installation"
echo
oc apply -f ${DEMO_MANIFESTS_HOME}/serverless/knativeserving-istio.yaml

wait_for_pods_ready "app=controller" "knative-serving"
wait_for_pods_ready "app=net-istio-controller" "knative-serving"
wait_for_pods_ready "app=net-istio-webhook" "knative-serving"
wait_for_pods_ready "app=autoscaler-hpa" "knative-serving"
wait_for_pods_ready "app=domain-mapping" "knative-serving"
wait_for_pods_ready "app=webhook" "knative-serving"
oc delete pod -n knative-serving -l app=activator --force --grace-period=0
oc delete pod -n knative-serving -l app=autoscaler --force --grace-period=0
wait_for_pods_ready "app=activator" "knative-serving"
wait_for_pods_ready "app=autoscaler" "knative-serving"

oc wait --for=condition=ready pod -l app=controller -n knative-serving --timeout=300s
oc wait --for=condition=ready pod -l app=net-istio-controller -n knative-serving --timeout=300s
oc wait --for=condition=ready pod -l app=net-istio-webhook -n knative-serving --timeout=300s
oc wait --for=condition=ready pod -l app=autoscaler-hpa -n knative-serving --timeout=300s
oc wait --for=condition=ready pod -l app=domain-mapping -n knative-serving --timeout=300s
oc wait --for=condition=ready pod -l app=webhook -n knative-serving --timeout=300s
oc wait --for=condition=ready pod -l app=activator -n knative-serving --timeout=300s
oc wait --for=condition=ready pod -l app=autoscaler -n knative-serving --timeout=300s

# Generate wildcard cert for a gateway.
export DOMAIN_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' | awk -F'.' '{print $(NF-1)"."$NF}')
export COMMON_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')

echo
light_info "[INFO] Generate wildcard cert using openssl"
echo
bash -x ${DEMO_SCRIPTS_HOME}/generate-wildcard-certs.sh ${BASE_CERT_DIR} ${DOMAIN_NAME} ${COMMON_NAME}

# Create the Knative gateways
oc create secret tls wildcard-certs --cert=${BASE_CERT_DIR}/wildcard.crt --key=${BASE_CERT_DIR}/wildcard.key -n istio-system
oc apply -f ${DEMO_MANIFESTS_HOME}/serverless/gateways.yaml

success "[SUCCESS] Successfully created ServiceMesh Control Plan CR, KNative-Serving CR and required setup such as wildcard cert and Gateways" 
