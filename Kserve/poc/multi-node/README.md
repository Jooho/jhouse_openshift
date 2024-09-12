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
export HF_TOKEN=XXX

cd kserve-required-manifests-vllm-deployment

kubectl apply -f 1.llama3-8b-ns.yaml
kubectl apply -f 2.setup-pvc-model-1.yaml
kubectl apply -f 3.setup-pvc-model-2.yaml
kubectl apply -f 4.llama3-8b-service.yaml
kubectl apply -f 5.llama3-8b-deployment-head.yaml
kubectl apply -f 6.llama3-8b-deployment-worker.yaml

kubectl port-forward pod -l node-type=head  3000:3000

kubectl exec -it pod -l node-type=head

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
export HF_TOKEN=XXX

cd kserve-required-manifests-vllm-sts

kubectl apply -f 1.llama3-8b-ns.yaml
kubectl apply -f 2.setup-pvc-model-1.yaml
kubectl apply -f 3.setup-pvc-model-2.yaml
kubectl apply -f 4.llama3-8b-service.yaml
kubectl apply -f 5.llama3-8b-statefulset-head.yaml
kubectl apply -f 6.llama3-8b-statefulset-worker.yaml

kubectl port-forward pod -l node-type=head  3000:3000

kubectl exec -it pod -l node-type=head

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

kubectl delete pod -l node-type=worker

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
