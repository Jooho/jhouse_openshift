# POC-1: Share Kernel Cache

Prerequisite
- NFS provisioner
- PVCs
  - vllm
  - triton
  ```
  oc create -f manifests/pvc/cache-pvc-rwm.yaml  # vllm
  oc create -f manifests/pvc/triton-cache-pvc-rwm.yaml
  ```
- Deploy a pod to copy the kernel
  ```
  oc apply -f ./manifests/pvc/cache-pvc-pod.yaml

  # Test
  oc exec running-pod-with-pvc -- touch /tmp/vllm-test/jooho.txt  
  oc exec running-pod-with-pvc -- ls /tmp/vllm-test/jooho.txt  
  ```



## no compile (RHOAI)

* Deploy vllm with nividia gpu

```
oc process vllm-cuda-runtime-template -n redhat-ods-applications|oc create -f -

cat <<EOF |oc create -f -
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: opt-125m
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
spec:
  predictor:
    model:
      modelFormat:
        name: vLLM
      runtime: vllm-cuda-runtime
      storageUri: hf://facebook/opt-125m
      resources:
        requests:
          cpu: "1"
          memory: 2Gi
          nvidia.com/gpu: "1"
        limits:
          cpu: "2"
          memory: 4Gi
          nvidia.com/gpu: "1"
EOF
```

** The vllm image has these environment variables
- VLLM_CACHE_ROOT=/tmp/vllm
- TRITON_CACHE_DIR=/tmp/triton

## no compile (Upstream)

* Deploy vllm with upstream vllm servingruntim

```
oc create -f ./manifests/no-cache/vllm-runtime-pvc.yaml
oc apply -f ./manifests/no-cache/isvc-upstream.yaml  
```
- Serving name: kserve-vllmserver
  - env:  
     - name: VLLM_CACHE_ROOT
       value: /tmp/vllm

**time**
model download: 10~11s

total deployment time:  ~91s

```
opt-125m-predictor-787c8998c9-tnr8w   0/2     PodInitializing   0          5s
opt-125m-predictor-787c8998c9-tnr8w   0/2     Running           0          6s
opt-125m-predictor-787c8998c9-tnr8w   1/2     Running           0          11s
opt-125m-predictor-787c8998c9-tnr8w   1/2     Running           0          91s
```

## AOT compile

* Restart pod 
```
oc delete $pod_name
```


**time**
model download: 10~11s

total deployment time:  ~60s

```
NAME                                  READY   STATUS            RESTARTS   AGE
opt-125m-predictor-86cfcd6dbc-w7sp6   0/2     PodInitializing   0          5s
running-pod-with-pvc                  1/1     Running           0          2m3s
opt-125m-predictor-86cfcd6dbc-w7sp6   0/2     Running           0          5s
opt-125m-predictor-86cfcd6dbc-w7sp6   1/2     Running           0          10s
opt-125m-predictor-86cfcd6dbc-w7sp6   1/2     Running           0          60s
opt-125m-predictor-86cfcd6dbc-w7sp6   2/2     Running           0          60s

```

## vllm & triton

* cleanup 

```
oc delete isvc,pod,pvc --all --force
```

* resetup
```
  oc create -f manifests/pvc/cache-pvc-rwm.yaml  # vllm
  oc create -f manifests/pvc/triton-cache-pvc-rwm.yaml
  oc apply -f manifests/pvc/cache-pvc-pod.yaml
```
* Create Serving Runtime and ISVC with 
```
      - name: TRITON_CACHE_DIR
        value: /tmp/triton
```

```
oc apply -f manifests/vllm-triton/vllm-runtime-pvc-triton.yaml
oc apply -f manifests/vllm-triton/isvc-upstream-pvc-triton.yaml
```

* Restart pod 
```
export pod_name=$(oc get pod -l serving.kserve.io/inferenceservice=opt-125m -oname)
oc delete $pod_name
```


**time**
model download: 10~11s

total deployment time:  ~60s

```
NAME                                  READY   STATUS    RESTARTS   AGE
opt-125m-predictor-5ccb97dfb7-vphnw   0/2     Running   0          6s
running-pod-with-pvc                  1/1     Running   0          3m35s
opt-125m-predictor-5ccb97dfb7-vphnw   1/2     Running   0          10s
opt-125m-predictor-5ccb97dfb7-vphnw   1/2     Running   0          60s
opt-125m-predictor-5ccb97dfb7-vphnw   2/2     Running   0          60s
```

## vLLM Cache PoC Results

| Case                        | Cache Configuration                                               | AOT Cache | Triton `.cubin` | `torch.compile` | Engine Init | Result               |
| --------------------------- | ----------------------------------------------------------------- | --------- | --------------- | --------------: | ----------: | -------------------- |
| **1. VLLM Cache Only**      | `VLLM_CACHE_ROOT` only                                            | Hit       | Hit             |       **1.10s** |   **7.77s** | Success              |
| **2. Triton Cache Missing** | `VLLM_CACHE_ROOT` + `TRITON_CACHE_DIR`, Triton cache not restored | Hit       | Miss            |       **1.04s** |   **9.57s** | Cubin reload warning |
| **3. VLLM + Triton Cache**  | `VLLM_CACHE_ROOT` + `TRITON_CACHE_DIR`, both restored             | Hit       | Hit             |       **0.38s** |   **6.82s** | Success              |

### Performance Comparison

Compared with Case 1, Case 3 showed:

* `torch.compile`: **1.10s → 0.38s (~65% reduction)**
* Engine initialization: **7.77s → 6.82s (~12% reduction)**

> **Note:** These results are based on a small number of runs. More repeated measurements are needed before concluding that a separate `TRITON_CACHE_DIR` is inherently faster.

