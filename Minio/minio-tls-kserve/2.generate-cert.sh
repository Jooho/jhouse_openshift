#!/bin/bash
source "$(dirname "$0")/env.sh"
# source "$(dirname "$0")/utils.sh"

if [[ $IS_OCP == "true" ]]
then
  EXTERNAL_ROUTE_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
fi

# Clean Up
if [[ $CLEAN_FIRST == "true" ]]
then
  sudo rm -rf ${DEMO_HOME}
  sudo rm -rf ${BASE_CERT_DIR}
  oc delete ns ${MINIO_NS} --force --wait
fi

# Generate Certificate
cat <<EOF> ${BASE_CERT_DIR}/openssl-san.config
[ req ]
distinguished_name = req
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = minio.${MINIO_NS}.svc
DNS.2 = minio.${MINIO_NS}.svc.cluster.local
DNS.3 = minio-${MINIO_NS}.${EXTERNAL_ROUTE_DOMAIN}
EOF

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096  -subj "/O=Example Inc./CN=root"  -keyout $BASE_CERT_DIR/root.key  -out $BASE_CERT_DIR/root.crt

openssl req -nodes --newkey rsa:4096 -subj "/CN=minio/O=Example Inc."  --keyout $BASE_CERT_DIR/minio.key -out $BASE_CERT_DIR/minio.csr -config $BASE_CERT_DIR/openssl-san.config

openssl x509 -req -in $BASE_CERT_DIR/minio.csr -CA $BASE_CERT_DIR/root.crt -CAkey $BASE_CERT_DIR/root.key -CAcreateserial -out $BASE_CERT_DIR/minio.crt -days 365 -sha256 -extfile $BASE_CERT_DIR/openssl-san.config -extensions v3_req

#openssl req -x509 -newkey rsa:4096 -sha256 -days 3560 -nodes -keyout ${BASE_CERT_DIR}/private.key -out ${BASE_CERT_DIR}/public.crt -subj '/CN=minio' -extensions v3_req -config ${BASE_CERT_DIR}/openssl-san.config

openssl x509 -in ${BASE_CERT_DIR}/minio.crt -text

echo "Veriry cert"
openssl verify -CAfile ${BASE_CERT_DIR}/root.crt ${BASE_CERT_DIR}/minio.crt

