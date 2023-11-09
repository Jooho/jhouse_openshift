#!/bin/bash
source "$(dirname "$0")/env.sh"
# source "$(dirname "$0")/utils.sh"


cat <<EOF> ${DEMO_HOME}/kserve-minio-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  annotations:
    serving.kserve.io/s3-endpoint: minio.<minio_ns>.svc:9000 # replace with your s3 endpoint e.g minio-service.kubeflow:9000
    serving.kserve.io/s3-usehttps: "1" # by default 1, if testing with minio you can set to 0
    serving.kserve.io/s3-verfiyssl: "0"    
    serving.kserve.io/s3-region: "us-east-2"
    serving.kserve.io/s3-useanoncredential: "false" # omitting this is the same as false, if true will ignore provided credential and use anonymous credentials
  name: storage-config
stringData:
  "AWS_ACCESS_KEY_ID": "THEACCESSKEY"
  "AWS_SECRET_ACCESS_KEY": "THEPASSWORD"
EOF

cat <<EOF> ${DEMO_HOME}/kserve-serviceaccount-minio.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa
secrets:
- name: storage-config
EOF


# create kserve storage-config secret for the minio
sed "s*<cacert>*$CACERT*g" ${DEMO_HOME}/kserve-minio-secret.yaml | tee ${DEMO_HOME}/kserve-storage-config-minio-secret-current.yaml 
