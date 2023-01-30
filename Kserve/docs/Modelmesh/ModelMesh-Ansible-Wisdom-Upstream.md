# Ansible Wisdom Model running on Watson Runtime using Kubernetes(KIND)

*Environment*
 - kind
 - ModelMesh 0.10

**Pre-requisite**
- [Install KIND](../ETC/Kind.md)
- [Install Tools](../ETC/ToolBinary.md)

**Pre-resuisite steps & check**
~~~
# Deploy kuberentes
kind create cluster

# Check yq version
yq --version
yq (https://github.com/mikefarah/yq/) version v4.30.8

# Export demo home
export DEMO_HOME=/tmp/modelmesh
mkdir -p $DEMO_HOME
cd $DEMO_HOME

# Clone jhouse repository
git clone https://github.com/Jooho/jhouse_openshift.git

# Export common script
source ${DEMO_HOME}/jhouse_openshift/docs/kserve/demos/utils/common.sh
~~~

**Install Model Mesh**
~~~
RELEASE=release-0.10
git clone -b $RELEASE --depth 1 --single-branch https://github.com/kserve/modelmesh-serving.git
cd modelmesh-serving

kubectl create namespace modelmesh-serving
./scripts/install.sh --namespace modelmesh-serving --quickstart
~~~

**Verify Model Mesh**
~~~
$ kubectl get pod
NAME                                  READY   STATUS    RESTARTS   AGE
etcd-7dbb56b4d9-t4mjp                 1/1     Running   0          64s
minio-5574dbcd98-6k85t                1/1     Running   0          64s
modelmesh-controller-85df6856-pzqtn   1/1     Running   0          32s
~~~

**Change base secret name to pull models**

Model Serving use a secret `model-serving-config` to overwrite default configuraiton.
The secret have to has a config.yaml key only.

~~~
cat <<EOF |oc apply -f - 
apiVersion: v1
kind: ConfigMap
metadata:
  name: model-serving-config
data:
  config.yaml: |
    storageSecretName: storage-config-aws
EOF

kubectl delete pod -l control-plane=modelmesh-controller

check_pod_ready  control-plane=modelmesh-controller modelmesh-serving

kubectl logs deploy/modelmesh-controller|grep storage-config-aws
~~~

## Deploy Ansible Wisdom on Watson Runtime

**Create a ns**
~~~
kubectl create ns mm-1
kubectl label namespace mm-1 modelmesh-enabled=true --overwrite=true
kubectl config set-context --current --namespace=mm-1
~~~

**Create a secret**
Request Secret information to Ewran.
~~~
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
~~~


oc create secret docker-registry custom-registry-secret --docker-server='us.icr.io' --docker-username='xxxx'  --docker-password='xxxx' --docker-email='asood@us.@ibm.com'

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

##Test
~~~
git clone 	git@github.com:rh-aiservices-pilot/ans-wis-model.git
oc port-forward svc/modelmesh-serving 8033:8033
cd ans-wis-model/clientcalls
chmod 777 grpcurl.sh

./grpcurl.sh "install node on rhel" 
install node on rhel
{
  "label": "- name: install node on rhel\n  yum: name=nodejs state=present enablerepo=nodejs\n",
  "producerId": {
    "name": "Ansible wisdom model",
    "version": "0.0.1"
  }
}

real	0m23.083s
user	0m0.201s
sys	0m0.034s

~~~




Env
 - CRC
 - RHODS (https://github.com/rh-aiservices-pilot/ans-wis-model/blob/main/deploy.rhods.livebuild.and.override.sh)


