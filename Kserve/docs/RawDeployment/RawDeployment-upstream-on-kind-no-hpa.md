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
git clone https://github.com/kserve/kserve.git
cd kserve

export controller_img=quay.io/jooholee/manager-12782ae64d3f5f3dbe4595b05a2cb78d@sha256:f096b4b550d56a9efe064792d722efb6af82d32aad0b4c8a27797d88e29dc0c4

cat <<EOF >./deploy-target-kserve.sh
#!/bin/bash
cd config/default; kustomize edit add resource certmanager/certificate.yaml; cd ../..
mode='{"defaultDeploymentMode":"RawDeployment"}' yq -i '.data.deploy=strenv(mode)' config/configmap/inferenceservice.yaml
yq -i '.spec.template.spec.containers.0.image=env(controller_img)' config/overlays/development/manager_image_patch.yaml
kustomize build config/overlays/development | kubectl apply -f -
kubectl wait --for=condition=ready pod -l control-plane=kserve-controller-manager -n kserve --timeout=300s
kustomize build config/runtimes | kubectl apply -f -
EOF

chmod 777 ./deploy-target-kserve.sh
./deploy-target-kserve.sh

kubectl create ns kserve-test
kubectl config set-context --current --namespace=kserve-test

cat <<EOF| kubectl apply -f -
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  annotations:
    "serving.kserve.io/autoscalerClass": "none"
    "serving.kserve.io/deploymentMode": "RawDeployment"
  name: "sklearn-irisv2"
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      runtime: kserve-mlserver
      storageUri: "gs://seldon-models/sklearn/mms/lr_model"
EOF
~~~

## Deploy a Inference Service with sample models
**1. Tensorflow (v1)**
~~~
cd ${DEMO_HOME}

export MODEL_NAME=flower-sample
kubectl create ns kserve-test
kubectl create -f jhouse_openshift/Kserve/docs/RawDeployment/manifests/tensorflow-nohpa.yaml

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
kubectl create -f jhouse_openshift/Kserve/docs/RawDeployment/manifests/sklearn-nohpa.yaml

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