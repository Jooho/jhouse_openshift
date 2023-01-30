#!/bin/bash

# set -o errexit
# set -o pipefail
# set -o nounset
# set -o errtrace
# set -x


source "./config.sh"

NS=mm
kubectl create ns ${NS}
ACCESS_KEY_ID=$(kubectl get secret -n modelmesh-serving storage-config -o yaml |yq '.data.localMinIO|@base64d'|jq .access_key_id)
SECRET_ACCESS_KEY=$(kubectl get secret -n modelmesh-serving storage-config -o yaml |yq '.data.localMinIO|@base64d'|jq .secret_access_key)

sed "s/<accesskey>/$ACCESS_KEY_ID/g" ./minio-secret.yaml | sed "s/<minio-ns>/${MINIO_NS}/g" | tee ./minio-secret-current.yaml 
sed "s/<secretkey>/$SECRET_ACCESS_KEY/g" -i ./minio-secret-current.yaml 

oc apply -f ./minio-secret-current.yaml -n ${NS}
oc apply -f ./sa_user.yaml -n ${NS}

oc label namespace ${NS} modelmesh-enabled=true --overwrite=true
oc apply -f openvino-serving-runtime.yaml -n ${NS}
oc apply -f ./openvino-inference-service.yaml -n ${NS}



# # check for model mesh instances
# for i in $(seq 1 ${NS_COUNT})
# do
#     NS=${NS_BASENAME}-${i}

#     until [[ "$(oc get pods -n ${NS} | grep '5/5' |grep Running |wc -l)" == ${MM_POD_COUNT} ]]
#     do
#         echo "NS:${NS}: Waiting for the model mesh pods"
#         sleep 1
#     done
#     unset NS
# done

# echo "id,ns,endpoint" > endpoints.txt

# # test inference endpoints
# INDEX=0
# for i in $(seq 1 ${NS_COUNT})
# do
#     NS=${NS_BASENAME}-${i}
    
#     auth_token=$(oc -n ${NS} sa new-token user-one)
#     for j in $(seq 1 ${MODEL_COUNT})
#     do
#         let "INDEX=INDEX+1"
#       	route=$(oc -n ${NS} get routes example-onnx-mnist-$j --template={{.spec.host}}{{.spec.path}})
#         ENDPOINT=https://${route}/infer
#         if [[ "$API_ENDPOINT_CHECK" -eq 0 ]]
#         then
#             echo "NS:${NS}: Smoke-testing endpoint example-onnx-mnist-$j"
#             until curl $CURL_OPTIONS $ENDPOINT -d @./input-onnx.json  | jq '.outputs[] | select(.data != null)' &>/dev/null
#             until curl $CURL_OPTIONS $ENDPOINT -d @./input-onnx.json -H "Authorization: Bearer ${auth_token}" | jq '.outputs[] | select(.data != null)' &>/dev/null
#             do
#                 echo "S:${NS}: Waiting for inference endpoint example-onnx-mnist-$j"
#                 sleep 1
#             done
# 	fi
# 	echo "${INDEX},${NS},${ENDPOINT}" >> endpoints.txt
#     done
#     unset NS
# done
