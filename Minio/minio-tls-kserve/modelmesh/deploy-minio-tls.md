# Deploy Minio with TLS

## Setup
~~~
git clone git@github.com:Jooho/jhouse_openshift.git
cd jhouse_openshift/Minio/minio-tls-kserve/modelmesh

export MINIO_NS=minio
export ACCESS_KEY_ID=THEACCESSKEY
export SECRET_ACCESS_KEY=$(openssl rand -hex 32)
export DOMAIN_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' | awk -F'.' '{print $(NF-1)"."$NF}')
export COMMON_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'|sed 's/apps.//')

export DEMO_HOME=/tmp/minio
export BASE_CERT_DIR=/tmp/minio/minio_certs
export DOMAIN_NAME=${MINIO_NS}.svc
export COMMON_NAME=minio.${DOMAIN_NAME}
mkdir ${DEMO_HOME}
mkdir ${BASE_CERT_DIR}
~~~

## Generate TLS Cert using openssl
~~~
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
~~~

## Generate SAN TLS Cert using openssl
~~~
cat <<EOF> ${BASE_CERT_DIR}/openssl-san.config
[ req ]
distinguished_name = req
[ san ]
subjectAltName = DNS:minio.${MINIO_NS}.svc
EOF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3560 -nodes -keyout ${BASE_CERT_DIR}/private.key -out ${BASE_CERT_DIR}/public.crt -subj '/CN=minio' -extensions san -config ${BASE_CERT_DIR}/openssl-san.config
~~~

## Generate TLS Cert using playbook (another way)
~~~
git clone git@github.com:Jooho/ansible-cheat-sheet.git
cd ansible-cheat-sheet/ansible-playbooks/ansible-playbook-generate-self-signed-cert/

ansible-playbook ./playbook.yaml -e use_intermediate_cert=false -e cert_commonName=minio.${MINIO_NS} -e cert_base_dir=${BASE_CERT_DIR} -b -e "{san_dns: [{ index: 1, dns: \"minio.${MINIO_NS}.svc\" }, { index: 2, dns: \"minio.${MINIO_NS}.svc.cluster.local\" },{ index: 3, dns: \"*.minio-hl.{MINIO_NS}.svc.cluster.local\" },{ index: 4, dns: \"*.minio.${MINIO_NS}.svc.cluster.local\" }]}" -vvvv

cp ${BASE_CERT_DIR}/minio.${MINIO_NS}/minio.${MINIO_NS}.cert.pem ${BASE_CERT_DIR}/public.crt
cp ${BASE_CERT_DIR}/minio.${MINIO_NS}/minio.${MINIO_NS}.key.pem ${BASE_CERT_DIR}/private.key
cp ${BASE_CERT_DIR}/certs/root-ca.cert.pem ${BASE_CERT_DIR}/root.crt

openssl x509 -in ${BASE_CERT_DIR}/public.crt -text

cd -

cd jhouse_openshift/Minio/minio-tls-kserve/modelmesh
~~~

## Deploy Minio
~~~
export CACERT=$(cat ${BASE_CERT_DIR}/public.crt | tr -d '\n' |sed 's/-----BEGIN CERTIFICATE-----/-----BEGIN CERTIFICATE-----\\\\n/g' |sed 's/-----E/\\\\n-----E/g')
oc new-project ${MINIO_NS}

oc create secret generic minio-tls --from-file=${BASE_CERT_DIR}/private.key --from-file=${BASE_CERT_DIR}/public.crt

sed "s/<accesskey>/$ACCESS_KEY_ID/g"  ../common_manifests/minio.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" | tee ${DEMO_HOME}/minio-current.yaml | oc -n ${MINIO_NS} apply -f -
sed "s/<accesskey>/$ACCESS_KEY_ID/g" ./manifests/minio-secret.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" |sed "s/<minio_ns>/$MINIO_NS/g" |sed "s*<cacert>*$CACERT*g" | tee ${DEMO_HOME}/minio-secret-current.yaml | oc -n ${MINIO_NS} apply -f - 
~~~
