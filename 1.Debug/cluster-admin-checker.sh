#!/bin/bash
groupNames=$(oc get group |grep $(oc whoami)|awk '{print $1}')
for groupName in $groupNames
do
    clusterAdmin=$(oc get clusterrolebindings -o json | jq '.items[] | select(.metadata.name| startswith("cluster-admin")) | .subjects[].name'|egrep "$userName|$groupName" |wc -l)
    if (( ${clusterAdmin} >= 1 ))
    then
        echo "[PASS] You logged to the cluster as a cluster-admin"
        break
    else
        echo "[FAIL] You logged to the cluster but you are not cluster-admin."
        echo "       Please log in to your cluster as a cluster-admin."
        exit 1
    fi
done
