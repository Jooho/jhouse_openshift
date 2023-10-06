#!/bin/bash

export MINIO_NS=minio
export MINIO_IMG=quay.io/jooholee/modelmesh-minio-examples:latest
export ACCESS_KEY_ID=THEACCESSKEY
export SECRET_ACCESS_KEY=THEPASSWORD
# export SECRET_ACCESS_KEY=$(openssl rand -hex 32)

if [[ ! -n $DEMO_HOME ]]
then
  export DEMO_HOME=/tmp/minio
fi
if [[ ! -n $BASE_CERT_DIR ]]
then
  export BASE_CERT_DIR=/tmp/minio/minio_certs
fi
export COMMON_NAME=minio.${MINIO_NS}

# Clean Up
sudo rm -rf ${BASE_CERT_DIR}
sudo rm -rf ${DEMO_HOME}
kubectl delete pod --all -n ${MINIO_NS} --force --grace-period=0
kubectl delete pod --all -n kserve-demo --force --grace-period=0
kubectl delete ns ${MINIO_NS} --force --grace-period=0 --wait
kubectl delete ns kserve-demo --force --grace-period=0 --wait

# Setup
mkdir -p ${DEMO_HOME}
mkdir -p ${BASE_CERT_DIR}

cd $DEMO_HOME

cat <<EOF> ${DEMO_HOME}/minio.yaml
apiVersion: v1
kind: Service
metadata:
  name: minio
spec:
  ports:
    - name: minio-client-port
      port: 9000
      protocol: TCP
      targetPort: 9000
  selector:
    app: minio
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: minio
  name: minio
spec:
  containers:
    - args:
        - server
        - /data1
      env:
        - name: MINIO_ROOT_USER
          value:  <accesskey>
        - name: MINIO_ROOT_PASSWORD
          value: <secretkey>
      image: ${MINIO_IMG}
      imagePullPolicy: Always
      name: minio
      volumeMounts:
        - name: minio-tls
          mountPath: /home/modelmesh/.minio/certs
  volumes:
    - name: minio-tls
      projected:
        defaultMode: 420
        sources:    
        - secret:
            items:
            - key: public.crt
              path: public.crt
            - key: private.key
              path: private.key
            - key: public.crt
              path: CAs/public.crt
            name: minio-tls
EOF

cat <<EOF> ${DEMO_HOME}/minio-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  annotations:
    serving.kserve.io/s3-endpoint: minio.<minio_ns>.svc:9000 # replace with your s3 endpoint e.g minio-service.kubeflow:9000
    serving.kserve.io/s3-usehttps: "1" # by default 1, if testing with minio you can set to 0
    serving.kserve.io/s3-verifyssl: "1"    
    serving.kserve.io/s3-region: "us-east-2"
    serving.kserve.io/s3-useanoncredential: "false" # omitting this is the same as false, if true will ignore provided credential and use anonymous credentials
  name: storage-config
stringData:
  "AWS_ACCESS_KEY_ID": "<accesskey>"
  "AWS_SECRET_ACCESS_KEY": "<secretkey>"
EOF


cat <<EOF> ${DEMO_HOME}/serviceaccount-minio.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa
secrets:
- name: storage-config
EOF

# Generate Certificate
cat <<EOF> ${BASE_CERT_DIR}/openssl-san.config
[ req ]
distinguished_name = req
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = minio.${MINIO_NS}
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3560 -nodes -keyout ${BASE_CERT_DIR}/private.key -out ${BASE_CERT_DIR}/public.crt -subj '/CN=minio' -extensions v3_req -config ${BASE_CERT_DIR}/openssl-san.config

cp $BASE_CERT_DIR/public.crt $BASE_CERT_DIR/AWS_CA_BUNDLE
openssl x509 -in ${BASE_CERT_DIR}/public.crt -text

# Deploy Minio
export CACERT=$(cat ${BASE_CERT_DIR}/public.crt | tr -d '\n' |sed 's/-----BEGIN CERTIFICATE-----/-----BEGIN CERTIFICATE-----\\\\n/g' |sed 's/-----E/\\\\n-----E/g')
kubectl create ns ${MINIO_NS}
kubectl config set-context --current --namespace ${MINIO_NS}
kubectl create secret generic minio-tls --from-file=${BASE_CERT_DIR}/private.key --from-file=${BASE_CERT_DIR}/public.crt
sed "s/<accesskey>/$ACCESS_KEY_ID/g"  ${DEMO_HOME}/minio.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" | tee ${DEMO_HOME}/minio-current.yaml | kubectl -n ${MINIO_NS} apply -f -
sed "s/<accesskey>/$ACCESS_KEY_ID/g" ${DEMO_HOME}/minio-secret.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" |sed "s/<minio_ns>/$MINIO_NS/g" |sed "s*<cacert>*$CACERT*g" | tee ${DEMO_HOME}/minio-secret-current.yaml | kubectl -n ${MINIO_NS} apply -f - 
sed "s/<minio_ns>/$MINIO_NS/g"  ${DEMO_HOME}/serviceaccount-minio.yaml | tee ${DEMO_HOME}/serviceaccount-minio-current.yaml 

######
cd ${DEMO_HOME}

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

kubectl create ns kserve-demo 

git clone git@github.com:kserve/kserve.git
cd kserve

sed 's/Serverless/RawDeployment/g' -i config/configmap/inferenceservice.yaml

sed 's+kserve/storage-initializer:latest+quay.io/jooholee/storage-initializer:verifyssl+g' -i config/configmap/inferenceservice.yaml

kustomize build config/default | kubectl apply -f -
kubectl wait --for=condition=ready pod -l control-plane=kserve-controller-manager -n kserve --timeout=300s
kustomize build config/runtimes | kubectl apply -n kserve-demo -f -

kubectl config set-context --current --namespace kserve-demo
kubectl create -f ${DEMO_HOME}/minio-secret-current.yaml 
kubectl create -f ${DEMO_HOME}/serviceaccount-minio.yaml

cat <<EOF> ${DEMO_HOME}/sklearn-isvc.yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  annotations:
    serving.knative.openshift.io/enablePassthrough: "true"
    sidecar.istio.io/inject: "true"
    sidecar.istio.io/rewriteAppHTTPProbers: "true"
  name: sklearn-example-isvc
spec:
  predictor:
    serviceAccountName: sa
    model:
      modelFormat:
        name: sklearn
      runtime: kserve-mlserver
      storageUri: s3://modelmesh-example-models/sklearn/model.joblib
EOF

kubectl create -f ${DEMO_HOME}/sklearn-isvc.yaml
