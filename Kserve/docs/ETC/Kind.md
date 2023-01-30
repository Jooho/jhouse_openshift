# Kind

kind is a tool for running local Kubernetes clusters using Docker container “nodes”.

- [Doc](https://kind.sigs.k8s.io/)

**Install**
~~~
KIND_VERSION=0.17.0
wget https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-amd64
chmod 777 kind-linux-amd64 
sudo mv kind-linux-amd64 /usr/local/bin/kind
~~~

**Deploy kubernetes**
~~~
kind create cluster
~~~

**Delete kubernetes cluster**
~~~
kind delete cluster
~~~