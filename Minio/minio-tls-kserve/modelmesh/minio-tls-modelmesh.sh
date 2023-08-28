#!/bin/bash

export MINIO_NS=minio
export MINIO_IMG=quay.io/opendatahub/modelmesh-minio-examples:caikit-flan-t5
export ACCESS_KEY_ID=THEACCESSKEY
export SECRET_ACCESS_KEY=$(openssl rand -hex 32)
export DOMAIN_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' | awk -F'.' '{print $(NF-1)"."$NF}')
export COMMON_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'|sed 's/apps.//')

if [[ ! -n $DEMO_HOME ]]
then
  export DEMO_HOME=/tmp/minio
fi
if [[ ! -n $BASE_CERT_DIR ]]
then
  export BASE_CERT_DIR=/tmp/minio_certs
fi
export DOMAIN_NAME=${MINIO_NS}.svc
export COMMON_NAME=minio.${DOMAIN_NAME}

# Clean Up
sudo rm -rf ${DEMO_HOME}
sudo rm -rf ${BASE_CERT_DIR}
oc delete ns ${MINIO_NS} --force --wait

# Setup
mkdir ${DEMO_HOME}
mkdir ${BASE_CERT_DIR}

cd $DEMO_HOME
git clone git@github.com:Jooho/jhouse_openshift.git
cd jhouse_openshift/Minio/minio-tls-kserve/modelmesh

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
  name: storage-config
stringData:
  localMinIO: |
    {
      "type": "s3",
      "access_key_id": "<accesskey>",
      "secret_access_key": "<secretkey>",
      "endpoint_url": "https://minio.<minio_ns>.svc:9000",
      "default_bucket": "modelmesh-example-models",
      "region": "us-south",
      "certificate": "<cacert>"
    }
EOF

# Generate Certificate
cat <<EOF> ${BASE_CERT_DIR}/openssl-san.config
[ req ]
distinguished_name = req
[ san ]
subjectAltName = DNS:minio.${MINIO_NS}.svc
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3560 -nodes -keyout ${BASE_CERT_DIR}/private.key -out ${BASE_CERT_DIR}/public.crt -subj '/CN=minio' -extensions san -config ${BASE_CERT_DIR}/openssl-san.config

cp $BASE_CERT_DIR/public.crt $BASE_CERT_DIR/AWS_CA_BUNDLE
openssl x509 -in ${BASE_CERT_DIR}/public.crt -text

# Deploy Minio
export CACERT=$(cat ${BASE_CERT_DIR}/public.crt | tr -d '\n' |sed 's/-----BEGIN CERTIFICATE-----/-----BEGIN CERTIFICATE-----\\\\n/g' |sed 's/-----E/\\\\n-----E/g')
oc new-project ${MINIO_NS}
oc create secret generic minio-tls --from-file=${BASE_CERT_DIR}/private.key --from-file=${BASE_CERT_DIR}/public.crt
sed "s/<accesskey>/$ACCESS_KEY_ID/g"  ${DEMO_HOME}/minio.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" | tee ${DEMO_HOME}/minio-current.yaml | oc -n ${MINIO_NS} apply -f -
sed "s/<accesskey>/$ACCESS_KEY_ID/g" ${DEMO_HOME}/minio-secret.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" |sed "s/<minio_ns>/$MINIO_NS/g" |sed "s*<cacert>*$CACERT*g" | tee ${DEMO_HOME}/minio-secret-current.yaml | oc -n ${MINIO_NS} apply -f - 
