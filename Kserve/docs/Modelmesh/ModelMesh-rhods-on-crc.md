# Model Mesh with RHODS on CRC

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

export RHODS_OP_NS=redhat-ods-operator
export RHODS_APP_NS=redhat-ods-applications
export MINIO_NS=minio
export test_mm_ns=mm-1
~~~


## Installation

**Install RHODS**
~~~
oc new-project ${RHODS_OP_NS}
oc create -f ${COMMON_MANIFESTS_HOME}/subs-rhods-operator.yaml -n ${RHODS_OP_NS}
check_pod_ready name=rhods-operator ${RHODS_OP_NS}

#(Optional) If you want to deploy ModelMesh only, execute the following command when RHODS installation done.
## Remove other components except Model Mesh
 #  oc delete kfdef rhods-anaconda rhods-dashboard rhods-nbc rhods-notebooks -n ${RHODS_APP_NS}

check_pod_ready app=model-mesh ${RHODS_APP_NS}
check_pod_ready app=odh-model-controller ${RHODS_APP_NS}
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

### HTTPS (Edge)

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

**Curl Test using HTTPS(Edge)**
~~~
  export Token=$(oc create token user-one -n ${test_mm_ns})
  export HOST_URL=$(oc get route example-onnx-mnist -ojsonpath='{.spec.host}' -n ${test_mm_ns})
  export HOST_PATH=$(oc get route example-onnx-mnist  -ojsonpath='{.spec.path}' -n ${test_mm_ns})

  curl  -H "Authorization: Bearer ${Token}" --silent --location --fail --show-error --insecure https://${HOST_URL}${HOST_PATH}/infer -d  @${COMMON_MANIFESTS_HOME}/input-onnx.json
~~~


### HTTPS (Reencrypt)

**Deploy Model**
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

**Send Predict using HTTPS(Reencrypt)**
~~~
export Token=$(oc create token user-one -n ${test_mm_ns})
export HOST_URL=$(oc get route example-onnx-mnist -ojsonpath='{.spec.host}' -n ${test_mm_ns})
export HOST_PATH=$(oc get route example-onnx-mnist  -ojsonpath='{.spec.path}' -n ${test_mm_ns})

curl  -H "Authorization: Bearer ${Token}" --silent --location --fail --show-error --insecure https://${HOST_URL}${HOST_PATH}/infer -d @${COMMON_MANIFESTS_HOME}/input-onnx.json
~~~

## Cleanup
~~~
oc delete -n ${test_mm_ns} -f  ${COMMON_MANIFESTS_HOME}/openvino-inference-service.yaml 
oc delete ns ${test_mm_ns} --wait

oc create configmap delete-self-managed-odh -n redhat-ods-operator 
oc label configmap/delete-self-managed-odh api.openshift.com/addon-managed-odh-delete=true -n ${RHODS_OP_NS}
while [[ $(oc get ns redhat-ods-applications --no-headers --ignore-not-found |wc -l) != 0 ]]; do echo "RHODS still exist. It will check every 10 secs"; sleep 10; done

# When all objects are removed, then delete redhat-ods-operator namespace
oc delete namespace ${RHODS_OP_NS}

oc delete ns ${MINIO_NS}
~~~
