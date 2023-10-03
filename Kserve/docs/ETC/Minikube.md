# Minikube 

## Installation

~~~
minikube start --kubernetes-version=1.26.1 --memory=20G --cpus=8  --vm-driver=kvm2
minikube docker-env 
~~~


docker run --network host -it kserve/modelmesh-controller-develop /bin/bash
