# How to deploy

~~~
# Create a new namespace
oc new-project oauth-proxy
# Search sample PHP application (Optional)
oc new-app -S php -n oauth-proxy
# Create cakephp-mysql-example application
oc new-app --template=cakephp-mysql-example -n oauth-proxy

# Check return value is 200
curl -o /dev/null -s -w "%{http_code}\n" -k $(oc get route cakephp-mysql-example -ojsonpath='{.spec.host}')

# Then execute the following:
oc apply -f ./
~~~

# How to check
~~~
google-chrome $(oc get route cakephp-mysql-example -ojsonpath='{.spec.host}')
~~~


# Load Test
~~~
cat <<EOF> /tmp/cakephp.yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  labels:
    app: cakephp-mysql-example
    template: cakephp-mysql-example
  name: cakephp-mysql-example
  namespace: oauth-proxy
spec:
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: edge
  to:
    kind: Service
    name: cakephp-mysql-example
    weight: 100
  wildcardPolicy: None
EOF

for i in {1..200} ; do sed "7s/name:.*/name: cakephp-mysql-example-$i/g" /tmp/cakephp.yaml |oc apply -f - ; done
for i in {1..200} ; do oc delete route cakephp-mysql-example-$i ; done
~~~
