
#!/bin/bash
set -o pipefail
set -o nounset
set -o errtrace
# set -x   #Uncomment this to debug script.

source "$(dirname "$(realpath "$0")")/../env.sh"
source "$(dirname "$(realpath "$0")")/../utils.sh"

# Remove test namespace from SMMR
INDEX=$(oc get servicemeshmemberroll/default -n istio-system -o jsonpath='{.spec.members[*]}')
INDEX=$(echo ${INDEX} | tr ' ' '\n' | grep -n ${TEST_NS} | cut -d: -f1)

if [ -z "${INDEX}" ]; then
  echo "Target member ${TEST_NS} not found in the array."
fi
oc patch servicemeshmemberroll/default -n istio-system --type='json' -p="[{'op': 'remove', 'path': \"/spec/members/$((INDEX - 1))\"}]"


# Remove kserve namespace from SMMR
INDEX=$(oc get servicemeshmemberroll/default -n istio-system -o jsonpath='{.spec.members[*]}')
INDEX=$(echo ${INDEX} | tr ' ' '\n' | grep -n ${KSERVE_OPERATOR_NS} | cut -d: -f1)

if [ -z "${INDEX}" ]; then
  echo "Target member ${TEST_NS} not found in the array."
fi
oc patch servicemeshmemberroll/default -n istio-system --type='json' -p="[{'op': 'remove', 'path': \"/spec/members/$((INDEX - 1))\"}]"

# Remove KServe
oc delete validatingwebhookconfiguration inferencegraph.serving.kserve.io  inferenceservice.serving.kserve.io 
oc delete mutatingwebhookconfiguration inferenceservice.serving.kserve.io
oc delete isvc --all -n ${TEST_NS} --force --grace-period=0

echo "It would take around around 3~4 mins"
oc delete all --all --force --grace-period=0  -n ${TEST_NS}
oc delete all --all --force --grace-period=0  -n ${MINIO_NS}
oc delete ns ${TEST_NS} ${MINIO_NS}
oc delete secret wildcard-certs -n istio-system

oc delete DataScienceCluster --all -n "${KSERVE_OPERATOR_NS}"
sleep 15
oc delete sub "${KSERVE_OPERATOR_NS}-operator" -n ${TARGET_OPERATOR_NS}
  
oc delete ns ${KSERVE_OPERATOR_NS} --force --grace-period=0
oc delete csv -n ${TARGET_OPERATOR_NS} $(oc get csv -n ${TARGET_OPERATOR_NS} |grep opendatahub |awk '{print $1}')
