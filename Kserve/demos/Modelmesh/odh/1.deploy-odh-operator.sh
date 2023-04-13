#!/bin/bash

source ./config.sh
source ../../utils/common.sh

oc create -f subs-odh-operator.yaml

check_pod_ready name=opendatahub-operator openshift-operators
