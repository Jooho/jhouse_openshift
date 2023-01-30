#!/bin/bash

source "./config.sh"
source ../../utils/common.sh
oc new-project ${MINIO_NS}

SECRETKEY=$(openssl rand -hex 32)

sed "s/<secretkey>/$SECRETKEY/g" ${MANIFESTS_DIR}/minio.yaml | sed "s/<minio-ns>/${MINIO_NS}/g" | oc -n ${MINIO_NS} apply -n ${MINIO_NS} -f -
sed "s/<secretkey>/$SECRETKEY/g" ${MANIFESTS_DIR}/minio-secret.yaml | sed "s/<minio-ns>/${MINIO_NS}/g" | tee  ${MANIFESTS_DIR}/minio-secret-current.yaml | oc -n ${MINIO_NS} apply -n ${MINIO_NS} -f -

check_pod_ready app=minio ${MINIO_NS}
