# test
SERVICE_HOSTNAME=$(kubectl get inferenceservice sklearn-irisv2 -o jsonpath='{.status.url}' | cut -d "/" -f 3)

curl -v \
  -H "Host: ${SERVICE_HOSTNAME}" \
  -H "Content-Type: application/json" \
  -d @./iris-input.json \
  http://${SERVICE_HOSTNAME}:${INGRESS_PORT}/v2/models/sklearn-irisv2/infer
~~~
