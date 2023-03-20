#!/bin/bash
source ./env.sh

oc delete ns ${test_mm_ns}
oc delete ns ${MINIO_NS}

oc create configmap delete-self-managed-odh -n redhat-ods-operator
oc label configmap/delete-self-managed-odh api.openshift.com/addon-managed-odh-delete=true -n redhat-ods-operator

check_pod_ready app=rhods-operator ${RHODS_OP_NS}
oc delete namespace redhat-ods-operator

rm -rf ${DEMO_HOME}