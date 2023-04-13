#!/bin/bash

source ./config.sh
source ../../utils/common.sh

export Token=$(oc sa new-token user-one -n ${MODELMESH_TEST_NS})
export HOST_URL=$(oc get route example-onnx-mnist -ojsonpath='{.spec.host}' -n ${MODELMESH_TEST_NS})
export HOST_PATH=$(oc get route example-onnx-mnist  -ojsonpath='{.spec.path}' -n ${MODELMESH_TEST_NS})

curl  --silent --location --fail --show-error -k https://${HOST_URL}${HOST_PATH}/infer -d  @${MANIFESTS_DIR}/input-onnx.json