Create User (HTPASSWD)
```
 oc create secret generic joe -n kube-system --from-literal=joe="$(htpasswd -bnB joe redhat | cut -d':' -f2)"
```

Delete kubeadmin
```
oc delete secret kubeadmin -n kube-system

```

cincinnati-web-graph
```
https://gitlab.cee.redhat.com/rbost/cincinnati-web-graph
https://cincinnati-web-graph.op.redhat.com/
```

check ocp version
```
#!/bin/bash
 
# Requires JQ installed.
# curl -sH 'Accept: application/json'  https://api.openshift.com/api/upgrades_info/v1/graph?channel=stable-4.1&arch=amd64 | jq -S '.nodes | sort_by(.version)'
 
 
PS3='Please enter your choice: '
 
# The names of the channels currently need to be hardcoded as there is no way to get a list of what current channels are avaiable.
# https://github.com/openshift/cincinnati/issues/171#issuecomment-555626636
# Channels not listed prerelease-4.1 candidate-4.2
 
options=( "stable-4.1" "fast-4.2" "stable-4.2" "candidate-4.3" "fast-4.3" "stable-4.3")
 
 
 
# Now that there are channels fro archetures, might what to add an option for arch.
 
_Command () {
  echo "Showing upgrade channel: ${channel}"
  curl -sH 'Accept: application/json'  "https://api.openshift.com/api/upgrades_info/v1/graph?channel=${channel}&arch=amd64" | jq -S '.nodes | sort_by(.version | sub ("-rc";"") | split(".") | map(tonumber)) | .[]'
}
 
if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed.' >&2
  exit 1
fi
 
 
select opt in "${options[@]}"
do
  channel="${opt}"
  _Command
  break
done
```
