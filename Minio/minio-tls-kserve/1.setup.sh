#!/bin/bash
source "$(dirname "$0")/env.sh"
# source "$(dirname "$0")/utils.sh"

# Clean Up
if [[ $CLEAN_FIRST == "true" ]]
then
  sudo rm -rf ${DEMO_HOME}
  sudo rm -rf ${BASE_CERT_DIR}
  oc delete ns ${MINIO_NS} --force --wait
fi

# Setup
if [[ ! -d $DEMO_HOME ]]
then
  mkdir ${DEMO_HOME}
fi
cd $DEMO_HOME

if [[ ! -d $BASE_CERT_DIR ]]
then
  mkdir ${BASE_CERT_DIR}
fi

if [[ ! -d ./jhouse_openshift ]]
then
  git clone git@github.com:Jooho/jhouse_openshift.git
fi

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
        # - --console-address
        # - :9001
      env:
        - name: MINIO_ROOT_USER
          value:  THEACCESSKEY
        - name: MINIO_ROOT_PASSWORD
          value: THEPASSWORD
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
            - key: minio.crt
              path: public.crt
            - key: minio.key
              path: private.key
            - key: root.crt
              path: CAs/root.crt
            name: minio-tls
EOF
