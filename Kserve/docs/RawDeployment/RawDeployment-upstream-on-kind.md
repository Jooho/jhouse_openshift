# KServe (rawDeployment)

*Environment*
 - Kubernetes(KIND)
 - Kserve 0.10

**Pre-requisite**
- [Install KIND](../ETC/Kind.md)
- [Install Cert Manager](../ETC/CertManager.md)
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

# Check cert manager installed
kubectl get ns  cert-manager || echo "ERROR!! CERT MANAGER NEEDED" 

# Export demo home
export DEMO_HOME=/tmp/modelmesh
mkdir -p $DEMO_HOME
cd $DEMO_HOME

# Clone jhouse repository
git clone https://github.com/Jooho/jhouse_openshift.git

# Export common script
source ${DEMO_HOME}/jhouse_openshift/Kserve/demos/utils/common.sh

# Export ModelMesh manifests
export RAW_MANIFESTS_HOME=${DEMO_HOME}/jhouse_openshift/Kserve/docs/RawDeployment/manifests
~~~

## Install Kserve (rawDeployment)
~~~
KSERVE_VERSION=0.10.0
wget https://github.com/kserve/kserve/releases/download/v${KSERVE_VERSION}/kserve.yaml
sed 's/Serverless/RawDeployment/g' -i ./kserve.yaml
kubectl apply -f ./kserve.yaml

wget https://github.com/kserve/kserve/releases/download/v${KSERVE_VERSION}/kserve-runtimes.yaml
kubectl apply -f ./kserve-runtimes.yaml

check_pod_ready control-plane=kserve-controller-manager kserve
~~~

## Deploy a Inference Service with sample models
**1. Tensorflow (v1)**
~~~
cd ${DEMO_HOME}

export MODEL_NAME=flower-sample
kubectl create ns kserve-test
kubectl label ns kserve-test modelmesh-enabled=true --overwrite=true
kubectl create -f jhouse_openshift/Kserve/docs/RawDeployment/manifests/tensorflow.yaml -n kserve-test

## HPA is always created now you have to delete hpa as a workaround(https://github.com/kserve/kserve/pull/2658)
kubectl delete hpa flower-sample-predictor-default

# test
oc port-forward svc/flower-sample-predictor-default 7777:80

curl -v \
  -H "Content-Type: application/json" \
  -d @./jhouse_openshift/Kserve/docs/RawDeployment/manifests/tensorflow-input.json \
  http://localhost:7777/v1/models/$MODEL_NAME:predict


{
    "predictions": [
        {
            "prediction": 0,
            "key": "   1",
            "scores": [0.999114931, 9.2098875e-05, 0.000136786344, 0.000337257865, 0.000300533167, 1.84813962e-05]
        }
    ]
}
~~~

**2. Sklearn(v2)**
~~~
export MODEL_NAME=sklearn-irisv2

kubectl create ns kserve-test
kubectl label ns kserve-test modelmesh-enabled=true --overwrite=true
kubectl create -f jhouse_openshift/Kserve/docs/RawDeployment/manifests/sklearn.yaml -n kserve-test

## HPA is always created now you have to delete hpa as a workaround(https://github.com/kserve/kserve/pull/2658)
kubectl delete hpa sklearn-irisv2-predictor-default

# test
kubectl port-forward svc/sklearn-irisv2-predictor-default 7778:80

curl -v \
  -H "Content-Type: application/json" \
  -d @./jhouse_openshift/Kserve/docs/RawDeployment/manifests/sklearn-input.json \
  http://localhost:7778/v2/models/$MODEL_NAME/infer

{"model_name":"sklearn-irisv2","model_version":null,"id":"356f28e6-1ff0-43df-bd67-6898b971b09d","parameters":null,"outputs":[{"name":"predict","shape":[2],"datatype":"INT64","parameters":null,"data":[1,1]}]}
~~~



## Clean UP
~~~
cd ${DEMO_HOME}
kubectl delete -f jhouse_openshift/Kserve/docs/RawDeployment/manifests/tensorflow.yaml
kubectl delete -f jhouse_openshift/Kserve/docs/RawDeployment/manifests/sklearn.yaml

kubectl delete ns kserve-test

kubectl delete -f ./kserve.yaml
kubectl delete -f ./kserve-runtimes.yaml
~~~