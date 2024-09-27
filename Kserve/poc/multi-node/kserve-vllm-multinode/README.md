## KServe ISVC on openshift

### Install KServe
~~~
export ROOT_DIR=/tmp/kserve_local
export USER_NAME=jooholee
export KSERVE_ENABLE_SELF_SIGNED_CA=true
export STORAGE_CLASS=gp3-csi
export HF_TOKEN=XXX

mkdir -p $ROOT_DIR

cd ${ROOT_DIR}
export KSERVE_DIR=${ROOT_DIR}/kserve
git clone --branch multi_node_impl https://github.com/Jooho/kserve
cd kserve

sed 's/Serverless"$/RawDeployment"/g' -i ./config/configmap/inferenceservice.yaml
sed "s/kserve\/kserve-controller:latest$/quay.io\/jooholee\/kserve-controller:multinode/g" -i ./config/default/manager_image_patch.yaml

#fixed with another pr
FILENAME=./hack/self-signed-ca.sh
TOTAL_LINES=$(wc -l < "$FILENAME")
START_LINE=$((TOTAL_LINES - 4))
sed -i "${START_LINE},${TOTAL_LINES}s/^/# /" $FILENAME

make deploy 

~~~

~~~
cd ${ROOT_DIR}
git clone https://github.com/Jooho/jhouse_openshift.git
cd jhouse_openshift/Kserve/poc/multi-node/kserve-vllm-multinode

# Deploy NFS Provisioner
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
  scForNFS: nfs
  scForNFSPvc: $STORAGE_CLASS
  storageSize: 100Gi
EOF

kubectl create ns kserve-demo
kubectl config set-context --current --namespace kserve-demo

kubectl apply -f 1.create-pvc.yaml
cat 2.download-model-to-pvc.yaml|envsubst |kubectl apply -f -

# Huggingface ServingRuntime
kubectl apply -f 3.huggingface-servingruntime-with-multinode.yaml
kubectl apply -f 4.huggingface-isvc-pvc.yaml

# Get pod name
podName=$(kubectl get pod -l app=isvc.huggingface-llama3-predictor --no-headers|cut -d' ' -f1)
workerPodName=$(kubectl get pod -l app=isvc.huggingface-llama3-predictor-worker --no-headers|cut -d' ' -f1)

# Check GPU memory size
kubectl exec $podName -- nvidia-smi
kubectl exec $workerPodName -- nvidia-smi

kubectl port-forward pod/$podName 9999:8080

# Send inference request.
curl http://localhost:9999/openai/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "huggingface-llama3",
        "prompt": "At what temperature does Nitrogen boil?",
        "max_tokens": 100,
        "temperature": 0
    }'

# clean up huggingface server isvc
oc delete isvc --all

# Vllm ServingRuntime (Optional)
kubectl apply -f .vllm-servingruntime-multinode.yaml
kubectl apply -f 6.vllm-isvc-pvc.yaml

podName=$(kubectl get pod -l app=isvc.huggingface-llama3-predictor --no-headers|cut -d' ' -f1)
workerPodName=$(kubectl get pod -l app=isvc.huggingface-llama3-predictor-worker --no-headers|cut -d' ' -f1)

kubectl exec $podName -- nvidia-smi
kubectl exec $workerPodName -- nvidia-smi

kubectl port-forward pod/$podName 9999:3000


curl http://localhost:9999/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "huggingface-llama3",
        "prompt": "At what temperature does Nitrogen boil?",
        "max_tokens": 100,
        "temperature": 0
    }'
~~~

## clean up kserve
~~~
kubectl delete -f  https://github.com/kserve/kserve/releases/download/v0.13.1/kserve.yaml
~~~
