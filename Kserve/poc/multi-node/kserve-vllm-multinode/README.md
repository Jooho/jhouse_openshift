# PoC


## Setup NFS Provisioner

~~~
git clone git@github.com:Jooho/nfs-provisioner-operator.git
cd nfs-provisioner-operator/
kustomize build config/default/ |oc create -f -

cat <<EOF |oc create -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: nfsprovisioner-operator
---  
apiVersion: cache.jhouse.com/v1alpha1
kind: NFSProvisioner
metadata:
  name: nfsprovisioner-sample
  namespace: nfsprovisioner-operator
spec:
  scForNFSPvc: standard
  nodeSelector:
    app: nfs-provisioner
EOF
~~~


