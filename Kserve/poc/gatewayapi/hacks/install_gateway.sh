kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/v${GATEWAY_API_VERSION}/standard-install.yaml"
kubectl apply --server-side -f "https://github.com/envoyproxy/gateway/releases/download/v${ENVOY_GATEWAY_VERSION}/install.yaml"

cat <<EOF |oc create -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller  
EOF