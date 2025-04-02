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

sleep 5
oc wait --for=condition=Ready pod/$(oc get pod --no-headers|cut -d" " -f1) --timeout=300s

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

