#!/usr/bin/env bash

# Remove the resources created by the Guardrail PoC.
# The sequence mirrors creation in reverse order. Deleting AITenant lets the
# controller remove the tenant-scoped MaaS resources that it owns.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
DRY_RUN=false
PLATFORM=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --platform)
      PLATFORM=true
      ;;
    *)
      echo "usage: $0 [--dry-run] [--platform]" >&2
      exit 1
      ;;
  esac
  shift
done

delete() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] oc delete $* --ignore-not-found"
    return
  fi

  oc delete "$@" --ignore-not-found
}

wait_for_deletion() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] oc wait --for=delete $* --timeout=5m"
    return
  fi

  if oc get "$@" >/dev/null 2>&1; then
    oc wait --for=delete "$@" --timeout=5m
  fi
}

delete_namespace() {
  local namespace="$1"

  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] oc delete namespace ${namespace} --ignore-not-found"
    echo "[dry-run] oc wait --for=delete namespace/${namespace} --timeout=10m"
    return
  fi

  oc delete namespace "${namespace}" --ignore-not-found
  if oc get namespace "${namespace}" >/dev/null 2>&1; then
    oc wait --for=delete "namespace/${namespace}" --timeout=10m
  fi
}

uninstall_helm_release() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] helm uninstall ${HELM_RELEASE_NAME} -n ${HELM_NAMESPACE} --wait --timeout=15m"
    return
  fi

  if helm status "${HELM_RELEASE_NAME}" -n "${HELM_NAMESPACE}" >/dev/null 2>&1; then
    helm uninstall "${HELM_RELEASE_NAME}" -n "${HELM_NAMESPACE}" --wait --timeout=15m
  fi
}

echo "Cleaning up Guardrail PoC tenant: ${TENANT_NAME}"

# The last resources created by the PoC.
delete nemoguardrails nemo-noauth -n "$TENANT_NAMESPACE"
delete configmap nemo-noauth-config -n "$TENANT_NAMESPACE"
delete secret api-token-noauth-secret -n "$TENANT_NAMESPACE"

# The model attachment and model runtime are external to the tenant namespace.
delete maasmodelref facebook-opt-125m-single-ref -n "$MODEL_NAMESPACE"
wait_for_deletion maasmodelref facebook-opt-125m-single-ref -n "$MODEL_NAMESPACE"
delete llminferenceservice facebook-opt-125m-single -n "$MODEL_NAMESPACE"
wait_for_deletion llminferenceservice facebook-opt-125m-single -n "$MODEL_NAMESPACE"
delete configmap facebook-opt-125m-chat-template -n "$MODEL_NAMESPACE"

# The controller cleans MaasTenantConfig, MaaSSubscription, MaaSAuthPolicy,
# maas-api, and other resources it owns for this tenant.
delete aitenant "$TENANT_NAME" -n ai-tenants
wait_for_deletion aitenant "$TENANT_NAME" -n ai-tenants

# This Gateway was created directly by the PoC, before the AITenant.
delete gateway "$TENANT_NAME" -n "$GATEWAY_NAMESPACE"
wait_for_deletion gateway "$TENANT_NAME" -n "$GATEWAY_NAMESPACE"

# The PoC created this namespace. The provider namespace is deliberately kept
# because it can contain shared KServe artifacts outside this PoC.
delete namespace "$TENANT_NAMESPACE"
wait_for_deletion namespace "$TENANT_NAMESPACE"

if [[ "$PLATFORM" == true ]]; then
  echo "Cleaning up the dedicated PoC platform installation"

  # The ODH operator must remain running while it removes MaaS, AI Gateway,
  # KServe, and their dependent resources.
  delete datasciencecluster default-dsc -n "$ODH_NAMESPACE"
  wait_for_deletion datasciencecluster default-dsc -n "$ODH_NAMESPACE"
  delete dscinitialization default-dsci -n "$ODH_NAMESPACE"
  wait_for_deletion dscinitialization default-dsci -n "$ODH_NAMESPACE"

  # The Helm release owns the OLM Subscription and installation resources.
  uninstall_helm_release

  # Config/default is created by the MaaS installation and can remain after a
  # failed or interrupted reconciliation. It is safe to remove only in the
  # explicit platform cleanup mode.
  delete config.maas.opendatahub.io default
  wait_for_deletion config.maas.opendatahub.io default

  # This CatalogSource is created only when deploy.sh receives --operator-catalog.
  delete catalogsource "$CUSTOM_CATALOG_NAME" -n "$CUSTOM_CATALOG_NAMESPACE"
  wait_for_deletion catalogsource "$CUSTOM_CATALOG_NAME" -n "$CUSTOM_CATALOG_NAMESPACE"

  # These namespaces are created exclusively by the disposable PoC platform.
  # ODH cleanup above must finish before deleting its operator namespace.
  delete_namespace "$INFRA_NAMESPACE"
  delete_namespace "$ODH_NAMESPACE"
  delete_namespace "$ODH_OPERATOR_NAMESPACE"
  delete_namespace "$HELM_NAMESPACE"
fi

echo "Guardrail PoC cleanup complete."
