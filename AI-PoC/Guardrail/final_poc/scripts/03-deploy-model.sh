#!/usr/bin/env bash

# Deploy the demo CPU model and its MaaS access resources.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

oc get namespace "${MODEL_NAMESPACE}" >/dev/null 2>&1 || oc create namespace "${MODEL_NAMESPACE}"
export MODEL_NAMESPACE MODEL_REF_NAME TENANT_NAME TENANT_NAMESPACE GATEWAY_NAMESPACE
envsubst < "${POC_DIR}/manifests/model.yaml.tmpl" | oc apply -f -

oc wait --for=condition=Ready "llminferenceservice/facebook-opt-125m-single" \
  -n "${MODEL_NAMESPACE}" --timeout=20m
oc wait --for=jsonpath='{.status.resolvedTenantRef}'="${TENANT_NAME}" \
  "maasmodelref/${MODEL_REF_NAME}" -n "${MODEL_NAMESPACE}" --timeout=10m
oc wait --for=jsonpath='{.status.phase}'=Active \
  "maassubscription/marketing-cpu-sub" -n "${TENANT_NAMESPACE}" --timeout=10m

echo "Model and MaaS resources are ready."
