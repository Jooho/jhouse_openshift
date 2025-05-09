source ../hacks/env.sh

# cluster
kind create cluster

../hacks/install_gateway.sh
./install_upstream_kserve.sh
../hacks/deploy_sample_isvc.sh

export INGRESS_GATEWAY_SERVICE=$(kubectl get svc -l serving.kserve.io/gateway=kserve-ingress-gateway -A --output jsonpath='{.items[0].metadata.name}')
export INGRESS_GATEWAY_NAMESPACE=$(kubectl get svc -l serving.kserve.io/gateway=kserve-ingress-gateway -A --output jsonpath='{.items[0].metadata.namespace}')

kubectl port-forward --namespace ${INGRESS_GATEWAY_NAMESPACE} svc/${INGRESS_GATEWAY_SERVICE} 8080:80 &
