
## SKLEAN

**Deploy sklean model for restful call**
~~~
export MODEL_NAME=sklearn-iris-v2-rest
oc apply -f ${KSERVE_MANIFESTS_HOME}/sklearn-iris-v2-rest.yaml

wait_for_pods_ready "serving.kserve.io/inferenceservice=${MODEL_NAME}" "${TEST_NS}"
oc wait --for=condition=ready pod -l serving.kserve.io/inferenceservice=${MODEL_NAME} -n ${TEST_NS} --timeout=300s
  
~~~

*Rest call*
~~~
ISVC_URL=$(oc get isvc ${MODEL_NAME} -ojsonpath='{.status.url}')
curl -k -X POST -H 'accept: application/json'    -H "Content-Type: application/json"   -d @${KSERVE_MANIFESTS_HOME}/iris-v2-input-rest.json   ${ISVC_URL}/v2/models/${MODEL_NAME}/infer
~~~

*gRPC call*
~~~
oc port-forward deploy/${MODEL_NAME}-predictor-00001-deployment 9000:9000

envsubst < "${KSERVE_MANIFESTS_HOME}/iris-v2-input-grpc-generic.json" | grpcurl -plaintext -proto ./grpc_predict_v2.proto -d @ localhost:9000 inference.GRPCInferenceService.ModelInfer
~~~

**Deploy sklean model for grpc call**
~~~
export MODEL_NAME=sklearn-iris-v2-grpc
oc apply -f ${KSERVE_MANIFESTS_HOME}/sklearn-iris-v2-grpc.yaml

wait_for_pods_ready "serving.kserve.io/inferenceservice=${MODEL_NAME}" "${TEST_NS}"
oc wait --for=condition=ready pod -l serving.kserve.io/inferenceservice=${MODEL_NAME} -n ${TEST_NS} --timeout=300s
~~~

~~~
export ISVC_URL=$(oc get isvc ${MODEL_NAME} -ojsonpath='{.status.url}' |awk -F'https://' '{print $2}')
grpcurl  -insecure   -proto ./grpc_predict_v2.proto   -d @  ${ISVC_URL}:443   inference.GRPCInferenceService.ModelInfer < ${KSERVE_MANIFESTS_HOME}/iris-v2-input-grpc.json   
~~~
