# Create global operatorgroup in openshift-operators-redhat
~~~
cat <<EOF|oc create -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  annotations:
    olm.providedAPIs: Elasticsearch.v1.logging.openshift.io,Kibana.v1.logging.openshift.io
  name: openshift-operators-redhat-f6d8w
  namespace: openshift-operators-redhat
spec: {}
EOF
~~~

# Deploy ElasticSearch
~~~
cat <<EOF|oc create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/elasticsearch-operator.openshift-operators-redhat: ""
  name: elasticsearch-operator
  namespace: openshift-operators-redhat
spec:
  channel: "stable-5.1"
  installPlanApproval: Automatic
  name: elasticsearch-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: elasticsearch-operator.5.1.0-96
EOF
~~~

# Deploy Jaeger
~~~
cat <<EOF|oc create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/jaeger-product.openshift-operators: ""
  name: jaeger-product
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: jaeger-product
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: jaeger-operator.v1.20.4
EOF
~~~



# Deploy Kiali
~~~
cat <<EOF|oc create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/kiali-ossm.openshift-operators: ""
  name: kiali-ossm
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: kiali-ossm
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: kiali-operator.v1.24.8
EOF
~~~

# Deploy ServiceMesh
~~~
cat <<EOF|oc create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/servicemeshoperator.openshift-operators: ""
  name: servicemeshoperator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: servicemeshoperator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: servicemeshoperator.v2.0.6.2
EOF
~~~

# Create istio-system project
~~~
oc new-project istio-system
~~~

# Create SMCP
~~~
cat <<EOF|oc create -f -
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  addons:
    grafana:
      enabled: true
    jaeger:
      install:
        storage:
          type: Memory
    kiali:
      enabled: true
    prometheus:
      enabled: true
  policy:
    type: Istiod
  profiles:
  - default
  telemetry:
    type: Istiod
  tracing:
    sampling: 10000
    type: Jaeger
  version: v2.0
EOF
~~~




# Create bookinfo project
~~~
oc new-project bookinfo
~~~

# Create SMMR
~~~
cat <<EOF|oc create -f -
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system
spec:
  members:
  - bookinfo
EOF
~~~



# Deploy bookinfo application
~~~
oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/platform/kube/bookinfo.yaml
~~~

# Create ISTIO object
~~~
oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/networking/bookinfo-gateway.yaml
oc apply -n bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/networking/destination-rule-all.yaml
~~~

# Verify bookinfo application
~~~
export GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
curl  -o /dev/null -s -w "%{http_code}\n"  $(echo "http://$GATEWAY_URL/productpage")
~~~



-----------------------------------------------

# Create clusterrolebinding for service account
~~~
cat <<EOF|oc create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: bookinfo-auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: bookinfo-productpage
    namespace: bookinfo
EOF
~~~

# Create oauth-proxy-tls-secret
~~~
oc annotate service productpage service.beta.openshift.io/serving-cert-secret-name=oauth-proxy-tls-secret
~~~

# Create cabundle configmap
~~~
oc create cm serving-certs-ca-bundle
oc annotate configmap serving-certs-ca-bundle service.beta.openshift.io/inject-cabundle=true
~~~

# Add redirect-url annotation
~~~
oc annotate serviceaccount bookinfo-productpage serviceaccounts.openshift.io/oauth-redirecturi.primary=http://istio-ingressgateway-istio-system.apps.jooho-test.fepc.s1.devshift.org
~~~

# Add prefix and change http port for oauth proxy
~~~
oc patch vs/bookinfo -p='[{"op": "add", "path": "/spec/http/0/match/-", "value": {"uri": {"prefix": "/oauth"}}}]' --type=json 
oc patch vs/bookinfo -p='[{"op": "replace", "path": "/spec/http/0/route/0/destination/port/number", "value": 4180}]' --type=json
~~~

# Add http port for oauth proxy in productpage svc
~~~
 oc patch svc/productpage -p='[{"op": "add", "path": "/spec/ports/-", "value":{"name": "oauth-http","port":4180,"targetPort":4180}}]' --type='json'
~~~


# Add oauthproxy into productpage deployment
~~~

     - args:
        - -provider=openshift
        - -https-address=:9090
        - -http-address=:4180
        - -email-domain=*
        - -upstream=http://localhost:9080
        - '-openshift-sar={"namespace": "bookinfo", "resource": "pods", "verb": "get"}'
        - '-openshift-delegate-urls={"/": {"namespace":"bookinfo","resource":"services","verb":"list"}}'
        - -client-secret-file=/var/run/secrets/kubernetes.io/serviceaccount/token
        - -openshift-service-account=bookinfo-productpage
        - -tls-cert=/tls/tls.crt
        - -tls-key=/tls/tls.key
        - -openshift-ca=/etc/configmap/trusted-ca-bundle/service-ca.crt
        - -openshift-ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        - -cookie-secret=SECRET
        - -cookie-name=bookinfo
        - -skip-auth-regex=^/metrics
        - -redirect-url=http://istio-ingressgateway-istio-system.apps.jooho-test.fepc.s1.devshift.org/productpage
        - -cookie-secure=false
        image: quay.io/openshift/origin-oauth-proxy:4.7.0
        imagePullPolicy: IfNotPresent
        name: oauth-proxy
        ports:
        - containerPort: 9090
          name: https
          protocol: TCP
        - containerPort: 4180
          name: http
          protocol: TCP
        resources:
          limits:
            cpu: 100m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 256Mi
        volumeMounts:
        - mountPath: /tls
          name: oauth-proxy-tls-secret
          readOnly: true
        - mountPath: /etc/configmap/trusted-ca-bundle
          name: configmap-trusted-ca-bundle
          readOnly: true
          
      volumes:    
      - name: oauth-proxy-tls-secret
        secret:
          defaultMode: 420
          secretName: oauth-proxy-tls-secret
      - configMap:
          defaultMode: 420
          name: serving-certs-ca-bundle
          optional: true
        name: configmap-trusted-ca-bundle
~~~
