

When you use Quay.io as a KO repository(export KO_DOCKER_REPO=quay.io/jooholee), you must update this file(image_patch_dev.sh)
~~~
IMG=$(ko resolve -f config/manager/manager.yaml --sbom=none | grep 'image:' | head -1 | awk '{print $2}')                               #--sbom=none
...
AGENT_IMG=$(ko resolve -f config/overlays/development/configmap/ko_resolve_agent --sbom=none | grep 'image:' | awk '{print $2}')        #--sbom=none
ROUTER_IMG=$(ko resolve -f config/overlays/development/configmap/ko_resolve_router --sbom=none | grep 'image:' | awk '{print $2}')      #--sbom=none


~~~



# Upstream Development Guide

## RawDeployment
~~~

KServe Development

**Required binary**
https://kind.sigs.k8s.io/
wget https://github.com/kubernetes-sigs/kind/releases/download/v0.17.0/kind-linux-amd64
chmod 777 kind-linux-amd64 
sudo mv kind-linux-amd64 /usr/local/bin/kind

**yq(4.0+)**
wget https://github.com/mikefarah/yq/releases/download/v4.30.8/yq_linux_amd64
chmod 777 yq_linux_amd64 
sudo mv yq_linux_amd64 /usr/local/bin/yq



# Clone repo
git clone https://github.com/Jason4849/kserve
cd kserve
git remote add upstream git@github.com:kserve/kserve.git
git remote set-url --push upstream no_push


# Ko installation
go install github.com/google/ko@latest


# bashrc
export GOPATH="$HOME/go"
export PATH="${PATH}:${GOPATH}/bin"
export KO_DOCKER_REPO=quay.io/jooholee
export KSERVE_ENABLE_SELF_SIGNED_CA=false



# Deploy Kind 
kind create cluster

#Cert Manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

#Deploy kserve 
make deploy-dev

~~~
kubectl config set-context --current --namespace=kserve
oc edit cm inferenceservice-config 
.....
  deploy: |-
    {
      "defaultDeploymentMode": "RawDeployment"
    }
.....
~~~

#Deploy Model Server
make deploy-dev-sklearn
make deploy-dev-xgb

#Deploy StorgeInintializer
make deploy-dev-storageInitializer


# Test
~~~
pip install virtualenv 
virtualenv ~/virtualEnv/kserve
source ~/virtualEnv/kserve/bin/activate
~~~

~~~
deactivate
~~~

#Delete Kserve
make undeploy-dev

Docs
- [developer](https://kserve.github.io/website/master/developer/developer/#deploy-kserve-from-master-branch)
~~~


git clone https://github.com/kserve/kserve.git
cd kserve

kind create cluster
export controller_img=quay.io/jooholee/manager-12782ae64d3f5f3dbe4595b05a2cb78d@sha256:f096b4b550d56a9efe064792d722efb6af82d32aad0b4c8a27797d88e29dc0c4
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

cat <<EOF >./deploy-target-kserve.sh
#!/bin/bash
cd config/default; kustomize edit add resource certmanager/certificate.yaml; cd ../..
mode='{"defaultDeploymentMode":"RawDeployment"}' yq -i '.data.deploy=strenv(mode)' config/configmap/inferenceservice.yaml
yq -i '.spec.template.spec.containers.0.image=env(controller_img)' config/overlays/development/manager_image_patch.yaml
kustomize build config/overlays/development | kubectl apply -f -
kubectl wait --for=condition=ready pod -l control-plane=kserve-controller-manager -n kserve --timeout=300s
kustomize build config/runtimes | kubectl apply -f -
EOF

chmod 777 ./deploy-target-kserve.sh
./deploy-target-kserve.sh


kubectl create ns kserve-test
kubectl config set-context --current --namespace=kserve-test
cat <<EOF| kubectl apply -f -
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  annotations:
    "serving.kserve.io/autoscalerClass": "none"
    "serving.kserve.io/deploymentMode": "RawDeployment"
  name: "sklearn-irisv2"
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      runtime: kserve-mlserver
      storageUri: "gs://seldon-models/sklearn/mms/lr_model"
EOF

Check if HPA is not created



Unit Test
~~~
KUBEBUILDER_ASSETS="/home/jooho/.local/share/kubebuilder-envtest/k8s/1.24.1-linux-amd64" go test $(go list ./pkg/...) 
KUBEBUILDER_ASSETS="/home/jooho/.local/share/kubebuilder-envtest/k8s/1.24.1-linux-amd64" go test $(go list ./pkg/...) ./cmd/... -coverprofile coverage.out -coverpkg ./pkg/... ./cmd...
KUBEBUILDER_ASSETS="/home/jooho/.local/share/kubebuilder-envtest/k8s/1.24.1-linux-amd64" go test github.com/kserve/kserve/pkg/controller/v1beta1/inferenceservice -args -ginkgo.v 
KUBEBUILDER_ASSETS="/home/jooho/.local/share/kubebuilder-envtest/k8s/1.24.1-linux-amd64" go test -v github.com/kserve/kserve/pkg/controller/v1beta1/inferenceservice -args -ginkgo.v -ginkgo.focus "Should have ingress/service/deployment created"
~~~