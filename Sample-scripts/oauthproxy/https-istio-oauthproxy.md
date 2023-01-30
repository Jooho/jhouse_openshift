# Generate wildcard certificate which will be used in Gateway for bookinfo application 
~~~
git clone git@github.com:Jooho/ansible-cheat-sheet.git
cd ansible-cheat-sheet/ansible-playbooks/ansible-playbook-generate-self-signed-cert/
ansible-galaxy install -f -r requirements.yaml
ansible-playbook ./playbook.yaml -e cert_commonName='*.apps.jooho-test.fepc.s1.devshift.org' -e cert_base_dir=/tmp/cert_base -b -vvvv
openssl x509 -in /home/jooho/cert_base/wild.apps.jooho-test.fepc.s1.devshift.org/wild.apps.jooho-test.fepc.s1.devshift.org.cert.pem  -text
~~~

# Create secrete with the generated wild certificates
~~~
cp /tmp/cert_base/wild.apps.jooho-test.fepc.s1.devshift.org/wild.apps.jooho-test.fepc.s1.devshift.org.cert.pem /tmp/tls.crt
cp /tmp/cert_base/wild.apps.jooho-test.fepc.s1.devshift.org/wild.apps.jooho-test.fepc.s1.devshift.org.key.pem /tmp/tls.pem

oc create -n istio-system secret tls wildcard-certs \
    --key=/tmp/tls.pem \
    --cert=/tmp/tls.crt
~~~

# Create PeerAuthentication to force mtls in bookinfo namespace
~~~
cat <<EOF | oc apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF
~~~

# Create https gateway which use the wildcard certs.
~~~
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: bookinfo-https
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - bookinfo.apps.jooho-test.fepc.s1.devshift.org
    tls:
      mode: SIMPLE
      credentialName: wildcard-certs
EOF
~~~

# Add https virtualService for bookinfo
~~~
oc patch vs/bookinfo -p='[{"op": "add", "path": "/spec/gateways/-", "value": "bookinfo-https"}]' --type=json 
~~~

--------------------------------------------------

# Add prefix and change https port for oauth proxy
~~~
oc patch vs/bookinfo-https -p='[{"op": "add", "path": "/spec/http/0/match/-", "value": {"uri": {"prefix": "/oauth"}}}]' --type=json 
oc patch vs/bookinfo-https -p='[{"op": "replace", "path": "/spec/http/0/route/0/destination/port/number", "value": 9090}]' --type=json
~~~

# Add http port for oauth proxy in productpage svc
~~~
oc patch svc/productpage -p='[{"op": "add", "path": "/spec/ports/-", "value":{"name": "oauth-https","port":9090,"targetPort":9090}}]' --type='json'
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
        - -openshift-ca=/etc/configmap/trusted-ca-bundle/ca-bundle.crt
        - -openshift-ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        - -cookie-secret=SECRET
        - -cookie-name=bookinfo
        - -skip-auth-regex=^/metrics
        - -redirect-url=http://istio-ingressgateway-istio-system.apps.jooho-test.fepc.s1.devshift.org/productpage
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
          name: trusted-ca-bundle
          optional: true
        name: configmap-trusted-ca-bundle
~~~

 
