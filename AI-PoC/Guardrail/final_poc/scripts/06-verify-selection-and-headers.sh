#!/usr/bin/env bash

# Verify the MaaS selection response and the rendered AuthPolicy catalog.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
LOCAL_PORT="${LOCAL_PORT:-18080}"

api_deployment="maas-api-${TENANT_NAME}"
oc get "deployment/${api_deployment}" -n "${INFRA_NAMESPACE}" >/dev/null
# Tenant API Deployments share one selector, so target the tenant pod by its instance label.
api_pod="$(oc get pod -n "${INFRA_NAMESPACE}" \
  -l "maas.opendatahub.io/tenant-instance=${api_deployment}" \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')"

oc port-forward -n "${INFRA_NAMESPACE}" "pod/${api_pod}" "${LOCAL_PORT}:8443" >/tmp/guardrail-poc-port-forward.log 2>&1 &
port_forward_pid=$!
trap 'kill "${port_forward_pid}" >/dev/null 2>&1 || true' EXIT

for _ in $(seq 1 30); do
  if curl --silent --fail --insecure https://127.0.0.1:"${LOCAL_PORT}"/health >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

response="$(curl --fail-with-body --silent --show-error --insecure \
  -H 'Content-Type: application/json' \
  -X POST "https://127.0.0.1:${LOCAL_PORT}/internal/v1/subscriptions/select" \
  --data "{\"groups\":[\"system:authenticated\"],\"username\":\"guardrail-poc\",\"requestedModel\":\"${MODEL_NAMESPACE}/${MODEL_REF_NAME}\"}")"

printf '%s\n' "${response}" | jq .
printf '%s\n' "${response}" | jq -e '
  .accessAllowed == true and
  (.selectedGuardrailChecks | type == "object") and
  (.selectedGuardrailChecks | length > 0)
' >/dev/null

header_count="$(oc get authpolicy "${TENANT_NAME}-maas-auth" -n "${GATEWAY_NAMESPACE}" -o json | \
  jq '[.spec.defaults.rules.response.success.headers? // {} | keys[] | select(startswith("x-aigateway-guardrail-"))] | length')"
if [[ "${header_count}" -lt 1 ]]; then
  echo "No rendered guardrail success header found in a Gateway AuthPolicy" >&2
  exit 1
fi

echo "Selection contains guardrail checks and ${header_count} guardrail success header(s) are rendered."
