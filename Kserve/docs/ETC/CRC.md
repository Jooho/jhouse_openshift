# Code Ready Container(CRC)

## Deploy CRC for Model Serving test
~~~
crc setup 
crc config set memory 35000 
crc config set cpus 8 
crc config set disk-size 70 
crc config set kubeadmin-password kubeadmin 
crc config set enable-cluster-monitoring true
crc start
~~~

## Add cluster-admin role to developer 
This is just for avoiding to use kube:admin user
~~~
oc login -u kubeadmin https://api.crc.testing:6443
oc adm policy add-cluster-role-to-user cluster-admin developer
oc login -u developer https://api.crc.testing:6443
~~~