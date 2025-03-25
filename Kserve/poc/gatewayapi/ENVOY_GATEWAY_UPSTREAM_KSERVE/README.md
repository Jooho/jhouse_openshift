# Integrating Envoy Gateway with KServe using Gateway API

This guide demonstrates how to integrate **Envoy Gateway** with **KServe** using the **Gateway API**. It covers setting up a Kubernetes cluster, deploying Envoy Gateway, and configuring KServe to use the Gateway API for model inference.

## Steps

## 0. Set environment variables for GATEWAY version

```sh
export GATEWAY_API_VERSION=1.2.1
export ENVOY_GATEWAY_VERSION=1.3.1
```

### 1. Create a Kubernetes Cluster and Install Gateway API & Envoy Gateway
```sh
export ROOT_DIR=/tmp
export KSERVE_DIR=${ROOT_DIR}/kserve
export KSERVE_ENABLE_SELF_SIGNED_CA=true

kind create cluster
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/v${GATEWAY_API_VERSION}/standard-install.yaml"
kubectl apply --server-side -f "https://github.com/envoyproxy/gateway/releases/download/v${ENVOY_GATEWAY_VERSION}/install.yaml"
```

### 2. Define a `GatewayClass` for Envoy Gateway
```sh
cat <<EOF |oc create -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller  
EOF
```

### 3. Clone KServe and Modify Configuration
```sh
cd ${ROOT_DIR}
git clone https://github.com/kserve/kserve
cd kserve

# Modify configuration to enable Gateway API and use RawDeployment
sed 's/Serverless"$/RawDeployment"/g' -i ./config/configmap/inferenceservice.yaml
sed 's|"enableGatewayApi": false|"enableGatewayApi": true|g'  -i ./config/configmap/inferenceservice.yaml

# Deploy KServe
make deploy
kubectl config set-context --current --namespace kserve
```

### 4. Configure `Gateway` for KServe
```sh
cat <<EOF|oc create -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: kserve-ingress-gateway
  namespace: kserve
spec:
  gatewayClassName: envoy
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
  infrastructure:
    labels:
      serving.kserve.io/gateway: kserve-ingress-gateway
EOF
```

### 5. Deploy an `InferenceService`
```sh
kubectl create ns kserve-demo
kubectl config set-context --current --namespace kserve-demo

kubectl apply -f - <<EOF
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  name: "sklearn-v2-iris"
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      protocolVersion: v2
      runtime: kserve-sklearnserver
      storageUri: "gs://kfserving-examples/models/sklearn/1.0/model"
EOF
```

### 6. Expose Envoy Gateway and Perform Inference Request
```sh
export INGRESS_GATEWAY_SERVICE=$(kubectl get svc -l serving.kserve.io/gateway=kserve-ingress-gateway -A --output jsonpath='{.items[0].metadata.name}')
export INGRESS_GATEWAY_NAMESPACE=$(kubectl get svc -l serving.kserve.io/gateway=kserve-ingress-gateway -A --output jsonpath='{.items[0].metadata.namespace}')
kubectl port-forward --namespace ${INGRESS_GATEWAY_NAMESPACE} svc/${INGRESS_GATEWAY_SERVICE} 8080:80
```

### 7. Prepare Inference Request
```sh
cat <<EOF> /tmp/iris-input-v2.json
{
  "inputs": [
    {
      "name": "input-0",
      "shape": [2, 4],
      "datatype": "FP32",
      "data": [
        [6.8, 2.8, 4.8, 1.4],
        [6.0, 3.4, 4.5, 1.6]
      ]
    }
  ]
}
EOF
```

### 8. Send an Inference Request
```sh
 oc wait --for=condition=Ready pod/$(oc get pod --no-headers|cut -d" " -f1)
export INGRESS_HOST=localhost
export INGRESS_PORT=8080

export SERVICE_HOSTNAME=$(kubectl get inferenceservice sklearn-v2-iris -o jsonpath='{.status.url}' | cut -d "/" -f 3)

curl -v \
  -H "Host: ${SERVICE_HOSTNAME}" \
  -H "Content-Type: application/json" \
  -d @/tmp/iris-input-v2.json \
  "http://${INGRESS_HOST}:${INGRESS_PORT}/v2/models/sklearn-v2-iris/infer"
```

## Summary
This setup enables KServe to use **Envoy Gateway** via the **Gateway API** for inference service management. The workflow involves:
- Setting up a Kubernetes cluster
- Deploying Envoy Gateway
- Configuring KServe for Gateway API support
- Deploying an `InferenceService`
- Sending an inference request through Envoy Gateway

This PoC validates the feasibility of using Envoy Gateway with KServe for model serving.
