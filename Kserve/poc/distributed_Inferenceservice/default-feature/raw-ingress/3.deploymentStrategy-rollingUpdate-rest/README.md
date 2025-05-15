🧪 PoC 3: Basic Distributed Inference Workflow Validation for deploymentStrategy rollingUpdate rest case

**Situation**
When existing DistributedInferenceService is updated, it should create a new required objects(ISVC,INGRESS,SVC) for the V2. When v2 isvc is READY, ingress will be updated to point to a V2 SVC. Then the V1 related objects will be removed.

**Full Steps**
- Create a [DistributedInferenceService object](./default-disvc.yaml) with minimal required fields.
    ```
    kubectl create ns kserve-demo
    kubectl config set-context --current --namespace kserve-demo

    kubectl create -f ./disvc-1.yaml
    ```
- It expects to create the following objects by distributedInferenceService reconciler 
  - [ISVC](./disvc-isvc1.yaml)
  - [SVC](./disvc-v1-svc.yaml)
  - [INGRESS](./disvc-ingress-1.yaml)
  ~~~
  oc create -f ./disvc-svc.yaml 
  oc create -f ./disvc-v1-svc.yaml 
  oc create -f ./disvc-ingress-1.yaml 
  ~~~
- When ISVC is ready, disvc reconciler will update status for the url
~~~
disvc.Status.url=http://sklearn-v2-iris-rest-kserve-demo.example.com
disvc.Status.Address.url=http://sklearn-v2-iris-rest-v1.kserve-demo.svc.cluster.local
~~~

- Send a request to the v1 runtime 
  - using internal hostname
    - simple test
      ~~~
      oc run test-pod --image=registry.access.redhat.com/rhel7/rhel-tools  -- sleep infinity 2> /dev/null      
      oc rsh test-pod
      #SERVICE_HOSTNAME=$(kubectl get distributedinferenceservice sklearn-v2-iris-rest -o jsonpath='{.status.address.url}' | cut -d "/" -f 3)
      SERVICE_HOSTNAME=sklearn-v2-iris-rest.kserve-demo.svc.cluster.local
      curl "$SERVICE_HOSTNAME"
      ~~~

    - with data
      ~~~    
      cat <<EOF > /tmp/iris-input-v2.json
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

      curl  -H "Content-Type: application/json" -d @/tmp/iris-input-v2.json $SERVICE_HOSTNAME/v2/models/sklearn-v2-iris-rest/infer 
      ~~~

    - using external hostname
      ~~~
      cat <<EOF > /tmp/iris-input-v2.json
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
      #SERVICE_HOSTNAME=$(kubectl get distributedinferenceservice sklearn-v2-iris-rest -o jsonpath='{.status.url}' | cut -d "/" -f 3)
      SERVICE_HOSTNAME=sklearn-v2-iris-rest-kserve-demo.example.com
      
      echo "127.0.0.1 ${SERVICE_HOSTNAME}" | sudo tee -a /etc/hosts
      curl  -H "Content-Type: application/json" -d @/tmp/iris-input-v2.json $SERVICE_HOSTNAME/v2/models/sklearn-v2-iris-rest/infer 
      ~~~



## Update disvc v2
```
  oc apply -f ./disvc-v2.yaml
  oc create -f ./disvc-v2-svc.yaml 
  oc apply -f ./disvc-ingress-2.yaml 
```

- When ISVC-2 is ready, disvc reconciler will update status for the url
~~~
disvc.Status.url=http://sklearn-v2-iris-rest-kserve-demo.example.com
disvc.Status.Address.url=http://sklearn-v2-iris-rest-v2.kserve-demo.svc.cluster.local
~~~

- Send a request to the v2 runtime 
  - using internal hostname
    - simple test
      ~~~
      oc rsh test-pod
      #SERVICE_HOSTNAME=$(kubectl get distributedinferenceservice sklearn-v2-iris-rest -o jsonpath='{.status.address.url}' | cut -d "/" -f 3)
      SERVICE_HOSTNAME=sklearn-v2-iris-rest.kserve-demo.svc.cluster.local
      curl "$SERVICE_HOSTNAME"
      ~~~

    - with data
      ~~~    
      cat <<EOF > /tmp/iris-input-v2.json
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

      curl  -H "Content-Type: application/json" -d @/tmp/iris-input-v2.json $SERVICE_HOSTNAME/v2/models/sklearn-v2-iris-rest/infer 
      ~~~

    - using external hostname
      ~~~
      cat <<EOF > /tmp/iris-input-v2.json
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
      #SERVICE_HOSTNAME=$(kubectl get distributedinferenceservice sklearn-v2-iris-rest -o jsonpath='{.status.url}' | cut -d "/" -f 3)
      SERVICE_HOSTNAME=sklearn-v2-iris-rest-kserve-demo.example.com
      
      echo "127.0.0.1 ${SERVICE_HOSTNAME}" | sudo tee -a /etc/hosts
      curl  -H "Content-Type: application/json" -d @/tmp/iris-input-v2.json $SERVICE_HOSTNAME/v2/models/sklearn-v2-iris-rest/infer 
      ~~~   
     


**Confirm**

- A corresponding InferenceService (ISVC) is created.
  - [InferenceService 1](./disvc-isvc1.yaml)
  - [InferenceService 2](./disvc-isvc2.yaml)
- Any associated Kubernetes Service objects are generated correctly.
  - [V1 Service](./disvc-v1-svc.yaml)
  - [V2 Service](./disvc-v2-svc.yaml)
  - [INGRESS v1](./disvc-ingress-1.yaml)
  - [INGRESS v2](./disvc-ingress-2.yaml)
- Send an inference request to the new top-level endpoint (associated with DistributedInferenceService).

**Validate**

The request is routed through the expected service chain.

A valid result is returned.

**Outcome**
This PoC confirms that the custom resource correctly orchestrates the creation of underlying components and handles inference requests end-to-end

**When replicas is increased to 2 or more??**
While this approach creates multiple ISVCs, the rest of the network configuration remains unchanged. Additionally, the DISVC will enable sessionAffinity to maintain a consistent runtime assignment per client.