#!/bin/bash

source "./config.sh"


oc delete -n opendatahub -f ./openvino-inference-service.yaml 
oc delete isvc --all -n opendatahub-mm
oc delete ns opendatahub-mm

wget https://raw.githubusercontent.com/red-hat-data-services/odh-manifests/master/kfdef/kfctl_openshift_model_serving.yaml

oc delete servingruntimes.serving.kserve.io --all -n opendatahub
oc delete servingruntimes.serving.kserve.io --all -n opendatahub-mm

kfctl build -f kfctl_openshift_model_serving.yaml
cd kustomize/model-mesh/
kustomize build . --load-restrictor LoadRestrictionsNone |oc delete -f -


oc delete ns minio