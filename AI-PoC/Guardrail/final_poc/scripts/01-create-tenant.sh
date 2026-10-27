#!/usr/bin/env bash

# Create the demo Gateway and AITenant through the MaaS supported tenant flow.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

[[ -x "${MAAS_REPO_PATH}/scripts/create-ai-tenant.sh" ]] || {
  echo "MaaS tenant script not found: ${MAAS_REPO_PATH}/scripts/create-ai-tenant.sh" >&2
  exit 1
}

oc get namespace "${MODEL_NAMESPACE}" >/dev/null 2>&1 || oc create namespace "${MODEL_NAMESPACE}"

ALLOWED_ROUTE_NAMESPACES="opendatahub,${INFRA_NAMESPACE},${MODEL_NAMESPACE}" \
  "${MAAS_REPO_PATH}/scripts/create-ai-tenant.sh" "${TENANT_NAME}"

gateway_tls_secret="$(oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" \
  -o jsonpath='{.spec.listeners[0].tls.certificateRefs[0].name}')"

if ! oc get secret "${gateway_tls_secret}" -n "${GATEWAY_NAMESPACE}" >/dev/null 2>&1; then
  router_tls_secret="$(oc get deployment router-default -n "${GATEWAY_NAMESPACE}" \
    -o jsonpath='{.spec.template.spec.volumes[?(@.name=="default-certificate")].secret.secretName}')"
  [[ -n "${router_tls_secret}" ]] || {
    echo "Tenant Gateway references missing TLS Secret ${gateway_tls_secret}, and the default Router certificate could not be detected" >&2
    exit 1
  }
  oc get secret "${router_tls_secret}" -n "${GATEWAY_NAMESPACE}" >/dev/null || {
    echo "Default Router TLS Secret does not exist: ${GATEWAY_NAMESPACE}/${router_tls_secret}" >&2
    exit 1
  }

  echo "Replacing missing Gateway TLS Secret ${gateway_tls_secret} with Router TLS Secret ${router_tls_secret}"
  oc patch gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" --type=json -p "[
    {\"op\":\"replace\",\"path\":\"/spec/listeners/0/tls/certificateRefs/0/name\",\"value\":\"${router_tls_secret}\"}
  ]"
fi

listener_ready=false
for _ in $(seq 1 60); do
  if oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" -o json | jq -e '
    .status.listeners[]
    | select(.name == "https")
    | ([.conditions[] | select(.type == "Programmed") | .status][0] == "True") and
      ([.conditions[] | select(.type == "ResolvedRefs") | .status][0] == "True")
  ' >/dev/null; then
    listener_ready=true
    break
  fi
  sleep 2
done

if [[ "${listener_ready}" != true ]]; then
  echo "Tenant Gateway HTTPS listener did not become ready" >&2
  oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" -o json | jq '.status.listeners' >&2
  exit 1
fi

oc wait --for=jsonpath='{.status.tenantNamespace}'="${TENANT_NAMESPACE}" \
  "aitenant/${TENANT_NAME}" -n ai-tenants --timeout=10m

api_deployment="maas-api-${TENANT_NAME}"
for _ in $(seq 1 120); do
  if oc get "deployment/${api_deployment}" -n "${INFRA_NAMESPACE}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
oc get "deployment/${api_deployment}" -n "${INFRA_NAMESPACE}" >/dev/null || {
  echo "MaaS API deployment was not created: ${INFRA_NAMESPACE}/${api_deployment}" >&2
  exit 1
}
oc wait --for=condition=Available "deployment/${api_deployment}" -n "${INFRA_NAMESPACE}" --timeout=10m

echo "Demo tenant is ready: ${TENANT_NAME} (${TENANT_NAMESPACE})"
