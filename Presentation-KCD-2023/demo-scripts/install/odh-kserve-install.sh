#!/bin/bash
# Environment variables
# - CHECK_UWM: Set this to "false", if you want to skip the User Workload Configmap check message
# - TARGET_OPERATOR: Set this among odh, rhods or brew, if you want to skip the question in the script.
set -o pipefail
set -o nounset
set -o errtrace
# set -x   #Uncomment this to debug script.

source "$(dirname "$(realpath "$0")")/../env.sh"
source "$(dirname "$(realpath "$0")")/../utils.sh"

echo
info "[INFO] Deploy KServe"
echo

oc create -f ${DEMO_MANIFESTS_HOME}/opendatahub/kserve-dsc.yaml

wait_for_pods_ready "control-plane=kserve-controller-manager" "${KSERVE_OPERATOR_NS}"

success "[SUCCESS] Successfully deployed KServe operator! Ready for demo" 
