# Ansible Wisdom Model on Watson Runtime

## with RHODS modelmesh

Env
 - CRC
 - RHODS (https://github.com/rh-aiservices-pilot/ans-wis-model/blob/main/deploy.rhods.livebuild.and.override.sh)



~~~
mkdir /tmp/olm
git clone git@gitlab.cee.redhat.com:data-hub/olminstall.git

cd /tmp/olm/olminstall/
./setup.sh \
    -t operator \
    -i quay.io/cfchase/rhods-operator-live-catalog:1.22.0-w5


oc -n redhat-ods-applications \
    patch configmap \
    servingruntimes-config \
    -p "$(cat rhods.deploy/servingruntimes-configmap.yaml)"

oc delete pod -l control-plane=modelmesh-controller

oc new-project mm-1
oc label namespace mm-1 modelmesh-enabled=true --overwrite=true
oc label namespace mm-1 opendatahub.io/dashboard=true --overwrite=true

cat <<EOF |oc apply -f - 
apiVersion: v1
kind: Secret
metadata:
  name: storage-config-aws
stringData:
  aws-connection-answis-dev: |
    {
      "type": "s3",
      "access_key_id": "XXX",
      "secret_access_key": "XXXX",
      "endpoint_url": "http://s3.amazonaws.com",
      "default_bucket": "answis-dev",
      "region": "us-east-1"
    }
EOF


oc create secret docker-registry custom-registry-secret --docker-server='us.icr.io' --docker-username='XXXX'  --docker-password='XXXX' --docker-email='asood@us.@ibm.com'

kubectl patch serviceaccount modelmesh-serving-sa -p '{"imagePullSecrets": [{"name": "custom-registry-secret"}]}'    
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "custom-registry-secret"}]}'    



  
k exec -it deploy/modelmesh-serving-model-server-mm-1 -c puller -- du -h --max-depth=1 /models

~~~~


oc create route  edge wisdom --insecure-policy=Redirect  --service=modelmesh-serving --port=8008


export URL=$(oc get route wisdom -ojsonpath='{.spec.host}')
 curl  -H "mm-vmodel-id: gpu-version-inference-service" --silent --location --fail --show-error --insecure https://${URL}/v2/models/gpu-version-inference-service/infer -d @./input.json

 curl  -H "mm-vmodel-id: gpu-version-inference-service" --silent --location --fail --show-error --insecure  https://wisdom-wisdom-dev.apps.pilot.j61u.p1.openshiftapps.com/v2/models/gpu-version-inference-service/infer -d @./input.json

 -H "mm-vmodel-id: gpu-version-inference-service" 

 



python -m grpc_tools.protoc -I../protos --python_out=. --pyi_out=. --grpc_python_out=. ../protos/common-service.proto


import sys
import os
sys.path.append(os.getcwd()+"/wisdom_grpc")

import grpc
from wisdom_grpc import common_service_pb2 
from wisdom_grpc import common_service_pb2_grpc 

query='install nginx on rhel and enable nginx service when os start'

def run():
    with grpc.insecure_channel(target='modelmesh-serving.wisdom-dev.svc.cluster.local:8033') as channel:
        stub = common_service_pb2_grpc.CoreAnsibleWisdomExtServiceStub(channel)
        metadata = [('mm-vmodel-id','gpu-version-inference-service')]

        # AnsibleWisdomPredict
        response = stub.AnsibleWisdomPredict(request=common_service_pb2.AnsibleWisdomRequest(prompt=query),metadata=metadata)
               
        # _, call = stub.AnsibleWisdomPredict.with_call(request=common_service_pb2.AnsibleWisdomRequest(prompt=query),metadata=metadata)
        # if call.done():
        #     response = call.result()
        
        print(response.label)
run()



https://console-openshift-console.apps.pilot.j61u.p1.openshiftapps.com/k8s/ns/rhods-notebooks/pods

https://rhods-dashboard-redhat-ods-applications.apps.pilot.j61u.p1.openshiftapps.com/notebookController