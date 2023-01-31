# Model Mesh

## Installation(Upstream)

[Doc](https://github.com/kserve/modelmesh-serving/blob/release-0.8/docs/quickstart.md)
~~~
RELEASE=release-0.9
git clone -b $RELEASE --depth 1 --single-branch https://github.com/kserve/modelmesh-serving.git
cd modelmesh-serving

kubectl create namespace modelmesh-serving
./scripts/install.sh --namespace modelmesh-serving --quickstart
~~~


**Enable Logging**
~~~
 kubectl set env deploy/modelmesh-controller DEV_MODE_LOGGING=true
~~~

**Namespace Scope**
~~~
kubectl set env deploy/modelmesh-controller NAMESPACE_SCOPE=true
sed -i.bak 's/#- bases\/serving.kserve.io_clusterservingruntimes.yaml/- bases\/serving.kserve.io_clusterservingruntimes.yaml/g' crd/kustomization.yaml
~~~


**Modelmesh namespace**
~~~
kubectl label namespace ${user_ns} modelmesh-enabled="true" --overwrite
kubectl apply -f runtimes.yaml -n ${user_ns}
~~~



## Model Mesh Model example by Minio 

### Customization
~~~
https://github.com/tedhtchang/modelmesh-serving/tree/Add-dockerfile-for-modelmesh-minio-examples-image/minio_examples
https://github.com/kserve/modelmesh-serving/pull/300
~~~

curl --create-dirs https://storage.openvinotoolkit.org/repositories/open_model_zoo/2022.1/models_bin/2/age-gender-recognition-retail-0013/FP32/age-gender-recognition-retail-0013.bin https://storage.openvinotoolkit.org/repositories/open_model_zoo/2022.1/models_bin/2/age-gender-recognition-retail-0013/FP32/age-gender-recognition-retail-0013.xml -o model/1/age-gender-recognition-retail-0013.bin -o model/1/age-gender-recognition-retail-0013.xml



# DownStream

## odh-manifest update check kfcfl

**Download kfctl**
~~~
wget https://github.com/kubeflow/kfctl/releases/download/v1.2.0/kfctl_v1.2.0-0-gbc038f9_linux.tar.gz

tar xvf kfctl_v1.2.0-0-gbc038f9_linux.tar.gz /tmp
cp /tmp/kfctl /usr/local/bin/.
~~~

**Upstream(ODH) odh-manifest test**
~~~
wget https://raw.githubusercontent.com/red-hat-data-services/odh-manifests/master/kfdef/kfctl_openshift_model_serving.yaml

kfctl build -f kfctl_openshift_model_serving.yaml
cd kustomize/model-mesh/
kustomize build . --load-restrictor LoadRestrictionsNone 
~~~

**Downstream(RHODS) odh-manifest test**
~~~
wget https://raw.githubusercontent.com/red-hat-data-services/odh-deployer/main/kfdefs/rhods-model-mesh.yaml

vi 
..
    - name: manifests
      uri: https://github.com/red-hat-data-services/odh-manifests/tarball/master


kfctl build -f rhods-model-mesh.yaml
cd kustomize/model-mesh/
kustomize build . --load-restrictor LoadRestrictionsNone 
~~~

**manifest sync flow**
1. https://github.com/opendatahub-io/modelmesh-serving/tree/main/manifests/opendatahub
2. https://github.com/red-hat-data-services/modelmesh-serving/tree/main/manifests/opendatahub
3. https://github.com/red-hat-data-services/odh-manifests/model-mesh 
4. https://github.com/opendatahub-io/odh-manifests/tree/master/model-mesh





[Sample Model](./Upstream/Installation/ModelMesh/README.md)

~~~
cd ./Upstream/Installation/ModelMesh
~~~



https://github.com/kserve/modelmesh-serving/blob/2d90aad548cb1b4b55f0c6b10b37577871494731/docs/configuration/README.md




## Ansible Wisdom Model on Watson Runtime

### with Upstream modelmesh

~~~

RELEASE=release-0.9
git clone -b $RELEASE --depth 1 --single-branch https://github.com/kserve/modelmesh-serving.git
cd modelmesh-serving

kubectl create namespace modelmesh-serving
./scripts/install.sh --namespace modelmesh-serving --quickstart


cat <<EOF |oc apply -f - 
apiVersion: v1
kind: ConfigMap
metadata:
  name: model-serving-config
data:
  config.yaml: |
    storageSecretName: storage-config-aws
EOF''

oc delete pod -l control-plane=modelmesh-controller

oc logs deploy/modelmesh-controller||grep storage-config-aws


kubectl create ns mm-1
kubectl label namespace mm-1 modelmesh-enabled=true --overwrite=true
kubectl config set-context --current --namespace=mm-1

cat <<EOF |oc apply -f - 
apiVersion: v1
kind: Secret
metadata:
  name: storage-config-aws
stringData:
  aws-connection-answis-dev: |
    {
      "type": "s3",
      "access_key_id": "XXXX",
      "secret_access_key": "XXXX",
      "endpoint_url": "http://s3.amazonaws.com",
      "default_bucket": "answis-dev",
      "region": "us-east-1"
    }
EOF



oc create secret docker-registry custom-registry-secret --docker-server='us.icr.io' --docker-username='XXXX'  --docker-password='XXXX' --docker-email='asood@us.@ibm.com'

# for "oc debug node"
kubectl create secret docker-registry redhat-registry-secret --from-file=.dockerconfigjson=/home/jooho/Downloads/pull-secret.txt

kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "custom-registry-secret"},{"name":"redhat-registry-secret"}]}'    

# NFS Provisioner
git clone git@github.com:Jooho/nfs-provisioner-operator.git
cd nfs-provisioner-operator

kustomize build ./config/default/|kubectl create -f -
export target_node=$(oc get node -l node-role.kubernetes.io/control-plane= --no-headers -o name |head -1|cut -d'/' -f2)
kubectl label node/${target_node} app=nfs-provisioner


# ssh to the node
oc debug node/${target_node}

# Create a directory and set up the Selinux label.
 chroot /host
 mkdir -p /home/core/nfs
 chcon -Rvt svirt_sandbox_file_t /home/core/nfs
 exit; exit


cat << EOF | oc apply -f -  
apiVersion: cache.jhouse.com/v1alpha1
kind: NFSProvisioner
metadata:
  name: nfsprovisioner-sample
  namespace: nfs-provisioner-operator
spec:
  hostPathDir: /home/core/nfs
  nodeSelector:
    app: nfs-provisioner
EOF

# Update annotation of the NFS StorageClass
oc patch storageclass nfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'


cat <<EOF |oc apply -f - 
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: watson-nlp-runtime-custom
  annotations:
    enable-route: "true"
    enable-auth: "false"
spec:
  #imagePullSecrets:
    #- name: custom-registry-secret
    #- name: ibm-entitlement-key
  containers:
  - env:
      - name: ACCEPT_LICENSE
        value: "true"
      - name: LOG_LEVEL
        value: info
      - name: CAPACITY
        value: "28000000000"
      - name: DEFAULT_MODEL_SIZE
        value: "1773741824"
      - name: METRICS_PORT
        value: "2113"
      - name: GATEWAY_PORT
        value: "8060"
      - name: STRICT_RPC_MODE
        value: "false"
      - name: HF_HOME
        value: "/tmp/"
      #- name: USE_EMBEDDED_PULLER
      #  value: 'true'
    image: us.icr.io/watson-runtime/fmaas-runtime-ansible:0.0.3
    imagePullPolicy: IfNotPresent
    name: watson-nlp-runtime
    resources:
      limits:
        cpu: 2
        memory: 16Gi
      requests:
        cpu: 1
        memory: 16Gi
  grpcDataEndpoint: port:8085
  grpcEndpoint: port:8085
  multiModel: true
  storageHelper:
    disabled: false
  supportedModelFormats:
    - autoSelect: true
      name: watson-nlp-custom
EOF

cat <<EOF |oc apply -f - 
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: syntax-izumo-en-custom-2
  annotations:
    serving.kserve.io/deploymentMode: ModelMesh
spec:
  predictor:
    model:
      modelFormat:
        name: watson-nlp-custom
      runtime: watson-nlp-runtime-custom
      storage:
        key: aws-connection-answis-dev
        path: model-files/ansible_ibm_model/aw_model/
EOF

k exec -it deploy/modelmesh-serving-watson-nlp-runtime-custom -c puller -- du -h --max-depth=1 /models

~~~
cat <<EOF |oc apply -f - 
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: models-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 30G
  storageClassName: nfs
EOF
 oc set volume models-dir --add

  oc set volume deploy/modelmesh-serving-watson-nlp-runtime-custom  --add --name=models-dir -t pvc --claim-name=models-pvc --overwrite


cat <<EOF |oc apply -f - 
apiVersion: v1
kind: ConfigMap
metadata:
  name: model-serving-config
data:
  config.yaml: |
    imagePullSecrets:
    - name: storage-config-aws
EOF
