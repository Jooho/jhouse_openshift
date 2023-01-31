#!/bin/bash

source ./config.sh
source ../../utils/common.sh

oc new-project ${ODH_NS}

oc create -f kfdef-odh-modelmesh.yaml

check_pod_ready app=model-mesh ${ODH_NS}
check_pod_ready app=odh-model-controller ${ODH_NS}


