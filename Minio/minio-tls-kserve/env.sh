#!/bin/bash

export IS_OCP=true
export EXTERNAL_ROUTE_DOMAIN=example.com
export MINIO_NS=minio
export MINIO_IMG=quay.io/opendatahub/modelmesh-minio-examples:caikit-flan-t5
export DEMO_HOME=/tmp/minio
export BASE_CERT_DIR=/tmp/minio/minio_certs
export CLEAN_FIRST=false
# export ACCESS_KEY_ID=THEACCESSKEY
# export SECRET_ACCESS_KEY=THEPASSWORD
