# ISTIO

## Installation Istio (ServiceMesh)


<!-- export cluster_url=https://console-openshift-console.apps.jooho.dev.datahub.redhat.com -->
~~~
export cluster_url=https://console-openshift-console.apps-crc.testing
~~~

**Deploy Jaeger**
~~~
google-chrome "$cluster_url/operatorhub/subscribe?pkg=jaeger-product&catalog=redhat-operators&catalogNamespace=openshift-marketplace&targetNamespace=undefined"
~~~
**Deploy Kiali**
~~~
google-chrome "$cluster_url/operatorhub/all-namespaces?keyword=kiali&details-item=kiali-ossm-redhat-operators-openshift-marketplace"
~~~

**Deploy OpenShift Service Mesh**
~~~
google-chrome "$cluster_url/operatorhub/subscribe?pkg=servicemeshoperator&catalog=redhat-operators&catalogNamespace=openshift-marketplace&targetNamespace=undefined"
~~~

**Create SMCP(ServiceMeshControlPlane)**
~~~
oc new-project istio-system

cat <<EOF|oc create -f -
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  tracing:
    type: Jaeger
    sampling: 10000
  policy:
    type: Istiod
  addons:
    grafana:
      enabled: true
    jaeger:
      install:
        storage:
          type: Memory
    kiali:
      enabled: true
    prometheus:
      enabled: true
  telemetry:
    type: Istiod
  version: v2.3
EOF
~~~

**Verify SMCP**
~~~
oc get smcp -n istio-system
~~~ 
## Test Application
bookinfo is a sample application for verifing the istio deployment
 
**Create bookinfo project**
~~~
oc new-project bookinfo
~~~

**Create SMMR(Istio Service Mesh Member)**

Add ISTIO access `bookinfo` namespace
~~~
cat <<EOF|oc create -f -
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system
spec:
  members:
  - bookinfo
EOF
~~~

**Check SMMR**
~~~
oc get smmr -n istio-system default
~~~
-----------------------------------------------
**Deploy test bookinfo application**
~~~
oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.3/samples/bookinfo/platform/kube/bookinfo.yaml

# Create ISTIO object
oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.3/samples/bookinfo/networking/bookinfo-gateway.yaml
oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.3/samples/bookinfo/networking/destination-rule-all.yaml
~~~

**Verify bookinfo application**
~~~
export GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
curl  -o /dev/null -s -w "%{http_code}\n"  $(echo "http://$GATEWAY_URL/productpage")
~~~