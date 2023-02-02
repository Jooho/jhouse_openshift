# Model Mesh Only with ODH on CRC

*Environment*
 - [CRC](../ETC/CRC.md)



**Pre-resuisite steps & check**
~~~
# Check yq version
yq --version
yq (https://github.com/mikefarah/yq/) version v4.30.8

# Check jq version
jq --version
jq-1.6

# Check grpcurl version
grpcurl --version
grpcurl v1.8.7

# Export demo home
export DEMO_HOME=/tmp/modelmesh
mkdir -p $DEMO_HOME
cd $DEMO_HOME

# Clone jhouse repository
git clone https://github.com/Jooho/jhouse_openshift.git

# Export common script
source ${DEMO_HOME}/jhouse_openshift/Kserve/demos/utils/common.sh

# Export ModelMesh Manifests
export MM_MANIFESTS_HOME=${DEMO_HOME}/jhouse_openshift/Kserve/docs/Modelmesh/manifests

# Export common manifests dir
export COMMON_MANIFESTS_HOME=${DEMO_HOME}/jhouse_openshift/Kserve/docs/Common/manifests

export ODH_NS=opendatahub
export MINIO_NS=minio
export test_mm_ns=${ODH_NS}-mm
~~~


## Installation

**Deploy ODH operator**
~~~
oc create -f ${COMMON_MANIFESTS_HOME}/subs-odh-operator.yaml
check_pod_ready name=opendatahub-operator openshift-operators
~~~

**Deploy Model Mesh**
~~~

oc new-project ${ODH_NS}
oc create -f  ${MM_MANIFESTS_HOME}/kfdef-odh-modelmesh.yaml

check_pod_ready app=model-mesh ${ODH_NS}
check_pod_ready app=odh-model-controller ${ODH_NS}
~~~

## Test model
**Deploy Minio**
~~~

ACCESS_KEY_ID=THEACCESSKEY
SECRET_ACCESS_KEY=$(openssl rand -hex 32)

oc new-project ${MINIO_NS}

sed "s/<accesskey>/$ACCESS_KEY_ID/g"  ${COMMON_MANIFESTS_HOME}/minio.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" | tee ./minio-current.yaml | oc -n ${MINIO_NS} apply -f -

sed "s/<accesskey>/$ACCESS_KEY_ID/g" ${COMMON_MANIFESTS_HOME}/minio-secret.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" |sed 's+http://minio.modelmesh-serving.svc:9000+http://minio.minio.svc:9000+g'  | tee ./minio-secret-current.yaml | oc -n ${MINIO_NS} apply -f - 
~~~


### HTTP

**Deploy Model**
~~~
oc new-project ${test_mm_ns}
oc label namespace ${test_mm_ns} modelmesh-enabled=true --overwrite=true

oc apply -f ./minio-secret-current.yaml -n ${test_mm_ns}
oc apply -f  ${COMMON_MANIFESTS_HOME}/sa_user.yaml -n ${test_mm_ns}

oc apply -f ${COMMON_MANIFESTS_HOME}/openvino-serving-runtime.yaml -n ${test_mm_ns}
oc apply -n ${test_mm_ns} -f  ${COMMON_MANIFESTS_HOME}/openvino-inference-service.yaml 

check_pod_ready modelmesh-service=modelmesh-serving ${test_mm_ns}
~~~

**Curl Test using HTTP**
~~~
export Token=$(oc create token user-one -n ${test_mm_ns})
export HOST_URL=$(oc get route example-onnx-mnist -ojsonpath='{.spec.host}' -n ${test_mm_ns})
export HOST_PATH=$(oc get route example-onnx-mnist  -ojsonpath='{.spec.path}' -n ${test_mm_ns})

curl  -H "Authorization: Bearer ${Token}" --silent --location --fail --show-error http://${HOST_URL}${HOST_PATH}/infer -d  @${COMMON_MANIFESTS_HOME}/input-onnx.json
~~~


### HTTPS

**Create a isvc using HTTPS**
~~~
oc delete project ${test_mm_ns}

oc new-project ${test_mm_ns}
oc apply -f  ./minio-secret-current.yaml -n ${test_mm_ns}
oc apply -f  ${COMMON_MANIFESTS_HOME}/sa_user.yaml -n ${test_mm_ns}

oc label namespace ${test_mm_ns} modelmesh-enabled=true --overwrite=true

sed 's/    enable-auth: "false"/    enable-auth: "true"/g'  ${COMMON_MANIFESTS_HOME}/openvino-serving-runtime.yaml | oc apply -n ${test_mm_ns} -f -

oc apply -n ${test_mm_ns} -f  ${COMMON_MANIFESTS_HOME}/openvino-inference-service.yaml 

check_pod_ready modelmesh-service=modelmesh-serving ${test_mm_ns}
~~~

**Send Predict using HTTPS**
~~~
export Token=$(oc create token user-one -n ${test_mm_ns})
export HOST_URL=$(oc get route example-onnx-mnist -ojsonpath='{.spec.host}' -n ${test_mm_ns})
export HOST_PATH=$(oc get route example-onnx-mnist  -ojsonpath='{.spec.path}' -n ${test_mm_ns})

curl  -H "Authorization: Bearer ${Token}" --silent --location --fail --show-error --insecure https://${HOST_URL}${HOST_PATH}/infer -d @${COMMON_MANIFESTS_HOME}/input-onnx.json
~~~

## Cleanup
~~~
oc delete -n ${test_mm_ns} -f  ${COMMON_MANIFESTS_HOME}/openvino-inference-service.yaml 
oc delete -f ${COMMON_MANIFESTS_HOME}/openvino-serving-runtime.yaml -n ${test_mm_ns}
oc delete -f ${MM_MANIFESTS_HOME}/kfdef-odh-modelmesh.yaml -n ${ODH_NS}
oc delete ns ${ODH_NS}
oc delete -f ${MM_MANIFESTS_HOME}/subs-odh-operator.yaml -n openshift-operators
oc delete csv $(oc get csv -n openshift-operators|grep opendatahub|awk '{print $1}') -n openshift-operators

oc delete ns ${MINIO_NS}
~~~
