# Multi Node/Multi GPU POC with vllm

Next action item:
- create a proposal doc explaining the mechanism

Open question:
- deployment vs statefulset

## Test Environment
- AWS
- Openshift Cluster 4.14 (ROSA)
- Node Feature Discovery Operator
- NVIDIA GPU Operator
- Model `meta-llama/Meta-Llama-3-8B-Instruct`
- Runtime `vllm/vllm-openapi:v0.6.0`

## Deployment
**POC Steps**
~~~
export HF_TEST_TOKEN=XXX

cd kserve-required-manifests-vllm-deployment

kubectl apply -f 1.llama3-8b-ns.yaml
cat 2.setup-pvc-model-1.yaml|envsubst |kubectl apply -f -
cat 3.setup-pvc-model-2.yaml|envsubst |kubectl apply -f -
kubectl apply -f 4.llama3-8b-service.yaml
kubectl apply -f 5.llama3-8b-deployment-head.yaml
kubectl apply -f 6.llama3-8b-deployment-worker.yaml

kubectl port-forward pod -l app=isvc.huggingface-llama3-predictor  3000:3000

kubectl exec -it pod -l app=isvc.huggingface-llama3-predictor

curl http://localhost:3000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "/llama_3_storage/hf/8b_instruction_tuned",
        "prompt": "At what temperature does Nitrogen boil?",
        "max_tokens": 100,
        "temperature": 0
    }'
~~~



## StatefulSet
~~~
export HF_TEST_TOKEN=XXX

cd kserve-required-manifests-vllm-sts

kubectl apply -f 1.llama3-8b-ns.yaml
cat 2.setup-pvc-model-1.yaml|envsubst |kubectl apply -f -
cat 3.setup-pvc-model-2.yaml|envsubst |kubectl apply -f -
kubectl apply -f 4.llama3-8b-service.yaml
kubectl apply -f 5.llama3-8b-statefulset-head.yaml
kubectl apply -f 6.llama3-8b-statefulset-worker.yaml

podName=$(kubectl get pod -l app=isvc.huggingface-llama3-predictor --no-headers|cut -d' ' -f1)
kubectl port-forward pod/$podName 3000:3000

kubectl exec -it pod $podName

nvidia-smi

curl http://localhost:3000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "/llama_3_storage/hf/8b_instruction_tuned",
        "prompt": "At what temperature does Nitrogen boil?",
        "max_tokens": 100,
        "temperature": 0
    }'
~~~


### Auto recovery
~~~
kubectl delete pod -l app=isvc.huggingface-llama3-predictor-worker

# from head container
curl http://localhost:3000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "/llama_3_storage/hf/8b_instruction_tuned",
        "prompt": "At what temperature does Nitrogen boil?",
        "max_tokens": 100,
        "temperature": 0
    }'

# outside container
kubectl get pod -w    

# head pod will restart and then worker will restart too

# after head is Ready try this again from head container
curl http://localhost:3000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "/llama_3_storage/hf/8b_instruction_tuned",
        "prompt": "At what temperature does Nitrogen boil?",
        "max_tokens": 100,
        "temperature": 0
    }'
~~~


## KServe ISVC on openshift
~~~
export HF_TEST_TOKEN=XXX

cd kserve-vllm-multinode

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
  scForNFSPvc: gp3-csi
  storageSize: 100Gi
EOF

kubectl apply -f 1.create-pvc.yaml
cat 2.download-model-to-pvc.yaml|envsubst |kubectl apply -f -

# Huggingface ServingRuntime
kubectl apply -f 3.huggingface-servingruntime-with-multinode.yaml
kubectl apply -f 4.huggingface-isvc-pvc.yaml


podName=$(kubectl get pod -l app=isvc.huggingface-llama3-predictor --no-headers|cut -d' ' -f1)
workerPodName=$(kubectl get pod -l app=isvc.huggingface-llama3-predictor-worker --no-headers|cut -d' ' -f1)

# Check GPU memory size
kubectl exec $podName -- nvidia-smi
kubectl exec $workerPodName -- nvidia-smi

kubectl port-forward pod/$podName 9999:8080


curl http://localhost:9999/openai/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "huggingface-llama3",
        "prompt": "At what temperature does Nitrogen boil?",
        "max_tokens": 100,
        "temperature": 0
    }'

# clean up
oc delete isvc --all

# Vllm ServingRuntime
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
