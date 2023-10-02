# KCD DEMO SCRIPT

*Environment*
 - [ROSA](https://aws.amazon.com/rosa/)


**Pre-resuisite steps & check**
It assumes that you are in the jhouse_openshift repository (Presentation-KCD-2023 folder)
~~~
git clone git@github.com:Jooho/jhouse_openshift.git

cd jhouse_openshift/Presentation-KCD-2023

env-setup-scripts/setup.sh

source init.sh

cd ${DEMO_HOME}

cp ${DEMO_MANIFESTS_HOME}/kserve/grpc_predict_v2.proto ${DEMO_HOME}/.
~~~

## Install part

**Install required operators**
~~~
${DEMO_SCRIPTS_HOME}/install/prerequisite-operators.sh
~~~

**Install required CRs**
~~~
${DEMO_SCRIPTS_HOME}/install/prerequisite-crs.sh
~~~

**Install KServe**
~~~
${DEMO_SCRIPTS_HOME}/install/odh-kserve-install.sh
~~~

## Demo 1 - how to deploy a model and how to inference by rest/grpc

**Create default ServingRuntimes in $TEST_NS(kserve-demo)**
~~~
oc new-project $TEST_NS
if [[ ! -d ${DEMO_HOME}/kserve ]];then
  cd ${DEMO_HOME}
  git clone https://github.com/kserve/kserve.git 
fi

cd ${DEMO_HOME}/kserve
kustomize build config/runtimes/ |sed "s/ClusterServingRuntime/ServingRuntime/g"|oc create -n kserve-demo -f -
cd -
~~~

**Deploy a sample model(sklearn-iris)**
~~~
export MODEL_NAME=sklearn-iris-v2-rest
oc apply -f ${DEMO_ISV_MANIFESTS_HOME}/sklearn-iris-v2-rest.yaml

wait_for_pods_ready "serving.kserve.io/inferenceservice=${MODEL_NAME}" "${TEST_NS}"
oc wait --for=condition=ready pod -l serving.kserve.io/inferenceservice=${MODEL_NAME} -n ${TEST_NS} --timeout=300s
~~~

*Rest call*
~~~
ISVC_URL=$(oc get isvc ${MODEL_NAME} -ojsonpath='{.status.url}')
curl -k -X POST -H 'accept: application/json'    -H "Content-Type: application/json"   -d @${DEMO_ISV_MANIFESTS_HOME}/sklearn-iris-v2-input-rest.json   ${ISVC_URL}/v2/models/${MODEL_NAME}/infer
~~~

*gRPC call using port-forward*
~~~
export MODEL_NAME=sklearn-iris-v2-rest

oc port-forward deploy/${MODEL_NAME}-predictor-00001-deployment 9000:9000

envsubst < "${DEMO_ISV_MANIFESTS_HOME}/sklearn-iris-v2-input-grpc-generic.json" | grpcurl -plaintext -proto ./grpc_predict_v2.proto -d @ localhost:9000 inference.GRPCInferenceService.ModelInfer
~~~

**Deploy sklean model for grpc call**
~~~
export MODEL_NAME=sklearn-iris-v2-grpc
oc apply -f ${DEMO_ISV_MANIFESTS_HOME}/sklearn-iris-v2-grpc.yaml

wait_for_pods_ready "serving.kserve.io/inferenceservice=${MODEL_NAME}" "${TEST_NS}"
oc wait --for=condition=ready pod -l serving.kserve.io/inferenceservice=${MODEL_NAME} -n ${TEST_NS} --timeout=300s
~~~

~~~
export ISVC_URL=$(oc get isvc ${MODEL_NAME} -ojsonpath='{.status.url}' |awk -F'https://' '{print $2}')
envsubst < "${DEMO_ISV_MANIFESTS_HOME}/sklearn-iris-v2-input-grpc-generic.json" | grpcurl  -insecure   -proto ./grpc_predict_v2.proto   -d @  ${ISVC_URL}:443   inference.GRPCInferenceService.ModelInfer 
~~~

*Clean grpc isvc*
~~~
oc delete isvc,pod --all --force --grace-period=0
~~~

## Demo 2 - Scale to Zero

**Deploy tensorflow model (flowers-sample)**
~~~
export MODEL_NAME=tensorflow-flower-sample
oc create -f ${DEMO_ISV_MANIFESTS_HOME}/tensorflow-flower-sample.yaml

wait_for_pods_ready "serving.kserve.io/inferenceservice=${MODEL_NAME}" "${TEST_NS}"
oc wait --for=condition=ready pod -l serving.kserve.io/inferenceservice=${MODEL_NAME} -n ${TEST_NS} --timeout=300s
~~~

**Verify model is working**
~~~
# https://codebeautify.org/base64-to-image-converter
# ['dandelion', 'daisy', 'tulips', 'sunflowers', 'roses']

ISVC_URL=$(oc get isvc ${MODEL_NAME} -ojsonpath='{.status.url}')
INPUT_DATA=${DEMO_ISV_MANIFESTS_HOME}/tensorflow-v1-input-rest-daisy.json

curl  -k -X POST -H 'accept: application/json'    -H "Content-Type: application/json"   -d @${INPUT_DATA}  ${ISVC_URL}/v1/models/$MODEL_NAME:predict
{
    "predictions": [
        {
            "scores": [0.999114931, 9.2098875e-05, 0.000136786606, 0.00033725868, 0.000300534302, 1.84814126e-05],
            "prediction": 0,
            "key": "   1"
        }
    ]
}

oc patch isvc/${MODEL_NAME}  -p '{"spec":{"predictor": {"minReplicas": 0}}}' -n ${TEST_NS} --type merge
oc get pod -w -n ${TEST_NS}
## around 60s~100s, it starts to scale down
~~~


**Send a request to see it is starting**
~~~
# Watch pods 
# oc get pod -w -n ${TEST_NS}
INPUT_DATA=${DEMO_ISV_MANIFESTS_HOME}/tensorflow-v1-input-rest-rose.json

curl -k -X POST -H 'accept: application/json' -H "Content-Type: application/json" -d @${INPUT_DATA}  ${ISVC_URL}/v1/models/$MODEL_NAME:predict
{
    "predictions": [
        {
            "scores": [2.79400103e-09, 3.62791047e-10, 0.999998093, 2.85873849e-08, 1.85485806e-06, 6.4345973e-10],
            "prediction": 2,
            "key": "   1"
        }
    ]
}
~~~

*Tip*
If you want to control the time to keep pod running before scaling down to zero, you can configure it with Knative configmap(config-autoscaler) in knative-serving namespace.
Refer [this doc](https://knative.dev/docs/serving/autoscaling/scale-to-zero/#scale-to-zero-last-pod-retention-period)


*Clean isvc*
~~~
oc delete isvc,pod --all --force --grace-period=0
~~~

## Demo 3 - Autoscaling management

- Metrics type: [concurrency](https://knative.dev/docs/serving/autoscaling/concurrency/) and [rps](https://knative.dev/docs/serving/autoscaling/rps-target/)

### Concurrency

- Soft limit
  - Annotation `autoscaling.knative.dev/target` can set the **soft limit** rather than a strictly enforced limit, if there is sudden burst of the requests, this value can be exceeded.
- Hard limit
  - `predictor.containerConcurrency` can set the **hard limit** that is an enforced upper bound. If concurrency reaches the hard limit, surplus requests will be buffered and must wait until enough capacity is free to execute the requests.

### Pod count range
- Min
  - `{"spec":{"predictor":{"minReplicas"}}}` can set minimum pod counts. If it is 0, it enabled `scaling to zero` feature
- Max
  - `{"spec":{"predictor":{"maxReplicas"}}}` can set maximum pod counts.

**Deploy tensorflow model (flowers-sample)**
~~~
export MODEL_NAME=tensorflow-flower-sample
oc create -f ${DEMO_ISV_MANIFESTS_HOME}/tensorflow-flower-sample.yaml

wait_for_pods_ready "serving.kserve.io/inferenceservice=${MODEL_NAME}" "${TEST_NS}"
oc wait --for=condition=ready pod -l serving.kserve.io/inferenceservice=${MODEL_NAME} -n ${TEST_NS} --timeout=300s
~~~

**Load testing to verify AutoScaling**
~~~
# setup.sh download the hey binary but if you don't have it, use the following commands:
# wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
# chmod 777 hey_linux_amd64
# sudo mv hey_linux_amd64 /usr/local/bin/hey
oc patch isvc ${MODEL_NAME} -n ${TEST_NS} --type json -p '[{"op": "add", "path": "/spec/predictor/scaleTarget", "value": 1}]'
oc patch isvc ${MODEL_NAME} -n ${TEST_NS} --type json -p '[{"op": "add", "path": "/spec/predictor/scaleMetric", "value": "concurrency"}]'

# Cleanup previous pods.
for i in {1..2}; do oc delete revision tensorflow-flower-sample-predictor-0000${i};  oc delete pod -l serving.knative.dev/revision=tensorflow-flower-sample-predictor-0000${i} --force --grace-period=0; done

hey -z 1s -c 5 -m POST -D $INPUT_DATA ${ISVC_URL}/v1/models/$MODEL_NAME:predict

❯ oc get pod
  NAME                                                        READY   STATUS            RESTARTS   AGE
  flowers-sample-predictor-00003-deployment-554bb59d5-2wx72   3/3     Running           0          13s
  flowers-sample-predictor-00003-deployment-554bb59d5-lbqqr   0/3     PodInitializing   0          15s
  flowers-sample-predictor-00003-deployment-554bb59d5-lgg55   0/3     Init:0/1          0          1s
  flowers-sample-predictor-00003-deployment-554bb59d5-mn4wv   3/3     Running           0          3m9s
  flowers-sample-predictor-00003-deployment-554bb59d5-wvsdw   0/3     Init:0/1          0          1s
~~~
  This will scale out to unlimited.

**Set maximum pods**

Only 2 pods will be created maximum with this change.
~~~
oc patch isvc ${MODEL_NAME} -p '{"spec":{"predictor":{"maxReplicas":2}}}' --type=merge

# Cleanup previous pods.
for i in {3..3}; do oc delete revision tensorflow-flower-sample-predictor-0000${i};  oc delete pod -l serving.knative.dev/revision=tensorflow-flower-sample-predictor-0000${i} --force --grace-period=0; done

# Retest
hey -z 1s -c 5 -m POST -D $INPUT_DATA ${ISVC_URL}/v1/models/$MODEL_NAME:predict

❯ oc get pod
  NAME                                                         READY   STATUS     RESTARTS   AGE
  flowers-sample-predictor-00002-deployment-7687c9cd5c-5m57h   3/3     Running    0          61s
  flowers-sample-predictor-00002-deployment-7687c9cd5c-cqws8   0/3     Init:0/1   0          7s
~~~

**Set hard limits**

~~~
# With default value : unlimited
oc patch isvc ${MODEL_NAME} -n ${TEST_NS} --type json -p '[{"op": "replace", "path": "/spec/predictor/maxReplicas","value": 1}]'
for i in {4..4}; do oc delete revision tensorflow-flower-sample-predictor-0000${i};  oc delete pod -l serving.knative.dev/revision=tensorflow-flower-sample-predictor-0000${i} --force --grace-period=0; done

hey -z 1s -c 10 -m POST -D $INPUT_DATA ${ISVC_URL}/v1/models/$MODEL_NAME:predict
Summary:
  Total:	2.9956 secs
  Slowest:	2.9941 secs
  Fastest:	2.1912 secs
  Average:	2.5006 secs
  Requests/sec:	3.3382

oc patch isvc ${MODEL_NAME} -p '{"spec":{"predictor":{"containerConcurrency":1}}}' --type=merge

# Cleanup previous pods.
for i in {5..5}; do oc delete revision tensorflow-flower-sample-predictor-0000${i};  oc delete pod -l serving.knative.dev/revision=tensorflow-flower-sample-predictor-0000${i} --force --grace-period=0; done

# Retest
hey -z 1s -c 10 -m POST -D $INPUT_DATA ${ISVC_URL}/v1/models/$MODEL_NAME:predict
Summary:
  Total:	4.1731 secs
  Slowest:	3.5072 secs
  Fastest:	0.3623 secs
  Average:	2.1276 secs
  Requests/sec:	3.1152


❯ oc get pod
  NAME                                                         READY   STATUS     RESTARTS   AGE
  flowers-sample-predictor-00002-deployment-7687c9cd5c-5m57h   3/3     Running    0          61s
  flowers-sample-predictor-00002-deployment-7687c9cd5c-cqws8   0/3     Init:0/1   0          7s
~~~

**Clean**
~~~
oc delete isvc,revision,pod --all --force --grace-period=0
~~~
## Demo 4 - Canary Deployment, Rollback, Revision Management

**Deploy sklean model for restful call**
~~~
export MODEL_NAME=sklearn-iris-v1-rest
oc apply -f ${DEMO_ISV_MANIFESTS_HOME}/sklearn-iris-v1-rest-model-1.yaml

wait_for_pods_ready "serving.kserve.io/inferenceservice=${MODEL_NAME}" "${TEST_NS}"
oc wait --for=condition=ready pod -l serving.kserve.io/inferenceservice=${MODEL_NAME} -n ${TEST_NS} --timeout=300s
~~~

*Rest call*
~~~
ISVC_URL=$(oc get isvc ${MODEL_NAME} -ojsonpath='{.status.url}')
INPUT_DATA=${DEMO_ISV_MANIFESTS_HOME}/sklearn-iris-v1-input-rest.json
curl -k -X POST -H 'accept: application/json'    -H "Content-Type: application/json" -d @${INPUT_DATA}  ${ISVC_URL}/v1/models/$MODEL_NAME:predict
~~~

**Deploy sklean model v2 for restful call**
~~~
export MODEL_NAME=sklearn-iris-v1-rest
oc apply -f ${DEMO_ISV_MANIFESTS_HOME}/sklearn-iris-v1-rest-model-2.yaml

wait_for_pods_ready "serving.kserve.io/inferenceservice=${MODEL_NAME},serving.knative.dev/configurationGeneration=2" "${TEST_NS}"
oc wait --for=condition=ready pod -l serving.kserve.io/inferenceservice=${MODEL_NAME},serving.knative.dev/configurationGeneration=2 -n ${TEST_NS} --timeout=300s
~~~

*PREV:90 vs LATEST:10*
~~~
oc get isvc
NAME                   URL                                                                                                  READY   PREV   LATEST   PREVROLLEDOUTREVISION                  LATESTREADYREVISION                    AGE
sklearn-iris-v1-rest   https://sklearn-iris-v1-rest-predictor-kserve-demo.apps.rosa.jlee-test-2.qcg0.p3.openshiftapps.com   True    90     10       sklearn-iris-v1-rest-predictor-00001   sklearn-iris-v1-rest-predictor-00002   3m58s
~~~

**Test request percentage**
~~~
# Terminal 1
oc logs -l serving.kserve.io/inferenceservice=sklearn-iris-v1-rest,serving.knative.dev/configurationGeneration=1 -n kserve-demo -f

# Terminal 2
oc logs -l serving.kserve.io/inferenceservice=sklearn-iris-v1-rest,serving.knative.dev/configurationGeneration=2 -n kserve-demo -f

# send 10 requests
seq 10 | xargs -I {} curl -k -X POST -H 'accept: application/json'    -H "Content-Type: application/json" -d @${INPUT_DATA}  ${ISVC_URL}/v1/models/$MODEL_NAME:predict
# You can see around 1~2 requests sent to second pod.
~~~

**Increase Traffic Percent**
~~~
oc patch isvc/${MODEL_NAME}  -p '{"spec":{"predictor": {"canaryTrafficPercent": 50}}}' -n ${TEST_NS} --type merge

oc get isvc
NAME                   URL                                                                                                  READY   PREV   LATEST   PREVROLLEDOUTREVISION                  LATESTREADYREVISION                    AGE
sklearn-iris-v1-rest   https://sklearn-iris-v1-rest-predictor-kserve-demo.apps.rosa.jlee-test-2.qcg0.p3.openshiftapps.com   True    50     50       sklearn-iris-v1-rest-predictor-00001   sklearn-iris-v1-rest-predictor-00002   15m
~~~
Note: changing the traffic percent does not create a new revision


**Promotion**
~~~
oc patch isvc/${MODEL_NAME} -n ${TEST_NS} --type='json' -p="[{'op': 'remove', 'path': '/spec/predictor/canaryTrafficPercent'}]"

oc get isvc
NAME                   URL                                                                                                  READY   PREV   LATEST   PREVROLLEDOUTREVISION   LATESTREADYREVISION                    AGE
sklearn-iris-v1-rest   https://sklearn-iris-v1-rest-predictor-kserve-demo.apps.rosa.jlee-test-2.qcg0.p3.openshiftapps.com   True           100                              sklearn-iris-v1-rest-predictor-00002   30m
~~~

**Rollback**
~~~
oc patch isvc/${MODEL_NAME} -n ${TEST_NS} --type='json' -p="[{'op': 'add', 'path': '/spec/predictor/canaryTrafficPercent', "value": "0" }]"

oc get pod
NAME                                                              READY   STATUS     RESTARTS   AGE
sklearn-iris-v1-rest-predictor-00001-deployment-7dc957bd5bhbjzd   0/3     Init:0/1   0          3s
sklearn-iris-v1-rest-predictor-00002-deployment-74558fb9665zcww   3/3     Running    0          32m

oc get isvc
NAME                   URL                                                                                                  READY   PREV   LATEST   PREVROLLEDOUTREVISION                  LATESTREADYREVISION                    AGE
sklearn-iris-v1-rest   https://sklearn-iris-v1-rest-predictor-kserve-demo.apps.rosa.jlee-test-2.qcg0.p3.openshiftapps.com   True    100    0        sklearn-iris-v1-rest-predictor-00001   sklearn-iris-v1-rest-predictor-00002   34m

~~~

**Route traffic using tag**
~~~   
oc annotate isvc ${MODEL_NAME}  serving.kserve.io/enable-tag-routing="true"
~~~

- Check url
~~~
oc get isvc ${MODEL_NAME} -ojsonpath="{.status.components.predictor}"  | jq

{
  "address": {
    "url": "http://sklearn-iris-v1-rest-predictor.kserve-demo.svc.cluster.local"
  },
  "latestCreatedRevision": "sklearn-iris-v1-rest-predictor-00003",
  "latestReadyRevision": "sklearn-iris-v1-rest-predictor-00003",
  "latestRolledoutRevision": "sklearn-iris-v1-rest-predictor-00001",
  "previousRolledoutRevision": "sklearn-iris-v1-rest-predictor-00001",
  "traffic": [
    {
      "latestRevision": true,
      "percent": 0,
      "revisionName": "sklearn-iris-v1-rest-predictor-00003",
      "tag": "latest",
      "url": "https://latest-sklearn-iris-v1-rest-predictor-kserve-demo.apps.rosa.jlee-test-2.qcg0.p3.openshiftapps.com"
    },
    {
      "latestRevision": false,
      "percent": 100,
      "revisionName": "sklearn-iris-v1-rest-predictor-00001",
      "tag": "prev",
      "url": "https://prev-sklearn-iris-v1-rest-predictor-kserve-demo.apps.rosa.jlee-test-2.qcg0.p3.openshiftapps.com"
    }
  ],
  "url": "https://sklearn-iris-v1-rest-predictor-kserve-demo.apps.rosa.jlee-test-2.qcg0.p3.openshiftapps.com"
}

~~~

*Previous Model Rest call*
~~~
ISVC_URL=$(oc get isvc ${MODEL_NAME} -ojsonpath='{.status.url}'|cut -d'/' -f3)
INPUT_DATA=${DEMO_ISV_MANIFESTS_HOME}/sklearn-iris-v1-input-rest.json
curl -k -X POST -H 'accept: application/json'    -H "Content-Type: application/json" -d @${INPUT_DATA}  https://prev-${ISVC_URL}/v1/models/$MODEL_NAME:predict
~~~

*Latest Model Rest call*
~~~
curl -k -X POST -H 'accept: application/json'    -H "Content-Type: application/json" -d @${INPUT_DATA}  https://latest-${ISVC_URL}/v1/models/$MODEL_NAME:predict
~~~

**Revision Management**
~~~
oc get configmap config-gc -n knative-serving -o yaml
..
    # Duration since creation before considering a revision for GC or "disabled".
    retain-since-create-time: "48h"

    # Duration since active before considering a revision for GC or "disabled".
    retain-since-last-active-time: "15h"

    # Minimum number of non-active revisions to retain.
    min-non-active-revisions: "20"

    # Maximum number of non-active revisions to retain
    # or "disabled" to disable any maximum limit.
    max-non-active-revisions: "1000"

..
~~~

---
## Optional


**Deploy sample flan-t5 LLM with Caikit**
~~~
${DEMO_SCRIPTS_HOME}/test/deploy-model.sh
~~~

**Test inference service for sample flan-t5 LLM**
~~~
${DEMO_SCRIPTS_HOME}/test/grpc-call.sh
~~~

**Uninstall KServe**
~~~
${DEMO_SCRIPTS_HOME}/uninstall/odh-kserve-uninstall.sh
~~~

**Uninstall Dependencies**
~~~
${DEMO_SCRIPTS_HOME}/uninstall/dependencies-uninstall.sh
~~~
