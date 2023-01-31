# How to deploy

~~~
# Create a new namespace
oc new-project oauth-proxy
# Search sample PHP application (Optional)
oc new-app -S php -n oauth-proxy
# Create cakephp-mysql-example application
oc new-app --template=cakephp-mysql-example -n oauth-proxy

# Check return value is 200
curl -o /dev/null -s -w "%{http_code}\n" -k $(oc get route cakephp-mysql-example-ssl -ojsonpath='{.spec.host}')

# Then execute the following:
oc apply -f ./
~~~

# How to check
~~~
google-chrome $(oc get route cakephp-mysql-example-ssl -ojsonpath='{.spec.host}')
~~~

# Load Test
~~~
cat <<EOF> /tmp/cakephp-ssl.yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  labels:
    app: cakephp-mysql-example
    template: cakephp-mysql-example
  name: cakephp-mysql-example
  namespace: oauth-proxy
spec:
  port:
    targetPort: oauth-https
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: reencrypt
  to:
    kind: Service
    name: cakephp-mysql-example
    weight: 100
  wildcardPolicy: None
EOF

for i in {1..200} ; do sed "7s/name:.*/name: cakephp-mysql-example-$i/g" /tmp/cakephp-ssl.yaml |oc apply -f - ; done
for i in {1..200} ; do oc delete route cakephp-mysql-example-$i ; done
~~~

# Enable Router Access Log
~~~
cat <<EOF> /tmp/router-access-log.yaml
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: default
  namespace: openshift-ingress-operator
spec:
  logging:
    access:
      destination:
        type: Container
      httpLogFormat: log_source="haproxy-default" log_type="http" c_ip="%ci" c_port="%cp"
        req_date="%tr" fe_name_transport="%ft" be_name="%b" server_name="%s" res_time="%TR"
        tot_wait_q="%Tw" Tc="%Tc" Tr="%Tr" Ta="%Ta" status_code="%ST" bytes_read="%B"
        bytes_uploaded="%U" captrd_req_cookie="%CC" captrd_res_cookie="%CS" term_state="%tsc"
        actconn="%ac" feconn="%fc" beconn="%bc" srv_conn="%sc" retries="%rc" srv_queue="%sq"
        backend_queue="%bq" captrd_req_headers="%hr" captrd_res_headers="%hs" http_request="%r"
      logEmptyRequests: Log
EOF

oc patch ingresscontrollers.operator.openshift.io/default -n openshift-ingress-operator --patch-file=/tmp/router-access-log.yaml --type=merge

# Check
oc edit ingresscontrollers.operator.openshift.io -n openshift-ingress-operator
~~~
