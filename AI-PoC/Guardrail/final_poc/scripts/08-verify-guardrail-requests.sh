#!/usr/bin/env bash

# Verify that the Gateway applies the selected NeMo input guardrail to inference traffic.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

gateway_host="$(oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" \
  -o jsonpath='{.spec.listeners[0].hostname}')"
token="${TOKEN:-$(oc whoami -t)}"
served_model_name="${SERVED_MODEL_NAME:-facebook/opt-125m}"
model_alias="$(oc get maasmodelref "${MODEL_REF_NAME}" -n "${MODEL_NAMESPACE}" \
  -o jsonpath='{.status.resolvedModelAlias}')"

[[ -n "${model_alias}" ]] || {
  echo "MaaSModelRef does not have a resolved model alias: ${MODEL_NAMESPACE}/${MODEL_REF_NAME}" >&2
  exit 1
}

# The AuthPolicy uses X-Gateway-Model-Name for /v1 requests. This preserves the
# full resolved alias, whereas a multi-segment alias path cannot be reconstructed
# from the first two URL path segments used by subscription selection.
model_url="https://${gateway_host}/v1/chat/completions"

listener_ready="$(oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" -o json | jq -r '
  .status.listeners[]
  | select(.name == "https")
  | ([.conditions[] | select(.type == "Programmed") | .status][0] == "True") and
    ([.conditions[] | select(.type == "ResolvedRefs") | .status][0] == "True")
')"
if [[ "${listener_ready}" != "true" ]]; then
  echo "Gateway HTTPS listener is not ready. Resolve its TLS or reference errors before testing." >&2
  oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" -o json | jq '.status.listeners'
  exit 1
fi

accepted="$(oc get aiguardrail marketing-privacy -n "${TENANT_NAMESPACE}" \
  -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}')"
if [[ "${accepted}" != "True" ]]; then
  echo "AIGuardrail is not Accepted. Run the NeMo and AIGuardrail setup first." >&2
  oc get aiguardrail marketing-privacy -n "${TENANT_NAMESPACE}" -o yaml >&2
  exit 1
fi

response_file="$(mktemp)"
trap 'rm -f "${response_file}"' EXIT
allowed_message='Reply with one friendly word.'
forbidden_message='This message contains the forbidden word.'

request() {
  local message="$1"
  local payload

  payload="$(jq -nc --arg model "${served_model_name}" --arg message "${message}" \
    '{model: $model, messages: [{role: "user", content: $message}], max_tokens: 8, stream: false}')"
  printf 'Request body:\n%s\n' "${payload}" >&2

  curl --silent --show-error --insecure --output "${response_file}" --write-out '%{http_code}' \
    --max-time 90 \
    -H "Authorization: Bearer ${token}" \
    -H 'Content-Type: application/json' \
    -H "X-Gateway-Model-Name: ${model_alias}" \
    -X POST "${model_url}" \
    --data "${payload}"
}

echo "Sending an allowed request through ${model_url} ..."
printf 'Request message: %s\n' "${allowed_message}"
status="$(request "${allowed_message}")"
printf 'Gateway response status: HTTP %s\n' "${status}"
echo 'Response body:'
cat "${response_file}" | jq . 2>/dev/null || cat "${response_file}"
printf '\n'
if [[ "${status}" != "200" ]] || ! jq -e '.choices[0].message.content | strings | length > 0' "${response_file}" >/dev/null; then
  echo "Expected an allowed request to return a non-empty chat completion, got HTTP ${status}." >&2
  exit 1
fi

echo "Sending a forbidden request through the same Gateway path ..."
printf 'Request message: %s\n' "${forbidden_message}"
status="$(request "${forbidden_message}")"
printf 'Gateway response status: HTTP %s\n' "${status}"
echo 'Response body:'
cat "${response_file}" | jq . 2>/dev/null || cat "${response_file}"
printf '\n'
if [[ "${status}" != "403" ]]; then
  echo "Expected the input guardrail to reject the forbidden request with HTTP 403, got HTTP ${status}." >&2
  exit 1
fi

echo "Gateway guardrail verification passed: allowed input reached the model and forbidden input was rejected."
