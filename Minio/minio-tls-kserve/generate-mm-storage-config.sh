#!/bin/bash
source "$(dirname "$0")/env.sh"
# source "$(dirname "$0")/utils.sh"

cat <<EOF> ${DEMO_HOME}/mm-minio-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: storage-config
stringData:
  localMinIO: |
    {
      "type": "s3",
      "access_key_id": "THEACCESSKEY",
      "secret_access_key": "THEPASSWORD",
      "endpoint_url": "https://minio.<minio_ns>.svc:9000",
      "default_bucket": "modelmesh-example-models",
      "region": "us-south",
      "certificate": "<cacert>"
    }
EOF

# Deploy Minio
export CACERT=$(cat ${BASE_CERT_DIR}/public.crt | tr -d '\n' |sed 's/-----BEGIN CERTIFICATE-----/-----BEGIN CERTIFICATE-----\\\\n/g' |sed 's/-----E/\\\\n-----E/g')

sed "s*<cacert>*$CACERT*g" ${DEMO_HOME}/mm-minio-secret.yaml | tee ${DEMO_HOME}/mm-storage-config-minio-secret-current.yaml 
