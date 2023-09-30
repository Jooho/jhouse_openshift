#!/bin/bash
set -o pipefail
set -o nounset
set -o errtrace
# set -x   #Uncomment this to debug script.

source "$(dirname "$(realpath "$0")")/../env.sh"

# Delete the Knative gateways
oc delete -f ${DEMO_MANIFESTS_HOME}/serverless/gateways.yaml
oc delete Jaeger jaeger -n istio-system
oc delete Kiali kiali -n istio-system
oc delete ServiceMeshControlPlane minimal -n istio-system

oc delete -f ${DEMO_MANIFESTS_HOME}/serverless/knativeserving-istio.yaml
oc delete -f ${DEMO_MANIFESTS_HOME}/serverless/operators.yaml
oc delete -f ${DEMO_MANIFESTS_HOME}/service-mesh/smmr-${TARGET_OPERATOR_TYPE}.yaml  

oc delete ns knative-serving
oc delete -f ${DEMO_MANIFESTS_HOME}/service-mesh/smcp.yaml
oc delete ns istio-system
oc delete -f ${DEMO_MANIFESTS_HOME}/service-mesh/operators.yaml

oc delete -f ${DEMO_MANIFESTS_HOME}/opendatahub/odh-operators-2.x.yaml


# if [[ -n "${BASE_DIR+x}"  ]] && [[ -n "${BASE_CERT_DIR+x}" ]]
# then
#   if [[ ! z$BASE_DIR == 'z' ]]
#   then
#     rm -rf /${BASE_DIR}
#     rm -rf /${BASE_CERT_DIR}
#   fi
# fi

# Verify 

oc delete KnativeServing knative-serving -n knative-serving
oc delete subscription jaeger-product -n openshift-operators
oc delete subscription kiali-ossm -n openshift-operators
oc delete subscription servicemeshoperator -n openshift-operators
oc delete subscription serverless-operator -n openshift-serverless

jaeger_csv_name=$(oc get csv -n openshift-operators | grep jaeger|awk '{print $1}')
oc delete csv $jaeger_csv_name -n openshift-operators

kiali_csv_name=$(oc get csv -n openshift-operators | grep kiali|awk '{print $1}')
oc delete csv $kiali_csv_name -n openshift-operators

sm_csv_name=$(oc get csv -n openshift-operators | grep servicemeshoperator|awk '{print $1}')
oc delete csv $sm_csv_name -n openshift-operators

sl_csv_name=$(oc get csv -n openshift-operators | grep serverless-operator|awk '{print $1}')
oc delete csv $sm_csv_name -n openshift-serverless

odh_csv_name=$(oc get csv -n openshift-operators | grep opendatahub-operator|awk '{print $1}')
oc delete csv $odh_csv_name -n openshift-serverless

oc delete csv OperatorGroup serverless-operators -n openshift-serverless

oc delete project istio-system
oc delete project knative-serving
oc delete project knative-eventing
oc delete project $TEST_NS
