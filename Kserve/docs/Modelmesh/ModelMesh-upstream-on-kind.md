# Upstream Model Mesh on KIND

*Environment*
 - Kubernetes(KIND)
 - ModelMesh 0.10

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
cd modelmesh-serving

kubectl create namespace modelmesh-serving
./scripts/install.sh --namespace modelmesh-serving --quickstart
~~~

**Verify Model Mesh**
~~~
kubectl get pod
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

**Deploy sklearn model**
~~~
kubectl create -f ${MM_MANIFESTS_HOME}/sklearn-storage.yaml

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

*using [modelmesh proto](https://github.com/kserve/modelmesh-serving/blob/main/fvt/proto/kfs_inference_v2.proto)(FYI)*
~~~
cd ${MM_MANIFESTS_HOME}

grpcurl \
  -plaintext \
  -proto ./kfs_inference_v2.proto \
  -d "$(envsubst <grpc-input.json)" \
  localhost:8033 \
  inference.GRPCInferenceService.ModelInfer
~~~

*Result*
~~~
{
  "modelName": "example-sklearn-isvc__isvc-6b2eb0b8bf",
  "outputs": [
    {
      "name": "predict",
      "datatype": "INT64",
      "shape": ["1"],
      "contents": {
        "int64Contents": ["8"]
      }
    }
  ]
}
~~~

**REST**
~~~
kubectl port-forward --address 0.0.0.0 service/modelmesh-serving 8008 -n ${test_mm_ns}

MODEL_NAME=example-sklearn-isvc

curl -X POST -k http://localhost:8008/v2/models/${MODEL_NAME}/infer -d @${MM_MANIFESTS_HOME}/rest-input.json
~~~


**notebook**
TBD


## Key Points
-  Data is different for rest/grpc
-  modelName should be in the input data for grpc but it should be in the header for rest


## Clean
~~~
kind delete cluster
~~~

## Reference
- [Send an inference request to your InferenceService](https://github.com/kserve/modelmesh-serving/blob/main/docs/predictors/run-inference.md)
- [Python example](https://github.com/pvaneck/model-serving-sandbox/tree/main/grpc-predict)