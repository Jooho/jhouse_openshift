export INGRESS_HOST=localhost
export INGRESS_PORT=8080

export SERVICE_HOSTNAME=$(kubectl get inferenceservice sklearn-v2-iris -o jsonpath='{.status.url}' | cut -d "/" -f 3)

curl -v \
  -H "Host: ${SERVICE_HOSTNAME}" \
  -H "Content-Type: application/json" \
  -d @/tmp/iris-input-v2.json \
  "http://${INGRESS_HOST}:${INGRESS_PORT}/v2/models/sklearn-v2-iris/infer"
