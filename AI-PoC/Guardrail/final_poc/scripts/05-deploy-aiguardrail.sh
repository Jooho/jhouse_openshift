#!/usr/bin/env bash

# Attach one accepted AIGuardrail check to the demo subscription.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
export TENANT_NAMESPACE MODEL_NAMESPACE

envsubst < "${POC_DIR}/manifests/aiguardrail.yaml.tmpl" | oc apply -f -
oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" --type=merge \
  -p '{"spec":{"guardrails":[{"ref":{"name":"marketing-privacy"},"checks":["privacy"]}]}}'

for _ in $(seq 1 90); do
  accepted="$(oc get aiguardrail marketing-privacy -n "${TENANT_NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}')"
  if [[ "${accepted}" == "True" ]]; then
    echo "AIGuardrail is Accepted."
    exit 0
  fi
  sleep 2
done

oc get aiguardrail marketing-privacy -n "${TENANT_NAMESPACE}" -o yaml >&2
echo "AIGuardrail did not become Accepted" >&2
exit 1
