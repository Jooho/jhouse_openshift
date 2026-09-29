# PoC for AIGuardRail

## Setup

* Install MaaS + AIGateway
```
git clone git@github.com:opendatahub-io/models-as-a-service.git

cd models-as-a-service

# Deploy ODH (default)
./scripts/deploy.sh

# Deploy RHOAI
#./scripts/deploy.sh --operator-type rhoai

# Deploy via Kustomize
#./scripts/deploy.sh --deployment-mode kustomize

# Deploy without TLS backend (HTTP for Authorino to maas-api)
./scripts/deploy.sh --disable-tls-backend	


INGRESS_MODE=ocproute ./scripts/setup-gateway.sh
```

* Enable TrustyAI
```
kubectl patch datasciencecluster default-dsc \
  --type=merge \
  -p '{
    "spec": {
      "components": {
        "trustyai": {
          "managementState": "Managed"
        }
      }
    }
  }'
```

## Create gateway for kserve (optional)
```
oc apply -f ./manifests/gateway.yaml
```

## Create an Example tenant

```


export CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
export DESTINATION_CA=$(oc get configmap signing-cabundle -n openshift-service-ca -o go-template='{{ index .data "ca-bundle.crt" }}')
export DESTINATION_CA_YAML=$(printf '%s\n' "$DESTINATION_CA" | sed 's/^/      /')
export MODEL_NAMESPACE=provider-llm
export TENANT_NAME=marketing-team
export TENANT_NS="ai-tenant-${TENANT_NAME}"
export GATEWAY_NAMESPACE="openshift-ingress"
export GATEWAY_HOSTNAME="${TENANT_NAME}-maas.${CLUSTER_DOMAIN}"
export GATEWAY_ACCESS_LABEL="maas.opendatahub.io/gateway-access-${TENANT_NAME}"
export CERT_NAME="${TENANT_NAME}-gateway-tls"
export GATEWAY_SERVICE_NAME="${TENANT_NAME}-openshift-default"
export GATEWAY_OPTIONS_CONFIGMAP="${TENANT_NAME}-gateway-options"

# Model Provider Namespace (holds LLMInferenceService)
oc create namespace ${MODEL_NAMESPACE}

# Tenant Namespace (holds MaaSSubscription and MaaSModelRef)
oc create namespace ${TENANT_NS}  # This namespace is created by maas operator

cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${GATEWAY_OPTIONS_CONFIGMAP}
  namespace: ${GATEWAY_NAMESPACE}
data:
  service: |
    metadata:
      annotations:
        service.beta.openshift.io/serving-cert-secret-name: ${CERT_NAME}
    spec:
      type: ClusterIP
EOF

cat <<EOF | oc apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: ${TENANT_NAME}
  namespace: ${GATEWAY_NAMESPACE}
  annotations:
    opendatahub.io/managed: "false"
    security.opendatahub.io/authorino-tls-bootstrap: "true"
  labels:
    app.kubernetes.io/name: maas
    app.kubernetes.io/instance: ${TENANT_NAME}
    app.kubernetes.io/component: gateway
    opendatahub.io/managed: "false"
spec:
  gatewayClassName: openshift-default
  infrastructure:
    parametersRef:
      group: ""
      kind: ConfigMap
      name: ${GATEWAY_OPTIONS_CONFIGMAP}
  listeners:
    - name: https
      hostname: ${GATEWAY_HOSTNAME}
      port: 443
      protocol: HTTPS
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              ${GATEWAY_ACCESS_LABEL}: "true"
      tls:
        mode: Terminate
        certificateRefs:
          - group: ""
            kind: Secret
            name: ${CERT_NAME}
EOF

oc get gateway ${TENANT_NAME} -n ${GATEWAY_NAMESPACE}

echo "Waiting for the Gateway service TLS Secret..."
for _ in {1..60}; do
  if oc get secret "${CERT_NAME}" -n "${GATEWAY_NAMESPACE}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
if ! oc get secret "${CERT_NAME}" -n "${GATEWAY_NAMESPACE}" >/dev/null 2>&1; then
  echo "TLS Secret ${GATEWAY_NAMESPACE}/${CERT_NAME} was not created" >&2
  exit 1
fi

cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ${TENANT_NAME}-gateway
  namespace: ${GATEWAY_NAMESPACE}
  labels:
    app.kubernetes.io/name: maas
    app.kubernetes.io/instance: ${TENANT_NAME}
    gateway.networking.k8s.io/gateway-name: ${TENANT_NAME}
spec:
  host: "${GATEWAY_HOSTNAME}"
  to:
    kind: Service
    name: ${GATEWAY_SERVICE_NAME}
    weight: 100
  port:
    targetPort: https
  tls:
    termination: reencrypt
    insecureEdgeTerminationPolicy: Redirect
    destinationCACertificate: |
${DESTINATION_CA_YAML}
  wildcardPolicy: None
EOF


cat <<EOF | oc apply -f -
apiVersion: maas.opendatahub.io/v1alpha1
kind: AITenant
metadata:
  name: ${TENANT_NAME}
  namespace: ai-tenants
spec:
  gateway:
    name: ${TENANT_NAME}
  # Optional: configure an external OIDC provider for this tenant.
  # Each tenant can use a different IdP realm/client. Omit to rely on OpenShift TokenReview only.
  # oidc:
  #   issuerUrl: "https://keycloak.example.com/realms/${TENANT_NAME}"
  #   clientId: ${TENANT_NAME}-maas
  #   ttl: 300
EOF
```

* adding annotation to use praxis (In GCP, it failed to use IPP)
```
oc patch maastenantconfig default-tenant \
  -n ai-tenant-marketing-team \
  --type=merge \
  -p '{"metadata":{"annotations":{"maas.opendatahub.io/payload-processing-type":"praxis"}}}'
```

* Check 
```
oc get aitenant ${TENANT_NAME} -n ai-tenants 
oc get namespace ai-tenant-${TENANT_NAME} --show-labels
oc get maastenantconfig default-tenant -n ai-tenant-${TENANT_NAME}

INFRA_NS=$(oc get deployment -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name --no-headers | grep "maas-api-${TENANT_NAME}" | awk '{print $1}')
oc get deployment maas-api-${TENANT_NAME} -n ${INFRA_NS}
```

* The controller creates Roles but does not create RoleBindings. Grant access with standard Kubernetes RoleBindings:
```
oc create rolebinding ${TENANT_NAME}-tenant-admin \
  --role=aitenant-${TENANT_NAME}-tenant-admin \
  --group=red-team-admins \
  -n ai-tenant-${TENANT_NAME}
```

* label namespace
```
# The model namespace must carry the tenant Gateway's access label
# so the controller-generated HTTPRoute can attach.
oc label namespace "${MODEL_NAMESPACE}" "maas.opendatahub.io/gateway-access-${TENANT_NAME}=true" --overwrite
```

* Deploy model
```
oc apply -n "${MODEL_NAMESPACE}" \
  -f ./manifests/llm-inference-service-facebook-opt-125m-cpu-no-scheduler.yaml

# Attach the generated HTTPRoute to this tenant Gateway.
oc patch llminferenceservice facebook-opt-125m-single \
  -n "${MODEL_NAMESPACE}" \
  --type=merge \
  -p "{\"spec\":{\"router\":{\"gateway\":{\"refs\":[{\"name\":\"${TENANT_NAME}\",\"namespace\":\"${GATEWAY_NAMESPACE}\"}]}}}}"
```

* Create 
  - MaaSModelRef
  - MaaSAuthPolicy
  - MaaSSubscription

```
cat <<EOF | oc apply -f -
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSModelRef
metadata:
  name: facebook-opt-125m-single-ref
  namespace: $MODEL_NAMESPACE
spec:
  modelRef:
    kind: LLMInferenceService
    name: facebook-opt-125m-single
  # tenantRef: ${TENANT_NAME}  # optional — set only as an advanced override
---

# Create a MaaSAuthPolicy in the tenant namespace.
# modelRefs point to the MaaSModelRef by name and namespace.
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSAuthPolicy
metadata:
  name: facebook-opt-125m-single-model-access
  namespace: ${TENANT_NS}
spec:
  modelRefs:
    - name: facebook-opt-125m-single-ref
      namespace: ${MODEL_NAMESPACE}
  subjects:
    groups:
      - name: system:authenticated
    users: []
EOF

cat <<EOF | oc apply -f -
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSSubscription
metadata:
  name: marketing-cpu-sub
  namespace: ${TENANT_NS}
spec:
  owner:
    groups:
      - name: system:authenticated
    users: []
  modelRefs:
    - name: facebook-opt-125m-single-ref
      namespace: ${MODEL_NAMESPACE}
      tokenRateLimits:
        - limit: 1000
          window: 1m
EOF
```

## Verification

* Verify AITenants STatus
```
oc get aitenant ${TENANT_NAME} -n ai-tenants
oc get aitenant ${TENANT_NAME} -n ai-tenants -o jsonpath='{.status.conditions}' | jq .
```

* Verify Tenant Namespace
```
oc get namespace ${TENANT_NS} -o jsonpath='{.metadata.labels}' | jq .
oc get maastenantconfig default-tenant -n ${TENANT_NS} -o yaml
```

* Verify maas-api Deployment
```
INFRA_NS=$(oc get deployment -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name --no-headers | grep "maas-api-${TENANT_NAME}" | awk '{print $1}')
oc get deployment maas-api-${TENANT_NAME} -n ${INFRA_NS}
```

* Verify Gateway
```
oc get gateway ${TENANT_NAME} -n openshift-ingress
oc get route ${TENANT_NAME}-gateway -n openshift-ingress
```

* Verify Policies
```
oc get authpolicy ${TENANT_NAME}-maas-auth -n openshift-ingress
oc get tokenratelimitpolicy -n ${TENANT_NS}
```

* Test Model Listing
```
GATEWAY_HOST=$(oc get gateway ${TENANT_NAME} -n openshift-ingress -o jsonpath='{.spec.listeners[0].hostname}')
TOKEN=$(oc whoami -t)

curl -sSk "https://${GATEWAY_HOST}/maas-api/v1/models" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq .
```

* Test Authentication

Without a token (expected: 401):
```
curl -sSk -o /dev/null -w "%{http_code}\n" "https://${GATEWAY_HOST}/maas-api/v1/models"
```

With a valid API key (expected: 200):
```
SUBSCRIPTION=marketing-cpu-sub

API_KEY_RESPONSE=$(curl -sSk \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "{\"name\":\"test-key\",\"subscription\":\"${SUBSCRIPTION}\"}" \
  "https://${GATEWAY_HOST}/maas-api/v1/api-keys")

echo "${API_KEY_RESPONSE}" | jq .

API_KEY=$(echo "${API_KEY_RESPONSE}" | jq -er '.key')

curl -sSk -w "\nHTTP: %{http_code}\n" \
  -H "Authorization: Bearer ${API_KEY}" \
  "https://${GATEWAY_HOST}/maas-api/v1/models"
```

* Test Tenant Isolation

403 with default MaaS Gateway:
```
# Get default tenant gateway host
DEFAULT_HOST=$(oc get gateway maas-default-gateway -n openshift-ingress -o jsonpath='{.spec.listeners[0].hostname}')

# Try the additional tenant's API key against the default tenant (expected: 401 or 403)
curl -sSk -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Bearer ${API_KEY}" \
  "https://${DEFAULT_HOST}/maas-api/v1/models"
```

With marketing gateway:
```
curl -sSk -w "\nHTTP: %{http_code}\n" \
  -H "Authorization: Bearer ${API_KEY}" \
  "https://${GATEWAY_HOST}/maas-api/v1/models"
```



* Verify all components
```
echo "=== AITenant ==="
oc get aitenant ${TENANT_NAME} -n ai-tenants

echo "=== MaasTenantConfig CR ==="
oc get maastenantconfig default-tenant -n ${TENANT_NS}

echo "=== maas-api ==="
oc get deployment maas-api-${TENANT_NAME} -n ${INFRA_NS}

echo "=== Gateway ==="
oc get gateway ${TENANT_NAME} -n openshift-ingress

echo "=== AuthPolicies ==="
oc get authpolicy ${TENANT_NAME}-maas-auth -n openshift-ingress

echo "=== Subscriptions ==="
oc get maassubscription -n ${TENANT_NS}

echo "=== Model Refs ==="
oc get maasmodelref -n ${TENANT_NS}
```


-------------
## Cleanup PoC resources without reinstalling MaaS

Run this block from the `models-as-a-service` checkout. It removes the
marketing tenant resources created by this PoC and leaves the MaaS
installation, shared namespaces, CRDs, and operators intact.

```bash
set -euo pipefail

TENANT_NAME=marketing-team
TENANT_NS=ai-tenant-${TENANT_NAME}
MODEL_NAMESPACE=provider-llm
LEGACY_MODEL_NAMESPACE=llm
GATEWAY_NAMESPACE=openshift-ingress
CERT_NAME=${TENANT_NAME}-gateway-tls
GATEWAY_OPTIONS_CONFIGMAP=${TENANT_NAME}-gateway-options

# Remove PoC subscription, auth policy, and model references first.
oc delete maassubscription marketing-cpu-sub \
  -n "${TENANT_NS}" --ignore-not-found
oc delete maassubscription my-subscription \
  -n "${TENANT_NS}" --ignore-not-found
oc delete maasauthpolicy facebook-opt-125m-single-model-access \
  -n "${TENANT_NS}" --ignore-not-found
oc delete maasauthpolicy my-model-access \
  -n "${TENANT_NS}" --ignore-not-found
oc delete maasmodelref facebook-opt-125m-single-ref \
  -n "${MODEL_NAMESPACE}" --ignore-not-found
oc delete maasmodelref my-model \
  -n "${MODEL_NAMESPACE}" --ignore-not-found
oc delete maasmodelref my-model \
  -n "${LEGACY_MODEL_NAMESPACE}" --ignore-not-found

# Remove the model workload created by the PoC manifest.
oc delete -f ./manifests/llm-inference-service-facebook-opt-125m-cpu-no-scheduler.yaml \
  -n "${MODEL_NAMESPACE}" \
  --ignore-not-found

# Remove the PoC role binding.
oc delete rolebinding "${TENANT_NAME}-tenant-admin" \
  -n "${TENANT_NS}" --ignore-not-found

# Delete the tenant and wait for MaaS and ai-gateway-controller finalizers.
oc delete aitenant "${TENANT_NAME}" \
  -n ai-tenants --ignore-not-found --wait=true --timeout=5m

# Remove the manually-created tenant Gateway and Routes.
oc delete route "${TENANT_NAME}-gateway" \
  -n "${GATEWAY_NAMESPACE}" --ignore-not-found
oc delete gateway "${TENANT_NAME}" \
  -n "${GATEWAY_NAMESPACE}" --ignore-not-found
oc delete configmap "${GATEWAY_OPTIONS_CONFIGMAP}" \
  -n "${GATEWAY_NAMESPACE}" --ignore-not-found
oc delete secret "${CERT_NAME}" \
  -n "${GATEWAY_NAMESPACE}" --ignore-not-found
oc delete route maas-gateway-route \
  -n "${GATEWAY_NAMESPACE}" --ignore-not-found

# Remove the tenant access labels added by the PoC.
oc label namespace "${MODEL_NAMESPACE}" \
  "maas.opendatahub.io/gateway-access-${TENANT_NAME}-" || true
oc label namespace "${LEGACY_MODEL_NAMESPACE}" \
  "maas.opendatahub.io/gateway-access-${TENANT_NAME}-" || true

# Do not delete provider-llm automatically. Delete it only if it was created
# exclusively for this PoC and contains no shared workloads:
# oc delete namespace "${MODEL_NAMESPACE}"
```



## Reference
- https://github.com/opendatahub-io/models-as-a-service/blob/e2790eb2a0219412dd5a8d9d9994bc12f0234591/docs/content/install/multi-tenant-setup.md

- https://github.com/opendatahub-io/models-as-a-service/blob/e2790eb2a0219412dd5a8d9d9994bc12f0234591/docs/content/install/multi-tenant-validation.md
