#!/bin/bash
source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/utils.sh"

export MINIO_NS=minio
export MINIO_IMG=quay.io/jooholee/modelmesh-minio-examples:v0.11.0
export ACCESS_KEY_ID=THEACCESSKEY
export SECRET_ACCESS_KEY=$(openssl rand -hex 32)

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
        #- --console-address
        #- :9001
      env:
        - name: MINIO_ROOT_USER
          value:  <accesskey>
        - name: MINIO_ROOT_PASSWORD
          value: <secretkey>
      image: ${MINIO_IMG}
      imagePullPolicy: Always
      name: minio
EOF

## Check if ${MINIO_NS} exist
oc project ${MINIO_NS} ||  oc new-project ${MINIO_NS}

oc get pod minio -n ${MINIO_NS}
if [[ $? ==  1 ]]
then
  sed "s/<accesskey>/$ACCESS_KEY_ID/g"  ${DEMO_HOME}/minio.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" | tee ${DEMO_HOME}/minio-current.yaml | oc -n ${MINIO_NS} apply -f -
  
  wait_for_pods_ready app=minio ${MINIO_NS}
fi
