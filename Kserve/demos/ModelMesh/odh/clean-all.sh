#!/bin/bash

source ../../utils/common.sh
source ./config.sh

oc delete -n ${MODELMESH_TEST_NS} -f  ${MANIFESTS_DIR}/openvino-inference-service.yaml 
oc delete -f ${MANIFESTS_DIR}/openvino-serving-runtime.yaml -n ${MODELMESH_TEST_NS}
oc delete -f kfdef-odh-modelmesh.yaml -n ${ODH_NS}
oc delete ns ${ODH_NS}
oc delete -f subs-odh-operator.yaml -n openshift-operators
oc delete csv $(oc get csv -n openshift-operators|grep opendatahub|awk '{print $1}') -n openshift-operators

oc delete ns ${MINIO_NS}

