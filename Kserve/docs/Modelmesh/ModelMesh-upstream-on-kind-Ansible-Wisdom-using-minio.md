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

export wisdom_img_tag=wisdom   #latest version is wisdom-v2(0.0.6)
export runtime_version=0.0.3   #latest version is 0.0.6(wisdom-v2)
~~~


## Install Model Mesh

** Deploy required components
~~~
cd $DEMO_HOME

RELEASE=release-0.10
git clone -b $RELEASE --depth 1 --single-branch https://github.com/kserve/modelmesh-serving.git

sed "s+kserve/modelmesh-minio-examples:latest+quay.io/jooholee/modelmesh-minio-examples:${wisdom_img_tag}+g" -i ./config/dependencies/quickstart.yaml

kubectl create namespace modelmesh-serving

#Please ask jooho about the secret file
kubectl create namespace modelmesh-serving

sed 's/jooholee-pull-secret/custom-registry-secret/g' -i  ~/Downloads/jooholee-secret.yml 
kubectl create -f ~/Downloads/jooholee-secret.yml --namespace=modelmesh-serving

kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "custom-registry-secret"}]}' -n modelmesh-serving  


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
oc create secret docker-registry ibm-registry-secret --docker-server='us.icr.io' --docker-username='xxxx'  --docker-password='xxxx' --docker-email='user@account.com'
#for "oc debug" optional
kubectl create secret docker-registry redhat-registry-secret --from-file=.dockerconfigjson=/home/jooho/Downloads/pull-secret.txt

kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "ibm-registry-secret"},{"name":"redhat-registry-secret"}]}'    
~~~

**Create Watson Runtime**
~~~
kubectl apply -f ${COMMON_MANIFESTS_HOME}/wisdom-servingruntime-${runtime_version}.yaml -n ${test_mm_ns}
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
