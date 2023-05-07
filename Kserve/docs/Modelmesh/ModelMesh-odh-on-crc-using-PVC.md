# ODH Model Mesh on CRC using PVC

*Environment*
 - Kubernetes(KIND)
 - ModelMesh pvc support version

Upstream ModelMesh use clusterServingRuntime so do not need to create the servingRuntime everytime for each namespace.

**Pre-requisite**
- [CRC](../ETC/CRC.md)
- [Install Tools](../ETC/ToolBinary.md)

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

# Export ModelMesh manifests
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
~~~

**Deploy Model Mesh**
~~~
oc new-project ${ODH_NS}
oc create -f  ${MM_MANIFESTS_HOME}/kfdef-odh-modelmesh.yaml

check_pod_ready app=model-mesh ${ODH_NS}
check_pod_ready app=odh-model-controller ${ODH_NS}

oc create -f  ${MM_MANIFESTS_HOME}/allowAnyPvc-config.yaml
oc delete pod -l control-plane=modelmesh-controller --force 

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

**Setup Namespace for test namespace**

~~~
oc new-project ${test_mm_ns}
oc label namespace ${test_mm_ns} modelmesh-enabled=true --overwrite=true
oc label namespace ${test_mm_ns} opendatahub.io/dashboard=true --overwrite=true

# Minio secret
oc apply -f ./minio-secret-current.yaml -n ${test_mm_ns}
oc apply -f  ${COMMON_MANIFESTS_HOME}/sa_user.yaml -n ${test_mm_ns}

#Create servingruntime
oc create -f ${MM_MANIFESTS_HOME}/servingruntime_mlserver.yaml
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
  labels:
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
        
check_pod_ready name=model-copy-pod ${test_mm_ns}  

oc rsync ${MM_MANIFESTS_HOME}/sklearn  model-copy-pod:/data

oc delete pod model-copy-pod --force
~~~


**Deploy sklearn model**
You can a storage as well. Refer [manifests/sklean-storage-pvc.yaml](manifests/sklearn-storage-pvc.yaml)
~~~
kubectl create -f ${MM_MANIFESTS_HOME}/sklearn-storageUri-pvc.yaml

check_pod_ready modelmesh-service=modelmesh-serving ${test_mm_ns}

kubectl get pod
NAME                                             READY   STATUS    RESTARTS   AGE
modelmesh-serving-mlserver-0.x-cff55b875-mg4hc   5/5     Running   0          21s



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
