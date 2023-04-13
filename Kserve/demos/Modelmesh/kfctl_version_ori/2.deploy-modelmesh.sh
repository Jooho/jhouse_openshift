#!/bin/bash

source "./config.sh"

wget https://raw.githubusercontent.com/red-hat-data-services/odh-manifests/master/kfdef/kfctl_openshift_model_serving.yaml

kfctl build -f kfctl_openshift_model_serving.yaml
cd kustomize/model-mesh/
kustomize build . --load-restrictor LoadRestrictionsNone |oc create -f -

kustomize build . --load-restrictor LoadRestrictionsNone |oc create -f -