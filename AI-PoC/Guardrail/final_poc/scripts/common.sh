#!/usr/bin/env bash

# Shared defaults for the Guardrail PoC. Export different values before running
# a script when testing another cluster, tenant, registry user, or image tag.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${POC_DIR}/../../../.." && pwd)"
POC_SOURCES_DIR="${POC_SOURCES_DIR:-/tmp/aiguardrail_poc}"

MAAS_REPO_PATH="${MAAS_REPO_PATH:-${POC_SOURCES_DIR}/models-as-a-service}"
TRUSTYAI_SERVICE_OPERATOR_REPO_PATH="${TRUSTYAI_SERVICE_OPERATOR_REPO_PATH:-${POC_SOURCES_DIR}/trustyai-service-operator}"
PRAXIS_AI_REPO_PATH="${PRAXIS_AI_REPO_PATH:-${POC_SOURCES_DIR}/praxis-ai}"
PRAXIS_EXTPROC_REPO_PATH="${PRAXIS_EXTPROC_REPO_PATH:-${POC_SOURCES_DIR}/praxis-extproc}"
AI_GATEWAY_REPO_PATH="${AI_GATEWAY_REPO_PATH:-${POC_SOURCES_DIR}/ai-gateway-controller}"
AI_GATEWAY_OPERATOR_REPO_PATH="${AI_GATEWAY_OPERATOR_REPO_PATH:-${POC_SOURCES_DIR}/ai-gateway-operator}"
ODH_OPERATOR_REPO_PATH="${ODH_OPERATOR_REPO_PATH:-${POC_SOURCES_DIR}/opendatahub-operator}"

ODH_NAMESPACE="${ODH_NAMESPACE:-opendatahub}"
INFRA_NAMESPACE="${INFRA_NAMESPACE:-odh-ai-gateway-infra}"
GATEWAY_NAMESPACE="${GATEWAY_NAMESPACE:-openshift-ingress}"
ODH_OPERATOR_NAMESPACE="${ODH_OPERATOR_NAMESPACE:-opendatahub-operator-system}"
HELM_RELEASE_NAME="${HELM_RELEASE_NAME:-rhoai-deps}"
HELM_NAMESPACE="${HELM_NAMESPACE:-rhoai-deps}"
CUSTOM_CATALOG_NAME="${CUSTOM_CATALOG_NAME:-odh-custom-catalog}"
CUSTOM_CATALOG_NAMESPACE="${CUSTOM_CATALOG_NAMESPACE:-openshift-marketplace}"

TENANT_NAME="${TENANT_NAME:-marketing-team}"
TENANT_NAMESPACE="${TENANT_NAMESPACE:-ai-tenant-${TENANT_NAME}}"
MODEL_NAMESPACE="${MODEL_NAMESPACE:-provider-llm}"
MODEL_REF_NAME="${MODEL_REF_NAME:-facebook-opt-125m-single-ref}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-facebook/opt-125m}"
GATEWAY_MAX_TOKENS="${GATEWAY_MAX_TOKENS:-16}"

# The no-auth provider is used for the initial PoC data-path test. Keep the
# authenticated provider available for the later HTTPS validation phase.
NEMO_PROVIDER_NAME="${NEMO_PROVIDER_NAME:-nemo-noauth}"
NEMO_CONFIG_ID="${NEMO_CONFIG_ID:-marketing-rails}"

QUAY_USER="${QUAY_USER:-jooholee}"
IMAGE_TAG="${IMAGE_TAG:-guardrail-poc}"
MAAS_API_IMAGE="${MAAS_API_IMAGE:-quay.io/${QUAY_USER}/maas-api:${IMAGE_TAG}}"
MAAS_CONTROLLER_IMAGE="${MAAS_CONTROLLER_IMAGE:-quay.io/${QUAY_USER}/maas-controller:${IMAGE_TAG}}"
AI_GATEWAY_CONTROLLER_IMAGE="${AI_GATEWAY_CONTROLLER_IMAGE:-quay.io/${QUAY_USER}/ai-gateway-controller:${IMAGE_TAG}}"
AI_GATEWAY_OPERATOR_IMAGE="${AI_GATEWAY_OPERATOR_IMAGE:-quay.io/${QUAY_USER}/odh-ai-gateway-operator:${IMAGE_TAG}}"
PRAXIS_EXTPROC_IMAGE="${PRAXIS_EXTPROC_IMAGE:-quay.io/${QUAY_USER}/odh-praxis-extproc:${IMAGE_TAG}}"
PRAXIS_AI_IMAGE="${PRAXIS_AI_IMAGE:-quay.io/${QUAY_USER}/praxis-ai:${IMAGE_TAG}}"
TRUSTYAI_SERVICE_OPERATOR_IMAGE="${TRUSTYAI_SERVICE_OPERATOR_IMAGE:-quay.io/${QUAY_USER}/trustyai-service-operator:${IMAGE_TAG}}"
TRUSTYAI_MODULE_OPERATOR_IMAGE="${TRUSTYAI_MODULE_OPERATOR_IMAGE:-quay.io/${QUAY_USER}/trustyai-module-operator:${IMAGE_TAG}}"
ODH_OPERATOR_VERSION="${ODH_OPERATOR_VERSION:-3.6.0}"
ODH_OPERATOR_IMAGE="${ODH_OPERATOR_IMAGE:-quay.io/${QUAY_USER}/opendatahub-operator:${IMAGE_TAG}}"
ODH_OPERATOR_BUNDLE_IMAGE="${ODH_OPERATOR_BUNDLE_IMAGE:-quay.io/${QUAY_USER}/opendatahub-operator-bundle:v${ODH_OPERATOR_VERSION}}"
ODH_OPERATOR_CATALOG_IMAGE="${ODH_OPERATOR_CATALOG_IMAGE:-quay.io/${QUAY_USER}/opendatahub-operator-index:${IMAGE_TAG}}"

# Empty selects the checked-out AI Gateway Operator commit when the custom ODH
# catalog is built. Set this only to a published commit that manifest-tools can fetch.
AI_GATEWAY_OPERATOR_MANIFEST_REF="${AI_GATEWAY_OPERATOR_MANIFEST_REF:-}"

# Select the subscription applicable to a user/group and model through the
# maas-api internal endpoint. A local port-forward to 18080 is required.
select_subscription() {
  local group="${1:-system:authenticated}"
  local requested_model="${2:-${MODEL_NAMESPACE}/${MODEL_REF_NAME}}"
  local username="${3:-guardrail-poc}"

  curl --fail-with-body --silent --show-error --insecure \
    -H 'Content-Type: application/json' \
    -X POST https://127.0.0.1:18080/internal/v1/subscriptions/select \
    --data "{\"groups\":[\"${group}\"],\"username\":\"${username}\",\"requestedModel\":\"${requested_model}\"}" \
    | jq .
}

# Send a Chat Completions request through the tenant Gateway and print the
# complete response. Arguments are: stream boolean, user message, optional max tokens.
gateway_chat_request() {
  local stream="$1"
  local message="$2"
  local max_tokens="${3:-${GATEWAY_MAX_TOKENS}}"
  local gateway_host model_alias token response_file http_status payload

  gateway_host="${GATEWAY_HOST:-$(oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" -o jsonpath='{.spec.listeners[0].hostname}')}"
  model_alias="${MODEL_ALIAS:-$(oc get maasmodelref "${MODEL_REF_NAME}" -n "${MODEL_NAMESPACE}" -o jsonpath='{.status.resolvedModelAlias}')}"
  token="${TOKEN:-$(oc whoami -t)}"

  [[ -n "${gateway_host}" && -n "${model_alias}" ]] || {
    echo "Gateway hostname or MaaSModelRef alias is empty" >&2
    return 1
  }

  response_file="$(mktemp)"
  payload="$(jq -nc \
    --arg model "${SERVED_MODEL_NAME}" \
    --arg message "${message}" \
    --argjson stream "${stream}" \
    --argjson max_tokens "${max_tokens}" \
    '{model: $model, messages: [{role: "user", content: $message}], max_tokens: $max_tokens, temperature: 0, stream: $stream}')"

  echo "Request body: ${payload}"
  http_status="$(curl --silent --show-error --insecure --output "${response_file}" \
    --write-out '%{http_code}' --max-time 90 \
    -H "Authorization: Bearer ${token}" \
    -H 'Content-Type: application/json' \
    -H "X-Gateway-Model-Name: ${model_alias}" \
    -X POST "https://${gateway_host}/v1/chat/completions" \
    --data "${payload}")"
  echo "Gateway response status: HTTP ${http_status}"
  echo "Response body:"
  cat "${response_file}" | jq . 2>/dev/null || cat "${response_file}"
  rm -f "${response_file}"
}
