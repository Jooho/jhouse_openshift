# Upstream Model Mesh on KIND using PVC

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

# Export common manifests dir
export COMMON_MANIFESTS_HOME=${DEMO_HOME}/jhouse_openshift/Kserve/docs/Common/manifests
~~~

## Install Model Mesh

** Deploy required components
~~~
cd $DEMO_HOME

RELEASE=release-0.10
git clone -b $RELEASE --depth 1 --single-branch https://github.com/kserve/modelmesh-serving.git

cd modelmesh-serving

# Change images to test PVC support
## allowAnyPVC =true
## Change adapter to image = jooholee/modelmesh-runtime-adapter
## Change adapter to tag = pvc

cd  config/manager; kustomize edit set image modelmesh-controller=quay.io/jooholee/modelmesh-controller:pvc; cd ../../
name=quay.io/jooholee/modelmesh-runtime-adapter yq '.storageHelperImage.name=strenv(name)' -i ./config/default/config-defaults.yaml
tag=pvc yq '.storageHelperImage.tag=strenv(tag)' -i ./config/default/config-defaults.yaml
yq '.allowAnyPVC |= . + true ' -i ./config/default/config-defaults.yaml

# Please ask jooho about the secret file (this secret is for the custom images from quay.io)

kubectl create namespace modelmesh-serving
sed 's/jooholee-pull-secret/custom-registry-secret/g' -i  ~/Downloads/jooholee-secret.yml 
kubectl create -f ~/Downloads/jooholee-secret.yml --namespace=modelmesh-serving

kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "custom-registry-secret"}]}' -n modelmesh-serving  

./scripts/install.sh --namespace modelmesh-serving --quickstart
~~~

**NOTE** During the installation, you have to execute the following command to pull the custom modelmesh serving image
~~~
kubectl patch serviceaccount modelmesh-controller -p '{"imagePullSecrets": [{"name": "custom-registry-secret"}]}' -n modelmesh-serving
kubectl delete pod -l control-plane=modelmesh-controller --force -n modelmesh-serving
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

kubectl create -f ~/Downloads/jooholee-secret.yml --namespace=${test_mm_ns}

kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "custom-registry-secret"}]}' -n ${test_mm_ns}
~~~


**Create a minio secret**

~~~
ACCESS_KEY_ID=$(kubectl get secret -n modelmesh-serving storage-config -o yaml |yq '.data.localMinIO|@base64d'|jq --raw-output .access_key_id)
SECRET_ACCESS_KEY=$(kubectl get secret -n modelmesh-serving storage-config -o yaml |yq '.data.localMinIO|@base64d'|jq --raw-output .secret_access_key)

sed "s/<accesskey>/$ACCESS_KEY_ID/g" ${COMMON_MANIFESTS_HOME}/minio-secret.yaml | sed "s/<minio-ns>/${MINIO_NS}/g" | tee ./minio-secret-current.yaml 
sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" -i ./minio-secret-current.yaml 

kubectl apply -f ./minio-secret-current.yaml -n ${test_mm_ns}
~~~

**Copy the model from minio to PVC**
~~~
cat <<EOF|oc create -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: model-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 30G
EOF

cat <<EOF|oc create -f -
kind: Pod
apiVersion: v1
metadata:
  name: model-copy-pod
spec:
  containers:
  - name: target
    command:  
    - /bin/sh
    - -c
    - 'trap : TERM INT; sleep 1d'
    image: docker.io/openshift/origin-cli
    volumeMounts:
      - name: model-pvc
        mountPath: "data"
  restartPolicy: "Never"
  volumes:
    - name: model-pvc
      persistentVolumeClaim:
        claimName: model-pvc
EOF
        
        
oc rsync ${MM_MANIFESTS_HOME}/sklearn  model-copy-pod:/data

oc delete pod model-copy-pod --force
~~~

**Create runtimes in the namespace**
~~~
cd ${DEMO_HOME}/modelmesh-serving
kustomize build ./config/namespace-runtimes --load-restrictor LoadRestrictionsNone |oc create -f -
~~~

**Deploy sklearn model**
You can deploy a storage as well. Refer [manifests/sklean-storage-pvc.yaml](manifests/sklearn-storage-pvc.yaml)
~~~
kubectl create -f ${MM_MANIFESTS_HOME}/sklearn-storageUri-pvc.yaml

check_pod_ready modelmesh-service=modelmesh-serving ${test_mm_ns}

kubectl get pod
NAME                                              READY   STATUS    RESTARTS   AGE
modelmesh-serving-mlserver-0.x-8664bdcddb-2dxn4   4/4     Running   0          4m18s
modelmesh-serving-mlserver-0.x-8664bdcddb-w5fc9   4/4     Running   0          4m18s


kubectl get isvc
NAME                   URL                                  READY   PREV   LATEST   PREVROLLEDOUTREVISION   LATESTREADYREVISION   AGE
example-sklearn-isvc   grpc://modelmesh-serving.mm-1:8033   True                                                                  16m
~~~

## Test inference 

### gRPC
- [gRPC proto for kserve](https://github.com/kserve/kserve/blob/master/docs/predict-api/v2/grpc_predict_v2.proto)

*Pre-requisite(optional if you use generated files)*
~~~
pip install -r ${MM_MANIFESTS_HOME}/requirements.txt

python -m grpc_tools.protoc -I${MM_MANIFESTS_HOME}/. --python_out=${MM_MANIFESTS_HOME}/. --grpc_python_out=${MM_MANIFESTS_HOME}/. ${MM_MANIFESTS_HOME}/grpc_predict_v2.proto
~~~


**grpcurl**
~~~
kubectl port-forward --address 0.0.0.0 service/modelmesh-serving 8033 -n ${test_mm_ns}

cd ${MM_MANIFESTS_HOME}
export MODEL_NAME=example-sklearn-isvc

grpcurl \
  -plaintext \
  -proto ./grpc_predict_v2.proto \
  -d "$(envsubst <grpc-input.json )" \
  localhost:8033 \
  inference.GRPCInferenceService.ModelInfer
~~~

## Build Processes
**modelmesh-runtime-adapter**
~~~
git clone --branch add-pvc-support    https://github.com/chinhuang007/modelmesh-runtime-adapter.git
cd modelmesh-runtime-adapter

git remote add upstream https://github.com/kserve/modelmesh-runtime-adapter.git
git fetch upstream
git merge upstream/main

make build

docker tag kserve/modelmesh-runtime-adapter:latest quay.io/jooholee/modelmesh-runtime-adapter:pvc

docker push quay.io/jooholee/modelmesh-runtime-adapter:pvc
~~~

**modelmesh-serving**
~~~
git clone --branch add-pvc https://github.com/chinhuang007/modelmesh-serving.git

cd modelmesh-serving
git remote add upstream https://github.com/kserve/modelmesh-serving.git
git fetch upstream
git merge upstream/main


export KO_DOCKER_REPO=quay.io/jooholee
make build

docker tag kserve/modelmesh-controller:latest quay.io/jooholee/modelmesh-controller:pvc

docker push quay.io/jooholee/modelmesh-controller:pvc
~~~

## Troubleshooting Tips
~~~
# for "oc debug node"
# for "oc debug node"
kubectl create secret docker-registry redhat-registry-secret --from-file=.dockerconfigjson=/home/jooho/Downloads/pull-secret.txt

kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "custom-registry-secret"},{"name":"redhat-registry-secret"}]}'     
~~~
