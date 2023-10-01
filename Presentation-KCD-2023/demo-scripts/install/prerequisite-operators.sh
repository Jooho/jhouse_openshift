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
info "Let's install ServiceMesh, OpenDataHub and Serverless operators"

if [[ ! -d ${BASE_DIR} ]]
then
  mkdir ${BASE_DIR}
fi

if [[ ! -d ${BASE_CERT_DIR} ]]
then
  mkdir ${BASE_CERT_DIR}
fi

# Install Service Mesh operators
echo
light_info "[INFO] Install Service Mesh operators"
echo
oc apply -f ${DEMO_MANIFESTS_HOME}/service-mesh/operators.yaml

wait_for_csv_installed servicemeshoperator openshift-operators
wait_for_csv_installed kiali-operator openshift-operators
wait_for_csv_installed jaeger-operator openshift-operators
oc wait --for=condition=ready pod -l name=istio-operator -n openshift-operators --timeout=300s
oc wait --for=condition=ready pod -l name=jaeger-operator -n openshift-operators --timeout=300s
oc wait --for=condition=ready pod -l name=kiali-operator -n openshift-operators --timeout=300s

echo
light_info "[INFO] Install Serverless Operator"
echo
oc apply -f ${DEMO_MANIFESTS_HOME}/serverless/operators.yaml
wait_for_csv_installed serverless-operator openshift-serverless

wait_for_pods_ready "name=knative-openshift" "openshift-serverless"
wait_for_pods_ready "name=knative-openshift-ingress" "openshift-serverless"
wait_for_pods_ready "name=knative-operator" "openshift-serverless"
oc wait --for=condition=ready pod -l name=knative-openshift -n openshift-serverless --timeout=300s
oc wait --for=condition=ready pod -l name=knative-openshift-ingress -n openshift-serverless --timeout=300s
oc wait --for=condition=ready pod -l name=knative-operator -n openshift-serverless --timeout=300s

# Deploy odh/rhods operator
echo
light_info "[INFO] Deploy odh operator"
echo
OPERATOR_LABEL="control-plane=controller-manager"

oc create -f  ${DEMO_MANIFESTS_HOME}/opendatahub/${TARGET_OPERATOR}-operators-2.x.yaml
wait_for_pods_ready "${OPERATOR_LABEL}" "${TARGET_OPERATOR_NS}"
oc wait --for=condition=ready pod -l ${OPERATOR_LABEL} -n ${TARGET_OPERATOR_NS} --timeout=300s 

success "[SUCCESS] Successfully installed ServiceMesh, OpenDataHub and Serverless operators" 
