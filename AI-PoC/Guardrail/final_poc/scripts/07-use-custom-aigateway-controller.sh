#!/usr/bin/env bash

# Configure custom AI Gateway, TrustyAI, and Praxis images through ODH OLM config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

ODH_SUBSCRIPTION_NAME="${ODH_SUBSCRIPTION_NAME:-opendatahub-operator}"
ODH_OPERATOR_DEPLOYMENT="${ODH_OPERATOR_DEPLOYMENT:-opendatahub-operator-controller-manager}"
TIMEOUT_SECONDS="${CUSTOM_IMAGE_TIMEOUT_SECONDS:-600}"

wait_for_deployment_image() {
  local namespace="$1"
  local deployment="$2"
  local expected_image="$3"
  local deadline=$((SECONDS + TIMEOUT_SECONDS))

  while [[ ${SECONDS} -lt ${deadline} ]]; do
    local image
    image="$(oc get deployment "${deployment}" -n "${namespace}" \
      -o jsonpath='{.spec.template.spec.containers[?(@.name=="manager")].image}' 2>/dev/null || true)"
    if [[ "${image}" == "${expected_image}" ]]; then
      oc rollout status "deployment/${deployment}" -n "${namespace}" --timeout=120s
      return 0
    fi
    echo "Waiting for ${namespace}/${deployment} image=${image:-<not-found>}"
    sleep 5
  done

  echo "Timed out waiting for ${namespace}/${deployment} to use ${expected_image}" >&2
  return 1
}

wait_for_deployment_env() {
  local namespace="$1"
  local deployment="$2"
  local name="$3"
  local expected_value="$4"
  local deadline=$((SECONDS + TIMEOUT_SECONDS))

  while [[ ${SECONDS} -lt ${deadline} ]]; do
    local value
    value="$(oc get deployment "${deployment}" -n "${namespace}" -o json | \
      jq -r --arg name "${name}" \
        '.spec.template.spec.containers[] | select(.name == "manager") | .env[]? | select(.name == $name) | .value' \
      | head -1)"
    if [[ "${value}" == "${expected_value}" ]]; then
      return 0
    fi
    echo "Waiting for ${namespace}/${deployment} ${name}=${value:-<not-set>}"
    sleep 5
  done

  echo "Timed out waiting for ${namespace}/${deployment} to receive ${name}=${expected_value}" >&2
  return 1
}

wait_for_praxis() {
  local deadline=$((SECONDS + TIMEOUT_SECONDS))

  while [[ ${SECONDS} -lt ${deadline} ]]; do
    local post_image pre_image post_ready pre_ready
    post_image="$(oc get deployment payload-processing -n "${GATEWAY_NAMESPACE}" \
      -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
    pre_image="$(oc get deployment payload-pre-processing -n "${GATEWAY_NAMESPACE}" \
      -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
    post_ready="$(oc get deployment payload-processing -n "${GATEWAY_NAMESPACE}" \
      -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"
    pre_ready="$(oc get deployment payload-pre-processing -n "${GATEWAY_NAMESPACE}" \
      -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)"

    if [[ "${post_image}" == "${PRAXIS_EXTPROC_IMAGE}" ]] \
      && [[ "${pre_image}" == "${PRAXIS_EXTPROC_IMAGE}" ]] \
      && [[ "${post_ready:-0}" -ge 1 ]] \
      && [[ "${pre_ready:-0}" -ge 1 ]]; then
      return 0
    fi
    echo "Waiting for Praxis images: payload-processing=${post_image:-<not-found>} ready=${post_ready:-0}; payload-pre-processing=${pre_image:-<not-found>} ready=${pre_ready:-0}"
    sleep 5
  done

  echo "Timed out waiting for Praxis ext-proc deployments to use ${PRAXIS_EXTPROC_IMAGE}" >&2
  return 1
}

subscription_env="$(oc get subscription "${ODH_SUBSCRIPTION_NAME}" -n "${ODH_OPERATOR_NAMESPACE}" -o json | \
  jq -c \
    --arg controller_image "${AI_GATEWAY_CONTROLLER_IMAGE}" \
    --arg praxis_image "${PRAXIS_EXTPROC_IMAGE}" \
    --arg trustyai_module_image "${TRUSTYAI_MODULE_OPERATOR_IMAGE}" \
    --arg trustyai_service_image "${TRUSTYAI_SERVICE_OPERATOR_IMAGE}" '
      (.spec.config.env // [])
      | map(select(
          .name != "RELATED_IMAGE_ODH_AI_GATEWAY_CONTROLLER_IMAGE" and
          .name != "RELATED_IMAGE_ODH_PRAXIS_EXTPROC_IMAGE" and
          .name != "RELATED_IMAGE_ODH_TRUSTYAI_MODULE_OPERATOR_IMAGE" and
          .name != "RELATED_IMAGE_ODH_TRUSTYAI_SERVICE_OPERATOR_IMAGE"
        ))
      + [
          {name: "RELATED_IMAGE_ODH_AI_GATEWAY_CONTROLLER_IMAGE", value: $controller_image},
          {name: "RELATED_IMAGE_ODH_PRAXIS_EXTPROC_IMAGE", value: $praxis_image},
          {name: "RELATED_IMAGE_ODH_TRUSTYAI_MODULE_OPERATOR_IMAGE", value: $trustyai_module_image},
          {name: "RELATED_IMAGE_ODH_TRUSTYAI_SERVICE_OPERATOR_IMAGE", value: $trustyai_service_image}
        ]
    ')"

patch="$(jq -cn --argjson env "${subscription_env}" '{spec: {config: {env: $env}}}')"
oc patch subscription "${ODH_SUBSCRIPTION_NAME}" -n "${ODH_OPERATOR_NAMESPACE}" \
  --type=merge -p "${patch}"

echo "Waiting for ODH Operator to receive the image overrides..."
oc rollout status "deployment/${ODH_OPERATOR_DEPLOYMENT}" -n "${ODH_OPERATOR_NAMESPACE}" --timeout=180s

wait_for_deployment_env "${ODH_OPERATOR_NAMESPACE}" "${ODH_OPERATOR_DEPLOYMENT}" \
  "RELATED_IMAGE_ODH_AI_GATEWAY_CONTROLLER_IMAGE" "${AI_GATEWAY_CONTROLLER_IMAGE}"
wait_for_deployment_env "${ODH_OPERATOR_NAMESPACE}" "${ODH_OPERATOR_DEPLOYMENT}" \
  "RELATED_IMAGE_ODH_PRAXIS_EXTPROC_IMAGE" "${PRAXIS_EXTPROC_IMAGE}"
wait_for_deployment_env "${ODH_OPERATOR_NAMESPACE}" "${ODH_OPERATOR_DEPLOYMENT}" \
  "RELATED_IMAGE_ODH_TRUSTYAI_MODULE_OPERATOR_IMAGE" "${TRUSTYAI_MODULE_OPERATOR_IMAGE}"
wait_for_deployment_env "${ODH_OPERATOR_NAMESPACE}" "${ODH_OPERATOR_DEPLOYMENT}" \
  "RELATED_IMAGE_ODH_TRUSTYAI_SERVICE_OPERATOR_IMAGE" "${TRUSTYAI_SERVICE_OPERATOR_IMAGE}"
wait_for_deployment_image "${ODH_NAMESPACE}" "ai-gateway-operator" "${AI_GATEWAY_OPERATOR_IMAGE}"
wait_for_deployment_env "${ODH_NAMESPACE}" "ai-gateway-operator" \
  "RELATED_IMAGE_ODH_AI_GATEWAY_CONTROLLER_IMAGE" "${AI_GATEWAY_CONTROLLER_IMAGE}"
wait_for_deployment_env "${ODH_NAMESPACE}" "ai-gateway-operator" \
  "RELATED_IMAGE_ODH_PRAXIS_EXTPROC_IMAGE" "${PRAXIS_EXTPROC_IMAGE}"
wait_for_deployment_image "${ODH_NAMESPACE}" "ai-gateway-controller" "${AI_GATEWAY_CONTROLLER_IMAGE}"
wait_for_deployment_image "${ODH_NAMESPACE}" "trustyai-operator-module-controller-manager" "${TRUSTYAI_MODULE_OPERATOR_IMAGE}"
wait_for_deployment_image "${ODH_NAMESPACE}" "trustyai-service-operator-controller-manager" "${TRUSTYAI_SERVICE_OPERATOR_IMAGE}"
wait_for_praxis

echo "Custom AI Gateway Controller, TrustyAI operators, and Praxis ext-proc images are ready."
