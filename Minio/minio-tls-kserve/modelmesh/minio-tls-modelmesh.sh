#!/bin/bash

export MINIO_NS=minio
export MINIO_IMG=quay.io/opendatahub/modelmesh-minio-examples:caikit-flan-t5
export ACCESS_KEY_ID=THEACCESSKEY
export SECRET_ACCESS_KEY=$(openssl rand -hex 32)
export DOMAIN_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' | awk -F'.' '{print $(NF-1)"."$NF}')
export COMMON_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'|sed 's/apps.//')

export DEMO_HOME=/tmp/minio-2
export BASE_CERT_DIR=/tmp/minio_certs-2
export DOMAIN_NAME=${MINIO_NS}.svc
export COMMON_NAME=minio.${DOMAIN_NAME}

# Clean Up
rm -rf ${DEMO_HOME}
rm -rf ${BASE_CERT_DIR}

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
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
-subj "/O=Example Inc./CN=${DOMAIN_NAME}" \
-keyout $BASE_CERT_DIR/root.key \
-out $BASE_CERT_DIR/root.crt

openssl req -nodes -newkey rsa:2048 \
-subj "/CN=${COMMON_NAME}/O=Example Inc." \
-keyout $BASE_CERT_DIR/private.key \
-out $BASE_CERT_DIR/minio.csr

openssl x509 -req -days 365 -set_serial 0 \
-CA $BASE_CERT_DIR/root.crt \
-CAkey $BASE_CERT_DIR/root.key \
-in $BASE_CERT_DIR/minio.csr \
-out $BASE_CERT_DIR/public.crt

openssl x509 -in ${BASE_CERT_DIR}/public.crt -text

# Deploy Minio
export CACERT=$(cat ${BASE_CERT_DIR}/root.crt | tr -d '\n' |sed 's/-----BEGIN CERTIFICATE-----/-----BEGIN CERTIFICATE-----\\\\n/g' |sed 's/-----E/\\\\n-----E/g')
oc new-project ${MINIO_NS}
oc create secret generic minio-tls --from-file=${BASE_CERT_DIR}/private.key --from-file=${BASE_CERT_DIR}/public.crt
sed "s/<accesskey>/$ACCESS_KEY_ID/g"  ${DEMO_HOME}/minio.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" | tee ${DEMO_HOME}/minio-current.yaml | oc -n ${MINIO_NS} apply -f -
sed "s/<accesskey>/$ACCESS_KEY_ID/g" ${DEMO_HOME}/minio-secret.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" |sed "s/<minio_ns>/$MINIO_NS/g" |sed "s*<cacert>*$CACERT*g" | tee ${DEMO_HOME}/minio-secret-current.yaml | oc -n ${MINIO_NS} apply -f - 
