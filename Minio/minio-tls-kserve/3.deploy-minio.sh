#!/bin/bash
source "$(dirname "$0")/env.sh"
# source "$(dirname "$0")/utils.sh"

# Deploy Minio
oc new-project ${MINIO_NS}
oc create secret generic minio-tls --from-file=${BASE_CERT_DIR}/minio.key --from-file=${BASE_CERT_DIR}/minio.crt --from-file=${BASE_CERT_DIR}/root.crt
oc -n ${MINIO_NS} apply -f ${DEMO_HOME}/minio.yaml
# sed "s/<minio_ns>/$MINIO_NS/g"  ${DEMO_HOME}/kserve-serviceaccount-minio.yaml | tee ${DEMO_HOME}/kserve-serviceaccount-minio-current.yaml 

oc create route passthrough minio --service=minio
