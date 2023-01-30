# Open Data Hub

## Install ODH operator
~~~
cat << EOF| oc create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  creationTimestamp: "2023-01-20T21:31:31Z"
  generation: 1
  labels:
    operators.coreos.com/opendatahub-operator.openshift-operators: ""
  name: opendatahub-operator
  namespace: openshift-operators
  resourceVersion: "6242197"
  uid: 291d3521-32eb-496a-ba9e-85e056e83c5c
spec:
  channel: stable
  installPlanApproval: Automatic
  name: opendatahub-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF
~~~