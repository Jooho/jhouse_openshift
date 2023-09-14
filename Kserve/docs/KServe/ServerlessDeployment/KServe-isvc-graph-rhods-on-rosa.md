# KServe ServerlessDeployment with RHODS on ROSA

*Environment*
 - [ROSA](https://aws.amazon.com/rosa/)


**Pre-resuisite steps & check**
It assumes that you are in the jhouse_openshift repository (Kserve/docs/KServe/ServerlessDeployment folder)
~~~
scripts/setup.sh

source init.sh

cd ${DEMO_HOME}

cp ${MM_MANIFESTS_HOME}/grpc_predict_v2.proto .
~~~


## Installation KServe

**Install Pre-requisites(Serverless, Service Mesh) and KServe**
~~~
git clone git@github.com:Jooho/openshift-ai-serving-test.git
cd openshift-ai-serving-test

./commands/kserve-rhods-install.sh
~~~

## Create all runtimes
~~~
cd ..
git clone git@github.com:kserve/kserve.git
cd kserve
kustomize build config/runtimes |oc create -f -
cd -
~~~

----

## Sequence

[reference](https://github.com/kserve/kserve/tree/master/docs/samples/graph)

**Deploy Sequence inference graph**
~~~
oc apply -f ${MM_MANIFESTS_HOME}/graph-sequence.yaml
~~~

*Rest call*
~~~
cp ${MM_MANIFESTS_HOME}/irisv1-input-graph.json .
IG_URL=$(oc get ig model-chainer -ojsonpath='{.status.url}')
curl -vk  ${IG_URL} -d @./irisv1-input-graph.json
~~~

## Splitter
[reference](https://github.com/kserve/kserve/tree/master/docs/samples/graph)

**Deploy Splitter inference graph**
~~~
oc apply -f ${MM_MANIFESTS_HOME}/graph-splitter.yaml
~~~

*Rest call*
~~~
cp ${MM_MANIFESTS_HOME}/irisv1-input-graph.json .
IG_URL=$(oc get ig splitter-model -ojsonpath='{.status.url}')
curl -vk  ${IG_URL} -d @./irisv1-input-graph.json
~~~

## Switch
**Deploy Switch inference graph**
~~~
oc apply -f ${MM_MANIFESTS_HOME}/graph-switch.yaml
~~~

*Rest call*
~~~
cp ${MM_MANIFESTS_HOME}/irisv1-input-graph.json .
IG_URL=$(oc get ig model-switch -ojsonpath='{.status.url}')
curl -vk  ${IG_URL} -d @./irisv1-input-graph.json
~~~

## Ensemble
**Deploy ensemble inference graph**
~~~
oc apply -f ${MM_MANIFESTS_HOME}/graph-ensemble.yaml
~~~

*Rest call*
~~~
cp ${MM_MANIFESTS_HOME}/irisv1-input-graph.json .
IG_URL=$(oc get ig model-ensemble -ojsonpath='{.status.url}')
curl -vk  ${IG_URL} -d @./irisv1-input-graph.json
~~~

## Cleanup
~~~
oc delete isvc,ig --all -n ${test_ns} 
oc delete ns ${test_ns} --wait

#cd openshift-ai-serving-test
#./commands/kserve-dependencies-clean.sh
~~~
