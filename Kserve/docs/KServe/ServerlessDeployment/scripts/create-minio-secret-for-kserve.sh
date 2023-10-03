#!/bin/bash
source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/utils.sh"

export MINIO_NS=minio
export MINIO_IMG=quay.io/jooholee/modelmesh-minio-examples:v0.11.0
export ACCESS_KEY_ID=THEACCESSKEY

## Check if ${MINIO_NS} exist
oc get ns ${MINIO_NS}
if [[ $? ==  1 ]]
then
   die "Deploy minio first"
else
  SECRET_ACCESS_KEY=$(oc get pod minio  -n minio -ojsonpath='{.spec.containers[0].env[1].value}')
fi
  
sed "s/<accesskey>/$ACCESS_KEY_ID/g" ${KSERVE_MANIFESTS_HOME}/minio-secret.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" |sed "s/<minio_ns>/$MINIO_NS/g" | tee ${DEMO_HOME}/minio-secret-current.yaml | oc -n ${MINIO_NS} apply -f - 

sed "s/<minio_ns>/$MINIO_NS/g" ${KSERVE_MANIFESTS_HOME}/minio-kserve-serviceaccount.yaml | tee ${DEMO_HOME}/minio-kserve-serviceaccount-current.yaml 

success "[SUCCESS] 2 files created"
success "${DEMO_HOME}/minio-kserve-serviceaccount-current.yaml, ${DEMO_HOME}/minio-secret-current.yaml"
success "You can create these file in the kserve demo namespace"
