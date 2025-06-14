# Deploy LLM-D with deployer

**Quick Demo**
~~~
git clone git@github.com:llm-d/llm-d-deployer.git
cd llm-d-deployer/quickstart

export HF_TOKEN=${HF_TOKEN} 
./llmd-installer.sh --namespace llmd-test --values-file examples/all-features/all-features.yaml
./test-requests.sh -n llmd-test
~~~


**Troubleshooting**

*Before running the example, clean up any leftover objects.*
~~~

oc delete crd $(oc get crd|grep istio)
kubectl delete crd wasmplugins.extensions.istio.io
kubectl delete crd istiod-gateway-controller-istio-system 
kubectl delete clusterrole istiod-clusterrole-istio-system

oc delete validatingwebhookconfigurations.admissionregistration.k8s.io $(oc get validatingwebhookconfigurations.admissionregistration.k8s.io|grep istio)
oc delete mutatingwebhookconfigurations.admissionregistration.k8s.io $(oc get mutatingwebhookconfigurations.admissionregistration.k8s.io |grep istio)


oc delete clusterrolebinding istio-reader-clusterrole-istio-system
oc delete clusterrolebinding istiod-clusterrole-istio-system

oc delete clusterrole $(oc get clusterrole|grep llm|awk '{print $1}')
~~~

**cleanup**
~~~
./llmd-installer.sh --uninstall
~~~