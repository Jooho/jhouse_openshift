# Ansible Wisdom Model running on Watson Runtime using Kubernetes(KIND)

*Environment*
 - Kubernetes(KIND)
 - ModelMesh pvc support version

Upstream ModelMesh use clusterServingRuntime so do not need to create the servingRuntime everytime for each namespace.

**Pre-requisite**
- [Install KIND](../ETC/Kind.md)
- [Install Tools](../ETC/ToolBinary.md)

**Pre-resuisite steps & check**
~~~
# Deploy kuberentes
kind create cluster
kubectl cluster-info --context kind-kind

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

# Export ModelMesh manifests
export MM_MANIFESTS_HOME=${DEMO_HOME}/jhouse_openshift/Kserve/docs/Modelmesh/manifests
~~~


## Install Model Mesh

** Deploy required components
~~~
cd $DEMO_HOME

RELEASE=release-0.10
git clone -b $RELEASE --depth 1 --single-branch https://github.com/kserve/modelmesh-serving.git

sed 's+kserve/modelmesh-minio-examples:latest+quay.io/jooholee/modelmesh-minio-examples:wisdom+g' -i ./config/dependencies/quickstart.yaml

kubectl create namespace modelmesh-serving

./scripts/install.sh --namespace modelmesh-serving --quickstart
~~~


**Verify Model Mesh**
~~~
kubectl get pod -n modelmesh-serving
NAME                                  READY   STATUS    RESTARTS   AGE
etcd-7dbb56b4d9-t4mjp                 1/1     Running   0          64s
minio-5574dbcd98-6k85t                1/1     Running   0          64s
modelmesh-controller-85df6856-pzqtn   1/1     Running   0          32s
~~~

## Deploy a Test Model

**Create a namespace**
~~~
cd $DEMO_HOME

export test_mm_ns=mm-1

kubectl create ns ${test_mm_ns}
kubectl label namespace ${test_mm_ns} modelmesh-enabled=true --overwrite=true
kubectl config set-context --current --namespace=${test_mm_ns}
~~~

**Create a minio secret**
You can a storageUri as well. Refer [manifests/sklean-storageUri.yaml](manifests/sklearn-storageUri.yaml)
~~~
ACCESS_KEY_ID=$(kubectl get secret -n modelmesh-serving storage-config -o yaml |yq '.data.localMinIO|@base64d'|jq --raw-output .access_key_id)
SECRET_ACCESS_KEY=$(kubectl get secret -n modelmesh-serving storage-config -o yaml |yq '.data.localMinIO|@base64d'|jq --raw-output .secret_access_key)

sed "s/<accesskey>/$ACCESS_KEY_ID/g" ${MM_MANIFESTS_HOME}/minio-secret.yaml | sed "s/<minio-ns>/${MINIO_NS}/g" | tee ./minio-secret-current.yaml 
sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" -i ./minio-secret-current.yaml 

kubectl apply -f ./minio-secret-current.yaml -n ${test_mm_ns}
~~~

**Create IBM registry secret**
~~~
oc create secret docker-registry ibm-registry-secret --docker-server='us.icr.io' --docker-username='xxxx'  --docker-password='xxxx' --docker-email='asood@us.@ibm.com'
#for "oc debug" optional
kubectl create secret docker-registry redhat-registry-secret --from-file=.dockerconfigjson=/home/jooho/Downloads/pull-secret.txt

kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "ibm-registry-secret"},{"name":"redhat-registry-secret"}]}'    
~~~

**Create Watson Runtime**
~~~
cat <<EOF |oc apply -f - 
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: watson-nlp-runtime-custom
  annotations:
    enable-route: "true"
    enable-auth: "false"
spec:
  #imagePullSecrets:
    #- name: custom-registry-secret
    #- name: ibm-entitlement-key
  containers:
  - env:
      - name: ACCEPT_LICENSE
        value: "true"
      - name: LOG_LEVEL
        value: info
      - name: CAPACITY
        value: "28000000000"
      - name: DEFAULT_MODEL_SIZE
        value: "1773741824"
      - name: METRICS_PORT
        value: "2113"
      - name: GATEWAY_PORT
        value: "8060"
      - name: STRICT_RPC_MODE
        value: "false"
      - name: HF_HOME
        value: "/tmp/"
      #- name: USE_EMBEDDED_PULLER
      #  value: 'true'
    image: us.icr.io/watson-runtime/fmaas-runtime-ansible:0.0.3
    imagePullPolicy: IfNotPresent
    name: watson-nlp-runtime
    resources:
      limits:
        cpu: 2
        memory: 16Gi
      requests:
        cpu: 1
        memory: 16Gi
  grpcDataEndpoint: port:8085
  grpcEndpoint: port:8085
  multiModel: true
  storageHelper:
    disabled: false
  supportedModelFormats:
    - autoSelect: true
      name: watson-nlp-custom
EOF
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
~~~

**Check model size**
~~~
kubectl exec -it deploy/modelmesh-serving-watson-nlp-runtime-custom -c puller -- du -h --max-depth=1 /models
~~~

## Test
~~~
kubectl port-forward --address 0.0.0.0 service/modelmesh-serving 8033 -n ${test_mm_ns}

git clone git@github.com:rh-aiservices-pilot/ans-wis-model.git
cd ans-wis-model/clientcalls
chmod 777 grpcurl.sh

sed 's/gpu-version-inference-service/syntax-izumo-en-custom-2/g' -i ./grpcurl.sh

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