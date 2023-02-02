# Model Mesh with RHODS on CRC for Ansible Wisdom Model on Watson Runtime

*Environment*
 - [CRC](../ETC/CRC.md)
 - [Custom RHODS](https://github.com/rh-aiservices-pilot/ans-wis-model/blob/main/deploy.rhods.livebuild.and.override.sh)

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
export test_mm_ns=wisdom
~~~


## Installation

**Install RHODS**
~~~
oc new-project ${RHODS_OP_NS}
oc create -f ${COMMON_MANIFESTS_HOME}/wisdom-custom-rhods-operator.yaml -n ${RHODS_OP_NS}
check_pod_ready name=rhods-operator ${RHODS_OP_NS}

#(Optional) If you want to deploy ModelMesh only, execute the following command when RHODS installation done.
## Remove other components except Model Mesh
 #  oc delete kfdef rhods-anaconda rhods-dashboard rhods-nbc rhods-notebooks -n ${RHODS_APP_NS}

check_pod_ready app=model-mesh ${RHODS_APP_NS}
check_pod_ready app=odh-model-controller ${RHODS_APP_NS}

oc -n ${RHODS_APP_NS} \
    patch configmap \
    servingruntimes-config \
    -p "$(cat ${COMMON_MANIFESTS_HOME}/wisdom-servingruntimes-configmap.yaml)"

oc delete pod -l control-plane=modelmesh-controller    
~~~


## Test model

**Deploy Minio**
~~~
ACCESS_KEY_ID=THEACCESSKEY
SECRET_ACCESS_KEY=$(openssl rand -hex 32)

oc new-project ${MINIO_NS}

#Please ask jooho about the secret file
sed 's/jooholee-pull-secret/custom-registry-secret/g' -i  ~/Downloads/jooholee-secret.yml 
oc create -f ~/Downloads/jooholee-secret.yml --namespace=${MINIO_NS}

oc patch serviceaccount default -p '{"imagePullSecrets": [{"name": "custom-registry-secret"}]}' -n ${MINIO_NS}

sed "s/<accesskey>/$ACCESS_KEY_ID/g"  ${COMMON_MANIFESTS_HOME}/minio.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" | sed 's+quay.io/opendatahub/modelmesh-minio-examples:v0.8.0+quay.io/jooholee/modelmesh-minio-examples:wisdom+g' |tee ./minio-current.yaml | oc -n ${MINIO_NS} apply -f -

sed "s/<accesskey>/$ACCESS_KEY_ID/g" ${COMMON_MANIFESTS_HOME}/minio-secret.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" |sed 's+http://minio.modelmesh-serving.svc:9000+http://minio.minio.svc:9000+g'  | tee ./minio-secret-current.yaml | oc -n ${MINIO_NS} apply -f - 
~~~


**Setup Namespace for Wisdom runtime**
~~~
oc new-project ${test_mm_ns}
oc label namespace ${test_mm_ns} modelmesh-enabled=true --overwrite=true
oc label namespace ${test_mm_ns} opendatahub.io/dashboard=true --overwrite=true

# Create IBM registry secret (You must update `xxxx`)
oc create secret docker-registry ibm-registry-secret --docker-server='us.icr.io' --docker-username='xxxx'  --docker-password='xxxx' --docker-email='asood@us.@ibm.com'

# Minio secret
oc apply -f ./minio-secret-current.yaml -n ${test_mm_ns}
oc apply -f  ${COMMON_MANIFESTS_HOME}/sa_user.yaml -n ${test_mm_ns}
~~~

**Create Watson Runtime**
~~~
oc apply -f ${COMMON_MANIFESTS_HOME}/wisdom-servingruntime.yaml -n ${test_mm_ns}
~~~

**Deploy Wisdom**
~~~
cat <<EOF |oc apply -f - 
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: syntax-izumo-en-custom-2
  annotations:
    serving.kserve.io/deploymentMode: ModelMesh
spec:
  predictor:
    model:
      modelFormat:
        name: watson-nlp-custom
      runtime: watson-nlp-runtime-custom
      storage:
        key: localMinIO
        path: wisdom/aw_model/
EOF

oc patch serviceaccount modelmesh-serving-sa -p '{"imagePullSecrets": [{"name": "ibm-registry-secret"}]}'    

oc delete pod --all --force
~~~

**Check model size**
~~~
oc exec -it deploy/modelmesh-serving-watson-nlp-runtime-custom -c puller -- du -h --max-depth=1 /models
~~~

## Test
~~~
oc port-forward --address 0.0.0.0 service/modelmesh-serving 8033 -n ${test_mm_ns}

git clone git@github.com:rh-aiservices-pilot/ans-wis-model.git
cd ans-wis-model/clientcalls
chmod 777 grpcurl.sh

sed 's/gpu-version-inference-service-v01/syntax-izumo-en-custom-2/g' -i ./grpcurl.sh

./grpcurl.sh "install node on rhel" 
install node on rhel
{
  "label": "- name: install node on rhel\n  yum: name=nodejs state=present enablerepo=nodejs\n",
  "producerId": {
    "name": "Ansible wisdom model",
    "version": "0.0.1"
  }
}

real	0m23.083s
user	0m0.201s
sys	0m0.034s
~~~