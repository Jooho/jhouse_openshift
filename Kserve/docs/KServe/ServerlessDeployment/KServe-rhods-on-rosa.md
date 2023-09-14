# KServe ServerlessDeployment with RHODS on ROSA

*Environment*
 - [ROSA](https://aws.amazon.com/rosa/)


**Pre-resuisite steps & check**
It assumes that you are in the jhouse_openshift repository (Kserve/docs/KServe/ServerlessDeployment folder)
~~~
scripts/setup.sh

source init.sh

cd ${DEMO_HOME}

cp ${MM_MANIFESTS_HOME}/grpc_predict_v2.proto .
~~~


## Installation KServe

**Install Pre-requisites(Serverless, Service Mesh) and KServe**
~~~
git clone git@github.com:Jooho/openshift-ai-serving-test.git
cd openshift-ai-serving-test

./commands/kserve-rhods-install.sh
~~~


## Deploy minio, sample LLM isvc then grpc test
~~~
./commands/kserve-rhods-test.sh
~~~

## Create all runtimes
~~~
cd ..
git clone git@github.com:kserve/kserve.git
cd kserve
kustomize build config/runtimes |oc create -f -
cd -
~~~

----

## SKLEAN

**Deploy sklean model for restful call**
~~~
export MODEL_NAME=sklearn-irisv2
oc apply -f ${MM_MANIFESTS_HOME}/sklearn-irisv2-rest.yaml
~~~

*Rest call*
~~~
curl -vk -X POST -H 'accept: application/json'    -H "Content-Type: application/json"   -d @${MM_MANIFESTS_HOME}/irisv2-input-rest.json   $(oc get isvc ${MODEL_NAME} -ojsonpath='{.status.url}')/v2/models/${MODEL_NAME}/infer
~~~

**Deploy sklean model for restful call**

*gRPC call*
~~~
oc port-forward deploy/${MODEL_NAME}-predictor-00001-deployment 9000:9000

grpcurl -v  -plaintext   -proto ./grpc_predict_v2.proto   -d @  localhost:9000   inference.GRPCInferenceService.ModelInfer < .${MM_MANIFESTS_HOME}/iris-input-grpc.json 
~~~

~~~
export MODEL_NAME=sklearn-irisv2-grpc
oc apply -f @${MM_MANIFESTS_HOME}/sklearn-irisv2-grpc.yaml
~~~

~~~
export ISVC_URL=$(oc get isvc ${MODEL_NAME} -ojsonpath='{.status.url}' |awk -F'https://' '{print $2}')
grpcurl -v  -insecure   -proto ./grpc_predict_v2.proto   -d @  ${ISVC_URL}:443   inference.GRPCInferenceService.ModelInfer < ${MM_MANIFESTS_HOME}/irisv2-input-grpc.json   
~~~


## Cleanup
~~~
oc delete isvc,ig --all -n ${test_ns} 
oc delete ns ${test_ns} --wait

#cd openshift-ai-serving-test
#./commands/kserve-dependencies-clean.sh
~~~
