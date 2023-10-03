# KServe (rawDeployment)

*Environment*
- CRC
- Kserve 0.10
- 
**Pre-requisite**
- [Install CRC](../ETC/CRC.md)
- [Install Cert Manager](../ETC/CertManager.md)
- [Install Tools](../ETC/ToolBinary.md)

**Pre-resuisite steps & check**
~~~
# Export demo home
export DEMO_HOME=/tmp/modelmesh
mkdir -p $DEMO_HOME
cd $DEMO_HOME

# Clone jhouse repository
git clone https://github.com/Jooho/jhouse_openshift.git

# Export common script
source ${DEMO_HOME}/jhouse_openshift/Kserve/demos/utils/common.sh
~~~


## Install Kserve v0.9.0 (rawDeployment)
~~~
KSERVE_VERSION=0.10.0
wget https://github.com/kserve/kserve/releases/download/v${KSERVE_VERSION}/kserve.yaml
sed 's/Serverless/RawDeployment/g' -i ./kserve.yaml
sed 's/example.com/apps-crc.testing/g' -i ./kserve.yaml
kubectl apply -f ./kserve.yaml

wget https://github.com/kserve/kserve/releases/download/v${KSERVE_VERSION}/kserve-runtimes.yaml
kubectl apply -f ./kserve-runtimes.yaml
~~~

## Deploy a Inference Service with sample models
**1. Tensorflow (v1)**
~~~
cd ${DEMO_HOME}

export MODEL_NAME=flower-sample
oc new-project kserve-test
oc create -f jhouse_openshift/Kserve/docs/RawDeployment/manifests/tensorflow.yaml

## HPA is always created now you have to delete hpa as a workaround(https://github.com/kserve/kserve/pull/2658)
oc delete hpa flower-sample-predictor-default


# test
SERVICE_HOSTNAME=$(oc get inferenceservice $MODEL_NAME -o jsonpath='{.status.url}' | cut -d "/" -f 3)

oc expose service $MODEL_NAME-predictor-default --name=$MODEL_NAME  

curl -v \
  -H "Content-Type: application/json" \
  -d @./Upstream/Installation/RawDeployment/tensorflow-input.json \
  http://${SERVICE_HOSTNAME}/v1/models/$MODEL_NAME:predict
~~~

**2. Sklearn(v2)**
~~~
export MODEL_NAME=sklearn-irisv2

oc new-project kserve-test
oc create -f jhouse_openshift/Kserve/docs/RawDeployment/manifests/sklearn.yaml
## HPA is always created now you have to delete hpa as a workaround(https://github.com/kserve/kserve/pull/2658)
oc delete hpa sklearn-irisv2-predictor-default

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
cd ${DEMO_HOME}
oc delete -f jhouse_openshift/Kserve/docs/RawDeployment/manifests/tensorflow.yaml
oc delete -f jhouse_openshift/Kserve/docs/RawDeployment/manifests/sklearn.yaml

oc delete project kserve-test

kubectl delete -f ./kserve.yaml
kubectl delete -f ./kserve-runtimes.yaml
~~~
