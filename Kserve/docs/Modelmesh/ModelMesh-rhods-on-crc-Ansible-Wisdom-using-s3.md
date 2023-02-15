# Model Mesh with RHODS on CRC using S3 for Ansible Wisdom Model on Watson Runtime GPU

*Environment*
 - [CRC](../ETC/CRC.md)
 - [Custom RHODS](https://github.com/rh-aiservices-pilot/ans-wis-model/blob/main/deploy.rhods.livebuild.and.override.sh)

**Pre-requisite steps & check**
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
export test_mm_ns=wisdom
export wisdom_img_tag=wisdom-v2   #latest version is wisdom-v2(0.0.6)
export runtime_version=0.0.6   #latest version is 0.0.6(wisdom-v2)
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

oc delete pod -l control-plane=modelmesh-controller --force 
~~~


## Test model

**Setup Namespace for Wisdom runtime**
~~~
oc new-project ${test_mm_ns}
oc label namespace ${test_mm_ns} modelmesh-enabled=true --overwrite=true
oc label namespace ${test_mm_ns} opendatahub.io/dashboard=true --overwrite=true

# Create S3 Secret
cat <<EOF |oc apply -f - 
apiVersion: v1
kind: Secret
metadata:
  name: storage-config-aws
stringData:
  aws-connection-answis-dev: |
    {
      "type": "s3",
      "access_key_id": "XXX",
      "secret_access_key": "XXXX",
      "endpoint_url": "http://s3.amazonaws.com",
      "default_bucket": "answis-dev",
      "region": "us-east-1"
    }
EOF

# Create IBM registry secret (You must update `xxxx`)
oc create secret docker-registry ibm-registry-secret --docker-server='us.icr.io' --docker-username='xxxx'  --docker-password='xxxx' --docker-email='user@account.com'
~~~

**Create Watson Runtime**
~~~
oc apply -f ${COMMON_MANIFESTS_HOME}/wisdom-servingruntime-${runtime_version}.yaml -n ${test_mm_ns}
~~~

**Deploy Wisdom**

You have to check key/path value according to your environment.
~~~
cat <<EOF |oc apply -f - 
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: gpu-version-inference-service-v01
  labels:
    opendatahub.io/dashboard: 'true'
  annotations:
    serving.kserve.io/deploymentMode: ModelMesh
spec:
  predictor:
    model:
      modelFormat:
        name: watson-nlp-custom
      runtime: model-server-wisdom-dev-gpu
      storage:
        key: aws-connection-answis-dev
        path: model-files/ansible_ibm_model/aw_model/
EOF

sleep 2

oc patch serviceaccount modelmesh-serving-sa -p '{"imagePullSecrets": [{"name": "ibm-registry-secret"}]}'    

oc delete pod --all --force
~~~

**Check model size**
~~~
oc exec -it deploy/modelmesh-serving-model-server-wisdom-dev-gpu -c puller -- du -h --max-depth=1 /models
~~~

## Test
~~~
oc port-forward --address 0.0.0.0 service/modelmesh-serving 8033 -n ${test_mm_ns}

git clone git@github.com:rh-aiservices-pilot/ans-wis-model.git
cd ans-wis-model/clientcalls
chmod 777 grpcurl.sh

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
