# KServe (rawDeployment)

## Installation
- [Install Cert Manager](./CertManager.md)

## Install Kserve v0.9.0 (rawDeployment)
~~~
wget https://github.com/kserve/kserve/releases/download/v0.9.0/kserve.yaml
sed 's/Serverless/RawDeployment/g' -i ./kserve.yaml
sed 's/example.com/apps-crc.testing/g' -i ./kserve.yaml
kubectl apply -f ./kserve.yaml

wget https://github.com/kserve/kserve/releases/download/v0.9.0/kserve-runtimes.yaml
kubectl apply -f ./kserve-runtimes.yaml
~~~

## Deploy a Inference Service with sample models
**1. Tensorflow (v1)**
~~~
git clone git@github.com:Jooho/jhouse_openshift.git
cd docs/kserve/demos/RawDeployment

export MODEL_NAME=flower-sample
oc new-project kserve-test
oc create -f ../demos/RawDeployment/tensorflow.yaml
oc expose service $MODEL_NAME-predictor-default --name=$MODEL_NAME  

# test
SERVICE_HOSTNAME=$(kubectl get inferenceservice $MODEL_NAME -o jsonpath='{.status.url}' | cut -d "/" -f 3)

curl -v \
  -H "Content-Type: application/json" \
  -d @./Upstream/Installation/RawDeployment/tensorflow-input.json \
  http://${SERVICE_HOSTNAME}/v1/models/$MODEL_NAME:predict
~~~

**2. Sklearn(v2)**
~~~
export MODEL_NAME=sklearn-irisv2
oc new-project kserve-test
oc create -f ../demos/RawDeployment/sklearn.yaml

# test
SERVICE_HOSTNAME=$(kubectl get inferenceservice $MODEL_NAME -o jsonpath='{.status.url}' | cut -d "/" -f 3)

oc expose service $MODEL_NAME-predictor-default --name=$MODEL_NAME  --path /v2/models/$MODEL_NAME

curl -v \
  -H "Content-Type: application/json" \
  -d @./Upstream/Installation/RawDeployment/sklearn-input.json \
  http://${SERVICE_HOSTNAME}/v2/models/$MODEL_NAME/infer
~~~



## Clean UP
~~~
oc delete -f ../demos/RawDeployment/tensorflow.yaml
oc delete -f ../demos/RawDeployment/sklearn.yaml
oc delete project kserve-test

kubectl delete -f ./kserve.yaml
kubectl delete -f ./kserve-runtimes.yaml
~~~