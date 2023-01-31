#!/bin/bash

source "./config.sh"
source "../../utils/common.sh"

cd ${DEMO_HOME}
# Get the latest version yaml
# wget https://raw.githubusercontent.com/red-hat-data-services/odh-manifests/master/kfdef/kfctl_openshift_model_serving.yaml -o ${MANIFESTS_DIR}/kfctl_openshift_model_serving.yaml 

kfctl build -f ${MANIFESTS_DIR}/kfctl_openshift_model_serving.yaml

cd kustomize/model-mesh/
kustomize build . --load-restrictor LoadRestrictionsNone |oc create -f -

kustomize build . --load-restrictor LoadRestrictionsNone |oc apply -f -

check_pod_ready app=odh-model-controller ${ODH_NS}
check_pod_ready app=model-mesh ${ODH_NS}

