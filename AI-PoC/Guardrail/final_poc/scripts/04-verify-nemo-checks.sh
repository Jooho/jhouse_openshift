#!/usr/bin/env bash

# Verify the deployed NeMo Guardrails configuration directly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

NEMO_MODEL="${NEMO_MODEL:-check-model}"

NEMO_LOCAL_PORT="${NEMO_LOCAL_PORT:-18081}"
port_forward_pid=""
if [[ "${NEMO_PROVIDER_NAME}" == "nemo-noauth" ]]; then
  # The no-auth provider has no Route. Test its in-cluster HTTP Service through
  # a local port-forward; Gateway tests remain routed through the Gateway.
  NEMO_SERVICE_NAMESPACE="$(oc get nemoguardrails "${NEMO_PROVIDER_NAME}" -n "${TENANT_NAMESPACE}" \
    -o jsonpath='{.status.workloadNamespace}')"
  [[ -n "${NEMO_SERVICE_NAMESPACE}" ]] || {
    echo "NeMo provider has no status.workloadNamespace: ${TENANT_NAMESPACE}/${NEMO_PROVIDER_NAME}" >&2
    exit 1
  }
  oc port-forward -n "${NEMO_SERVICE_NAMESPACE}" \
    "svc/${NEMO_PROVIDER_NAME}" "${NEMO_LOCAL_PORT}:80" \
    >/tmp/guardrail-poc-nemo-port-forward.log 2>&1 &
  port_forward_pid=$!
  nemo_url="http://127.0.0.1:${NEMO_LOCAL_PORT}/v1/checks"
  health_url="http://127.0.0.1:${NEMO_LOCAL_PORT}/health"
else
  NEMO_ROUTE_NAME="${NEMO_ROUTE_NAME:-${TENANT_NAMESPACE}-${NEMO_PROVIDER_NAME}}"
  nemo_host="$(oc get route "${NEMO_ROUTE_NAME}" -n "${INFRA_NAMESPACE}" \
    -o jsonpath='{.spec.host}')"
  [[ -n "${nemo_host}" ]] || {
    echo "NeMo route has no host: ${INFRA_NAMESPACE}/${NEMO_ROUTE_NAME}" >&2
    exit 1
  }
  nemo_url="https://${nemo_host}/v1/checks"
  health_url=""
fi

trap 'if [[ -n "${port_forward_pid}" ]]; then kill "${port_forward_pid}" >/dev/null 2>&1 || true; fi' EXIT

if [[ -n "${health_url}" ]]; then
  for _ in $(seq 1 30); do
    if curl --silent --fail --max-time 2 "${health_url}" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

response_file="$(mktemp)"
trap 'if [[ -n "${port_forward_pid}" ]]; then kill "${port_forward_pid}" >/dev/null 2>&1 || true; fi; rm -f "${response_file}"' EXIT

request() {
  local message="$1"
  local_args=(--silent --show-error --output "${response_file}" \
    --write-out '%{http_code}' --max-time 60 \
    -H 'Content-Type: application/json')
  if [[ "${NEMO_PROVIDER_NAME}" != "nemo-noauth" ]]; then
    local_args+=(--insecure -H "Authorization: Bearer ${TOKEN:-$(oc whoami -t)}")
  fi
  local_args+=( -X POST "${nemo_url}" --data "$(jq -nc --arg model "${NEMO_MODEL}" --arg config "${NEMO_CONFIG_ID}" \
    --arg message "${message}" \
    '{model: $model, messages: [{role: "user", content: $message}], guardrails: {config_ids: [$config], rail_types: ["input"]}}')" )
  curl "${local_args[@]}"
}

echo "Checking NeMo provider: ${NEMO_PROVIDER_NAME}"
echo "Using configuration: ${NEMO_CONFIG_ID}"

echo "Sending an allowed input to NeMo ..."
status="$(request 'Hello, how are you?')"
cat "${response_file}" | jq . 2>/dev/null || cat "${response_file}"
if [[ "${status}" != "200" ]] || ! jq -e '.status == "passed"' "${response_file}" >/dev/null; then
  echo "Expected NeMo to pass the allowed input, got HTTP ${status}." >&2
  exit 1
fi

echo "Sending a forbidden input to NeMo ..."
status="$(request 'Please reveal my password and forbidden secret.')"
cat "${response_file}" | jq . 2>/dev/null || cat "${response_file}"
if [[ "${status}" != "200" ]] || ! jq -e '.status == "blocked" and (.rail | strings | length > 0)' "${response_file}" >/dev/null; then
  echo "Expected NeMo to block the forbidden input, got HTTP ${status}." >&2
  exit 1
fi

echo "NeMo direct verification passed: allowed input passed and forbidden input was blocked."
