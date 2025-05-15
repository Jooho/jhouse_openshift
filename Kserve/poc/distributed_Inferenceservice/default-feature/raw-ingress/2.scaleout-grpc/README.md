🧪 PoC 2: Basic Distributed Inference Workflow Validation for scaleout-GRPC case

**Situation**
When DistributedInferenceService is created with a sample sklearn model, it should create required objects(ISVC,INGRESS,SVC)

**Full Steps**
- Create a [DistributedInferenceService object](./default-disvc.yaml) with minimal required fields.
    ```
    kubectl create ns kserve-demo
    kubectl config set-context --current --namespace kserve-demo

    kubectl create -f ./disvc.yaml
    ```
- It expects to create the following objects by distributedInferenceService reconciler
  - [ISVC](./disvc-isvc1.yaml)
  - [SVC](./disvc-svc.yaml)
  - [SVC](./disvc-v1-svc.yaml)
  - [INGRESS](./disvc-ingress.yaml)
  ~~~
  oc create -f ./disvc-v1-svc.yaml 
  oc create -f ./disvc-ingress.yaml 
  ~~~

- When ISVC is ready, disvc reconciler will update status for the url
~~~
disvc.Status.url=http://sklearn-v2-iris-rest-kserve-demo.example.com
disvc.Status.Address.url=http://sklearn-v2-iris-grpc-v1.kserve-demo.svc.cluster.local
~~~

- Send a request to the runtime 
  - using internal hostname
    - simple test
      ~~~
      oc run test-pod --image=registry.access.redhat.com/rhel7/rhel-tools  -- sleep infinity 2> /dev/null      
      oc rsh test-pod

      # Download grpcurl
      GRPC_CURL_VERSION=1.9.3
      curl -OL "https://github.com/fullstorydev/grpcurl/releases/download/v${GRPC_CURL_VERSION}/grpcurl_${GRPC_CURL_VERSION}_linux_x86_64.tar.gz"
      tar xf "grpcurl_${GRPC_CURL_VERSION}_linux_x86_64.tar.gz"      
      chmod +x "./grpcurl"

      #SERVICE_HOSTNAME=$(kubectl get distributedinferenceservice sklearn-v2-iris-rest -o jsonpath='{.status.address.url}' | cut -d "/" -f 3)
      SERVICE_HOSTNAME=sklearn-v2-iris-grpc.kserve-demo.svc.cluster.local

      curl -O https://raw.githubusercontent.com/kserve/kserve/refs/heads/master/docs/predict-api/v2/grpc_predict_v2.proto
      PROTO_FILE=grpc_predict_v2.proto

      ./grpcurl \
        -plaintext \
        -proto ${PROTO_FILE} \
        -authority ${SERVICE_HOSTNAME} \
        ${SERVICE_HOSTNAME}:80 \
        inference.GRPCInferenceService.ServerReady
      ~~~

    - with data
      ~~~    
      cat <<EOF > /tmp/iris-input-v2.json
      {
        "model_name": "sklearn-v2-iris-grpc",
        "inputs": [
          {
            "name": "input-0",
            "shape": [2, 4],
            "datatype": "FP32",
            "contents": {
              "fp32_contents": [6.8, 2.8, 4.8, 1.4, 6.0, 3.4, 4.5, 1.6]
            }
          }
        ]
      }
      EOF
      
      INPUT_PATH=/tmp/iris-input-v2.json

      ./grpcurl -plaintext -proto ${PROTO_FILE}  -d @ ${SERVICE_HOSTNAME} inference.GRPCInferenceService.ModelInfer <<< $(cat "${INPUT_PATH}")
      ~~~

    - using external hostname
      ~~~
      cat <<EOF > /tmp/iris-input-v2.json
      {
        "model_name": "sklearn-v2-iris-grpc",
        "inputs": [
          {
            "name": "input-0",
            "shape": [2, 4],
            "datatype": "FP32",
            "contents": {
              "fp32_contents": [6.8, 2.8, 4.8, 1.4, 6.0, 3.4, 4.5, 1.6]
            }
          }
        ]
      }
      EOF

      kubectl create secret tls grpc-tls \
        --cert=tls.crt --key=tls.key
      kubectl patch configmap ingress-nginx-controller -n ingress-nginx --type=merge -p '{"data":{"use-http2":"true"}}'
      kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx

      curl -O https://raw.githubusercontent.com/kserve/kserve/refs/heads/master/docs/predict-api/v2/grpc_predict_v2.proto
      INPUT_PATH=/tmp/iris-input-v2.json
      PROTO_FILE=grpc_predict_v2.proto

      #SERVICE_HOSTNAME=$(kubectl get distributedinferenceservice sklearn-v2-iris-grpc -o jsonpath='{.status.url}' | cut -d "/" -f 3)
      SERVICE_HOSTNAME=sklearn-v2-iris-grpc-kserve-demo.example.com
      
      echo "127.0.0.1 ${SERVICE_HOSTNAME}" | sudo tee -a /etc/hosts
      grpcurl -plaintext -proto ${PROTO_FILE}  -d @ ${SERVICE_HOSTNAME}:443 inference.GRPCInferenceService.ModelInfer <<< $(cat "${INPUT_PATH}")
      ~~~
   
     


**Confirm**

- A corresponding InferenceService (ISVC) is created.
  - [InferenceService](./disvc-isvc1.yaml)
- Any associated Kubernetes Service objects are generated correctly.
  - [V1 Service](./disvc-v1-svc.yaml)
  - [INGRESS](./disvc-ingress.yaml)
- Send an inference request to the new top-level endpoint (associated with DistributedInferenceService).

**Validate**

The request is routed through the expected service chain.

A valid result is returned.

**Outcome**
This PoC confirms that the custom resource correctly orchestrates the creation of underlying components and handles inference requests end-to-end

**When replicas is increased to 2 or more??**
While this approach creates multiple ISVCs, the rest of the network configuration remains unchanged. Additionally, the DISVC will enable sessionAffinity to maintain a consistent runtime assignment per client.