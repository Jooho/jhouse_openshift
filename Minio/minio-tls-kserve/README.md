# Deploy Minio with TLS

## Setup
~~~
git clone git@github.com:Jooho/jhouse_openshift.git
cd jhouse_openshift/Minio/minio-tls-kserve

export MINIO_NS=minio
export ACCESS_KEY_ID=THEACCESSKEY
export SECRET_ACCESS_KEY=$(openssl rand -hex 32)
export DOMAIN_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' | awk -F'.' '{print $(NF-1)"."$NF}')
export COMMON_NAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'|sed 's/apps.//')

export BASE_CERT_DIR=/tmp/minio_certs
export DOMAIN_NAME=${MINIO_NS}.svc
export COMMON_NAME=minio.${DOMAIN_NAME}
~~~

## Generate TLS Cert using openssl
~~~
mkdir ${BASE_CERT_DIR}

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

## Generate TLS Cert using playbook (another way)
~~~
mkdir /tmp/minio_certs
git clone git@github.com:Jooho/ansible-cheat-sheet.git
cd ansible-cheat-sheet/ansible-playbooks/ansible-playbook-generate-self-signed-cert/

ansible-playbook ./playbook.yaml -e use_intermediate_cert=false -e cert_commonName=minio.minio -e cert_BASE_CERT_DIR=/tmp/minio_certs -b -e '{san_dns: [{ index: 1, dns: "minio.minio.svc" }, { index: 2, dns: "minio.minio.svc.cluster.local" },{ index: 3, dns: "*.minio.minio-hl.svc.cluster.local" },{ index: 4, dns: "*.minio.minio.svc.cluster.local" }]}' -vvvv

cp /tmp/minio_certs/minio.minio/minio.minio.cert.pem /tmp/minio_certs/public.crt
cp /tmp/minio_certs/minio.minio/minio.minio.key.pem /tmp/minio_certs/private.key
cp /tmp/minio_certs/certs/root-ca.cert.pem /tmp/minio_certs/root.crt
cd -
cd jhouse_openshift/Minio/minio-tls-kserve
~~~

## Deploy Minio
~~~
oc new-project ${MINIO_NS}

oc create secret generic minio-tls --from-file=${BASE_CERT_DIR}/private.key --from-file=${BASE_CERT_DIR}/public.crt

sed "s/<accesskey>/$ACCESS_KEY_ID/g"  ./manifests/minio.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" | tee ./minio-current.yaml | oc -n ${MINIO_NS} apply -f -
sed "s/<accesskey>/$ACCESS_KEY_ID/g" ./manifests/minio-secret.yaml | sed "s+<secretkey>+$SECRET_ACCESS_KEY+g" |sed "s/<minio_ns>/$MINIO_NS/g" | tee ./minio-secret-current.yaml | oc -n ${MINIO_NS} apply -f - 

sed "s/<minio_ns>/$MINIO_NS/g" ./manifests/serviceaccount-minio.yaml | tee ./serviceaccount-minio-current.yaml 
~~~


~~~
export TEST_NS=kserve-demo
oc new-project ${TEST_NS}
oc patch smmr/default -n istio-system --type='json' -p="[{'op': 'add', 'path': '/spec/members/-', 'value': \"$TEST_NS\"}]"
sed "s/<test_ns>/$TEST_NS/g" manifests/service-mesh/peer-authentication-test-ns.yaml | tee ./peer-authentication-test-ns-current.yaml | oc apply -f -
# we need this because of https://access.redhat.com/documentation/en-us/openshift_container_platform/4.12/html/serverless/serving#serverless-domain-mapping-custom-tls-cert_domain-mapping-custom-tls-cert
~~~



## Create Caikit ServingRuntime

~~~

oc apply -f ./manifests/caikit/caikit-servingruntime.yaml
~~~

## Deploy example model(flan-t5-samll)

~~~
oc apply -f ./minio-secret-current.yaml 
oc create -f ./serviceaccount-minio-current.yaml

oc apply -f ./manifests/caikit/caikit-isvc.yaml -n ${TEST_NS}
~~~


awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' /tmp/minio_certs/root.crt 
