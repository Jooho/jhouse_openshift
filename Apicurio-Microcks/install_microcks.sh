source ./env.sh
source ./scripts/utils.sh


# Create a project if it does not exist.
createNS ${PROJECT_NAME}

# Install Microcks operator
envsubst < ${microcks_dir}/og.yaml | oc create -f -
envsubst < ${microcks_dir}/subs.yaml | oc create -f -

#Wait for the operator is running
operator_name=$(oc get pods --field-selector status.phase=Running -l  name=microcks-ansible-operator -o name|cut -d'/' -f2)
waitForPodReady $operator_name

# Create a CR for Microks
envsubst < ${microcks_dir}/cr.yaml |oc create -f -

#Wait for the Microcks is running
waitForPodsReady  "app=${MICROCKS_CR_NAME}" "5"
exit 1