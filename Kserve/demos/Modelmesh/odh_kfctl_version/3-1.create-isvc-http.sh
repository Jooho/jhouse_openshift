#!/bin/bash

source ./config.sh
source ../../utils/common.sh

oc new-project ${MODELMESH_TEST_NS}
oc apply -f  ${MANIFESTS_DIR}/minio-secret-current.yaml -n ${MODELMESH_TEST_NS}
oc apply -f  ${MANIFESTS_DIR}/sa_user.yaml -n ${MODELMESH_TEST_NS}

oc label namespace ${MODELMESH_TEST_NS} modelmesh-enabled=true --overwrite=true
oc apply -f  ${MANIFESTS_DIR}/openvino-serving-runtime.yaml -n ${MODELMESH_TEST_NS}
oc apply -n ${MODELMESH_TEST_NS} -f  ${MANIFESTS_DIR}/openvino-inference-service.yaml 

check_pod_ready modelmesh-service=modelmesh-serving ${MODELMESH_TEST_NS}

