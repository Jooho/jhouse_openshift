cd ${ROOT_DIR}
git clone https://github.com/kserve/kserve
cd kserve

# Modify configuration to enable Gateway API and use RawDeployment
sed 's/Serverless"$/RawDeployment"/g' -i ./config/configmap/inferenceservice.yaml
sed 's|"enableGatewayApi": false|"enableGatewayApi": true|g'  -i ./config/configmap/inferenceservice.yaml

# Deploy KServe
make deploy
kubectl config set-context --current --namespace kserve

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
