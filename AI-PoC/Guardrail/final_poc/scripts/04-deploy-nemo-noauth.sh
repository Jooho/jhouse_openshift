#!/usr/bin/env bash

# Deploy the no-auth NeMo provider used by the initial PoC data-path test.
# The authenticated nemo-guardrails provider is kept for the later HTTPS phase.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
GATEWAY_HOST="${GATEWAY_HOST:-$(oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" -o jsonpath='{.spec.listeners[0].hostname}')}"
MODEL_BASE_URL="${MODEL_BASE_URL:-https://${GATEWAY_HOST}/v1}"
MODEL_NAME="${MODEL_NAME:-facebook/opt-125m}"
: "${NEMO_OPENAI_API_KEY:?set NEMO_OPENAI_API_KEY to a token that can call the demo model}"

oc create secret generic api-token-noauth-secret -n "${TENANT_NAMESPACE}" \
  --from-literal=token="${NEMO_OPENAI_API_KEY}" \
  --dry-run=client -o yaml | oc apply -f -

export TENANT_NAMESPACE MODEL_BASE_URL MODEL_NAME NEMO_CONFIG_ID

envsubst '${TENANT_NAMESPACE} ${MODEL_BASE_URL} ${MODEL_NAME} ${NEMO_CONFIG_ID}' \
  < "${POC_DIR}/manifests/nemo-noauth.yaml.tmpl" | oc apply -f -

for _ in $(seq 1 90); do
  workload_namespace="$(oc get nemoguardrails nemo-noauth -n "${TENANT_NAMESPACE}" \
    -o jsonpath='{.status.workloadNamespace}' 2>/dev/null || true)"
  if [[ -n "${workload_namespace}" ]]; then
    echo "No-auth NeMo provider is ready."
    echo "  CR: ${TENANT_NAMESPACE}/nemo-noauth"
    echo "  Service: nemo-noauth.${workload_namespace}.svc.cluster.local:80"
    echo "  status.endpoint is intentionally empty because auth is disabled."
    exit 0
  fi
  sleep 2
done

oc get nemoguardrails nemo-noauth -n "${TENANT_NAMESPACE}" -o yaml >&2
echo "No-auth NeMo provider did not publish status.workloadNamespace" >&2
exit 1
