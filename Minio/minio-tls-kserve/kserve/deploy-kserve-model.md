# Deploy Kserve and a model

## Pre-resuisite

Follow this [pre-requisite installation](https://github.com/opendatahub-io/caikit-tgis-serving/blob/main/demo/kserve/Kserve.md#prerequisite-installation) before installing kserve.

~~~
export TEST_NS=kserve-demo
oc new-project ${TEST_NS}
oc patch smmr/default -n istio-system --type='json' -p="[{'op': 'add', 'path': '/spec/members/-', 'value': \"$TEST_NS\"}]"
sed "s/<test_ns>/$TEST_NS/g" manifests/service-mesh/peer-authentication-test-ns.yaml | tee ./peer-authentication-test-ns-current.yaml | oc apply -f -
# we need this because of https://access.redhat.com/documentation/en-us/openshift_container_platform/4.12/html/serverless/serving#serverless-domain-mapping-custom-tls-cert_domain-mapping-custom-tls-cert
~~~

## Deploy Kserve
~~~
oc project kserve
oc create -f custom-manifests/opendatahub/operators.yaml
sleep 30
oc create -f custom-manifests/opendatahub/kfdef-kserve-op.yaml
~~~

## Create Caikit ServingRuntime
~~~
oc apply -f ./manifests/caikit/caikit-servingruntime.yaml
~~~

## Deploy example model(flan-t5-samll)

~~~
oc apply -f ./minio-secret-current.yaml 
oc create -f ./serviceaccount-minio-current.yaml

oc apply -f ./manifests/caikit/caikit-isvc.yaml -n ${TEST_NS}
~~~

## gRPC Test
~~~
export KSVC_HOSTNAME=$(oc get ksvc caikit-example-isvc-predictor -o jsonpath='{.status.url}' | cut -d'/' -f3)
grpcurl -insecure -d '{"text": "At what temperature does liquid Nitrogen boil?"}' -H "mm-model-id: flan-t5-small-caikit" ${KSVC_HOSTNAME}:443 caikit.runtime.Nlp.NlpService/TextGenerationTaskPredict
~~~
