#!/bin/bash

source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/utils.sh"

namespace=$1 

# Deploying NFS provisioner for RWM PVCs
oc project $namespace|| oc new-project $namespace

# If there is no default storageclass in the cluster, it failed
default_sc=$(oc get sc|grep default || true)
if [[ z${default_sc} == z ]]; then
  die "No default StorageClass exist. FVT require NFS Provisioner for RWM pvc"
fi

default_sc_name=$(oc get sc|grep default|awk '{print $1}')

info "..Deploying NFS Provisioner operator"
oc apply -f $COMMON_MANIFESTS_HOME/nfs-provisioner-subs.yaml

exist_nfs_crd=$(oc get crd -n $namespace --output custom-columns=":metadata.name"|grep nfsprovisioners.cache.jhouse.com || true)
while [ z${exist_nfs_crd} == z ]
do
  sleep 5s
  exist_nfs_crd=$(oc get crd -n $namespace --output custom-columns=":metadata.name"|grep nfsprovisioners.cache.jhouse.com || true)
done

info ".. Deploying NFS Provisioner pod"
sed "s/%default-sc-name%/${default_sc_name}/g"  $COMMON_MANIFESTS_HOME/nfs-provisioner.yaml |oc apply -n $namespace -f - 
wait_for_pods_ready "app=nfs-provisioner" "$namespace"

info ".. Changing default StorageClass to NFS"
oc patch storageclass nfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
oc patch storageclass ${default_sc_name} -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

success "[SUCCESS] NFS Provisioner is Ready to create RWM PVCs"
