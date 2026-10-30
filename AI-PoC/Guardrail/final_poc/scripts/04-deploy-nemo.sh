#!/usr/bin/env bash

# Deploy a NeMo Guardrails provider that calls the demo model through its tenant Gateway.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
GATEWAY_HOST="${GATEWAY_HOST:-$(oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" -o jsonpath='{.spec.listeners[0].hostname}')}"
MODEL_BASE_URL="${MODEL_BASE_URL:-https://${GATEWAY_HOST}/v1}"
MODEL_NAME="${MODEL_NAME:-facebook/opt-125m}"
: "${NEMO_OPENAI_API_KEY:?set NEMO_OPENAI_API_KEY to a token that can call the demo model}"

oc create secret generic api-token-secret -n "${TENANT_NAMESPACE}" \
  --from-literal=token="${NEMO_OPENAI_API_KEY}" \
  --dry-run=client -o yaml | oc apply -f -
export TENANT_NAMESPACE MODEL_BASE_URL MODEL_NAME
envsubst '${TENANT_NAMESPACE} ${MODEL_BASE_URL} ${MODEL_NAME}' \
  < "${POC_DIR}/manifests/nemo.yaml.tmpl" | oc apply -f -

for _ in $(seq 1 90); do
  endpoint="$(oc get nemoguardrails nemo-guardrails -n "${TENANT_NAMESPACE}" -o jsonpath='{.status.endpoint}')"
  if [[ -n "${endpoint}" ]]; then
    echo "NeMo Guardrails provider published an endpoint: ${endpoint}"
    exit 0
  fi
  sleep 2
done

oc get nemoguardrails nemo-guardrails -n "${TENANT_NAMESPACE}" -o yaml >&2
echo "NeMo Guardrails provider did not publish an endpoint" >&2
exit 1
