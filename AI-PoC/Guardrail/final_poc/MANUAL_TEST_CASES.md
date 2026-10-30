# Guardrail manual test cases

This document contains hands-on checks for the Guardrail PoC. Each case records the change, what to inspect, the expected result, and how to return to the baseline so it can later become E2E coverage. The NeMo input rail used here blocks input containing `forbidden`, case-insensitively.

## Prerequisites

Start after the base PoC deployment, tenant, NeMo provider, AIGuardrail, and subscription exist.

```bash
cd /home/jlee/temp/20260924_guardrail/jhouse_openshift/AI-PoC/Guardrail/final_poc
source ./scripts/common.sh
export TOKEN="$(oc whoami -t)"

./scripts/04-deploy-nemo-noauth.sh
./scripts/05-deploy-aiguardrail.sh
```

Open a temporary port-forward for direct selection API requests in a separate terminal. Stop it with `Ctrl-C` when testing is complete.

```bash
api_deployment="maas-api-${TENANT_NAME}"
api_pod="$(oc get pod -n "${INFRA_NAMESPACE}" \
  -l "maas.opendatahub.io/tenant-instance=${api_deployment}" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')"

oc port-forward -n "${INFRA_NAMESPACE}" "pod/${api_pod}" 18080:8443
```

`common.sh` provides `select_subscription`, which calls the local selection API. It accepts an optional group, requested-model value, and username.

```bash
# Return every mutation case to the one-check demo baseline. Run this before
# starting a mutation case and again after it finishes, even when a command in
# the middle of the case fails.
reset_baseline() {
  oc patch aitenant "${TENANT_NAME}" -n ai-tenants --type=merge \
    -p '{"spec":{"guardrails":null}}'
  oc patch maastenantconfig default-tenant -n "${TENANT_NAMESPACE}" --type=merge \
    -p '{"spec":{"guardrails":null}}'
  oc patch maasmodelref "${MODEL_REF_NAME}" -n "${MODEL_NAMESPACE}" --type=merge \
    -p '{"spec":{"guardrails":null}}'
  oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" --type=json \
    -p='[{"op":"remove","path":"/spec/modelRefs/0/guardrails"}]' 2>/dev/null || true
  oc delete aiguardrail marketing-privacy -n "${MODEL_NAMESPACE}" \
    --ignore-not-found
  oc delete maassubscription marketing-safety-sub -n "${TENANT_NAMESPACE}" \
    --ignore-not-found
  ./scripts/05-deploy-aiguardrail.sh
  sleep 10
}
```

## Baseline: working guardrail path

Confirm the known-good state before running mutation cases. Run `reset_baseline` before and after every mutation case. It restores the single `privacy` check policy and removes extra scope attachments and the second subscription created by these tests.

```bash
./scripts/08-verify-guardrail-requests.sh
```

Expected result:

- Allowed input reaches the model with HTTP `200`.
- Input containing `forbidden` is rejected by the NeMo input rail with HTTP `403`.

Use the following command only when a control-plane snapshot is needed.

```bash
./scripts/06-verify-selection-and-headers.sh
```

## MT-01: remove the subscription attachment

Remove the subscription attachment and confirm that both selection and the rendered catalog become guardrail-free.

```bash
reset_baseline

oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" \
  --type=json \
  -p='[{"op":"remove","path":"/spec/guardrails"}]'

sleep 10
select_subscription

oc get authpolicy "${TENANT_NAME}-maas-auth" -n "${GATEWAY_NAMESPACE}" -o json \
  | jq '.spec.defaults.rules.response.success.headers
        | with_entries(select(.key | startswith("x-aigateway-guardrail-")))'
```

Expected result:

- Selection succeeds.
- `selectedGuardrailChecks` is `{}`.
- No guardrail success header remains.
- The empty-catalog validation rule remains, so a non-empty selection is still fail-closed.

Reset:

```bash
reset_baseline
./scripts/06-verify-selection-and-headers.sh
```

## MT-02: invalid check reference fails closed

Select a check that does not exist in the policy and confirm that selection does not silently downgrade to an allowed or empty result.

```bash
reset_baseline

oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" \
  --type=merge \
  -p='{"spec":{"guardrails":[{"ref":{"name":"marketing-privacy"},"checks":["does-not-exist"]}]}}'

sleep 5
select_subscription
```

Expected result:

- The selection request does not return an allowed selection.
- The API error is `guardrail_unavailable`.
- No partial `selectedGuardrailChecks` result is returned.

Reset:

```bash
reset_baseline
./scripts/06-verify-selection-and-headers.sh
```

## MT-03: missing policy fails closed

Delete the AIGuardrail referenced by a selected attachment and confirm that selection does not treat it as a no-policy decision.

```bash
reset_baseline

oc delete aiguardrail marketing-privacy -n "${TENANT_NAMESPACE}"
sleep 5
select_subscription
```

Expected result:

- The selection request returns `guardrail_unavailable`.
- Existing check IDs are not returned as a partial result.

Reset:

```bash
reset_baseline
./scripts/06-verify-selection-and-headers.sh
```

## MT-04: client-supplied guardrail header is rejected

Confirm that a client cannot spoof a Gateway-internal success header to bypass the guardrail. Reset first, then read one rendered header name.

```bash
reset_baseline

header_name="$(oc get authpolicy "${TENANT_NAME}-maas-auth" -n "${GATEWAY_NAMESPACE}" -o json \
  | jq -r '.spec.defaults.rules.response.success.headers | keys[]
           | select(startswith("x-aigateway-guardrail-"))' \
  | head -n1)"

gateway_host="$(oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" \
  -o jsonpath='{.spec.listeners[0].hostname}')"
model_alias="$(oc get maasmodelref "${MODEL_REF_NAME}" -n "${MODEL_NAMESPACE}" \
  -o jsonpath='{.status.resolvedModelAlias}')"

curl --silent --show-error --insecure --output /tmp/guardrail-spoof-response \
  --write-out 'HTTP %{http_code}\n' \
  -H "Authorization: Bearer ${TOKEN}" \
  -H 'Content-Type: application/json' \
  -H "X-Gateway-Model-Name: ${model_alias}" \
  -H "${header_name}: true" \
  -X POST "https://${gateway_host}/v1/chat/completions" \
  --data '{"model":"facebook/opt-125m","messages":[{"role":"user","content":"Reply with one friendly word."}],"max_tokens":8,"stream":false}'

cat /tmp/guardrail-spoof-response
```

Expected result:

- The Gateway returns HTTP `403`.
- The request does not reach the model or NeMo provider.

This case does not change cluster resources, so no reset is needed afterward.

## MT-05: check catalog changes after a valid policy update

Change a policy's check set and confirm that the AuthPolicy header catalog and selection result update together. Add a second valid check that uses the same NeMo config, then select both checks from the subscription.

```bash
reset_baseline

oc patch aiguardrail marketing-privacy -n "${TENANT_NAMESPACE}" \
  --type=merge \
  -p='{"spec":{"checks":[
    {"name":"privacy","configId":"marketing-rails","phases":["Input"]},
    {"name":"safety","configId":"marketing-rails","phases":["Input"]}
  ]}}'

oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" \
  --type=merge \
  -p='{"spec":{"guardrails":[{"ref":{"name":"marketing-privacy"},"checks":["privacy","safety"]}]}}'

oc wait --for=condition=Accepted aiguardrail/marketing-privacy \
  -n "${TENANT_NAMESPACE}" --timeout=2m

select_subscription

oc get authpolicy "${TENANT_NAME}-maas-auth" -n "${GATEWAY_NAMESPACE}" -o json \
  | jq '[.spec.defaults.rules.response.success.headers | keys[]
         | select(startswith("x-aigateway-guardrail-"))]'
```

Expected result:

- `selectedGuardrailChecks` contains two check IDs.
- The AuthPolicy contains two guardrail success headers.

Then reduce the subscription to `privacy` only.

```bash
oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" \
  --type=merge \
  -p='{"spec":{"guardrails":[{"ref":{"name":"marketing-privacy"},"checks":["privacy"]}]}}'

sleep 10
select_subscription

oc get authpolicy "${TENANT_NAME}-maas-auth" -n "${GATEWAY_NAMESPACE}" -o json \
  | jq '[.spec.defaults.rules.response.success.headers | keys[]
         | select(startswith("x-aigateway-guardrail-"))]'
```

Expected result:

- `selectedGuardrailChecks` and the guardrail success headers each contain one entry.
- The removed `safety` check ID and header are gone.
- Running MT-01 afterward also covers the `privacy -> empty` transition.

This is a priority candidate for later E2E coverage of `A+B -> A` cleanup and deduplication.

Reset:

```bash
reset_baseline
./scripts/08-verify-guardrail-requests.sh
```

## MT-06: every attachment scope contributes a check

Confirm that each of the five attachment sources supported by shared composition can select a check on its own. Remove every attachment first; selection should then return `{}`.

```bash
reset_baseline

attachment='[{"ref":{"name":"marketing-privacy"},"checks":["privacy"]}]'

oc patch aitenant "${TENANT_NAME}" -n ai-tenants --type=merge \
  -p '{"spec":{"guardrails":null}}'
oc patch maastenantconfig default-tenant -n "${TENANT_NAMESPACE}" --type=merge \
  -p '{"spec":{"guardrails":null}}'
oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" --type=merge \
  -p '{"spec":{"guardrails":null}}'
oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" --type=json \
  -p='[{"op":"remove","path":"/spec/modelRefs/0/guardrails"}]' 2>/dev/null || true
oc patch maasmodelref "${MODEL_REF_NAME}" -n "${MODEL_NAMESPACE}" --type=merge \
  -p '{"spec":{"guardrails":null}}'

sleep 10
select_subscription
```

Expected result for this step:

- Selection succeeds with `accessAllowed: true`.
- `selectedGuardrailChecks` is an empty object (`{}`). Model access authorization remains independent of whether a guardrail attachment exists.
- The AuthPolicy guardrail success header catalog is also empty. The next command prints `{}`.

```bash
oc get authpolicy "${TENANT_NAME}-maas-auth" -n "${GATEWAY_NAMESPACE}" -o json \
  | jq '.spec.defaults.rules.response.success.headers
         | with_entries(select(.key | startswith("x-aigateway-guardrail-")))'
```

Apply one scope at a time. After each application, use `select_subscription` to verify one check ID, then remove that scope before continuing.

```bash
# 1. AITenant attachment
oc patch aitenant "${TENANT_NAME}" -n ai-tenants --type=merge \
  -p "{\"spec\":{\"guardrails\":${attachment}}}"
sleep 10; select_subscription
oc patch aitenant "${TENANT_NAME}" -n ai-tenants --type=merge \
  -p '{"spec":{"guardrails":null}}'

# 2. MaasTenantConfig attachment
oc patch maastenantconfig default-tenant -n "${TENANT_NAMESPACE}" --type=merge \
  -p "{\"spec\":{\"guardrails\":${attachment}}}"
sleep 10; select_subscription
oc patch maastenantconfig default-tenant -n "${TENANT_NAMESPACE}" --type=merge \
  -p '{"spec":{"guardrails":null}}'

# 3. MaaSSubscription-wide attachment
oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" --type=merge \
  -p "{\"spec\":{\"guardrails\":${attachment}}}"
sleep 10; select_subscription
oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" --type=merge \
  -p '{"spec":{"guardrails":null}}'

# 4. Matching MaaSSubscription modelRefs entry
model_entry_patch="$(jq -nc --argjson attachment "${attachment}" \
  '[{op:"add",path:"/spec/modelRefs/0/guardrails",value:$attachment}]')"
oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" --type=json \
  -p "${model_entry_patch}"
sleep 10; select_subscription
oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" --type=json \
  -p='[{"op":"remove","path":"/spec/modelRefs/0/guardrails"}]'

# 5. MaaSModelRef attachment. A model-scoped attachment resolves its policy in
# the MaaSModelRef namespace, not in the tenant namespace. The no-auth NeMo
# provider permits consumers from every namespace for this PoC.
cat <<EOF | oc apply -f -
apiVersion: aigateway.opendatahub.io/v1alpha1
kind: AIGuardrail
metadata:
  name: marketing-privacy
  namespace: ${MODEL_NAMESPACE}
spec:
  provider:
    nemo:
      ref:
        name: ${NEMO_PROVIDER_NAME}
        namespace: ${TENANT_NAMESPACE}
    timeout: 5s
  checks:
  - name: privacy
    configId: ${NEMO_CONFIG_ID}
    phases:
    - Input
EOF
oc wait --for=condition=Accepted aiguardrail/marketing-privacy \
  -n "${MODEL_NAMESPACE}" --timeout=2m

oc patch maasmodelref "${MODEL_REF_NAME}" -n "${MODEL_NAMESPACE}" --type=merge \
  -p "{\"spec\":{\"guardrails\":${attachment}}}"
sleep 10; select_subscription
oc patch maasmodelref "${MODEL_REF_NAME}" -n "${MODEL_NAMESPACE}" --type=merge \
  -p '{"spec":{"guardrails":null}}'
oc delete aiguardrail marketing-privacy -n "${MODEL_NAMESPACE}"
```

Expected result:

- With one source applied, selection returns one `privacy` check ID.
- After removing that source, selection returns `{}` again.
- Reset to the baseline at the end.

```bash
reset_baseline
./scripts/08-verify-guardrail-requests.sh
```

## MT-07: duplicate check across scopes is emitted once

Attach the same policy/check at multiple scopes and confirm that selection and headers are not duplicated. Then remove one source while another remains and confirm that selection stays in place.

```bash
reset_baseline

attachment='[{"ref":{"name":"marketing-privacy"},"checks":["privacy"]}]'

# The subscription attachment exists after reset_baseline.
oc patch maastenantconfig default-tenant -n "${TENANT_NAMESPACE}" --type=merge \
  -p "{\"spec\":{\"guardrails\":${attachment}}}"

sleep 10
select_subscription

oc get authpolicy "${TENANT_NAME}-maas-auth" -n "${GATEWAY_NAMESPACE}" -o json \
  | jq '[.spec.defaults.rules.response.success.headers | keys[]
         | select(startswith("x-aigateway-guardrail-"))]'

# Remove only the TenantConfig source; leave the subscription source in place.
oc patch maastenantconfig default-tenant -n "${TENANT_NAMESPACE}" --type=merge \
  -p '{"spec":{"guardrails":null}}'
sleep 10
select_subscription
```

Expected result:

- With both scopes present, selection has one check ID and one header.
- Removing the TenantConfig attachment leaves the check ID in place because the subscription attachment remains.

Reset:

```bash
reset_baseline
```

## MT-08: subscription isolation for the same model

Confirm that requests for the same model can select different checks based on the selected subscription. This is the core request-time selection contract. Reset the baseline, add `privacy` and `safety` checks to the policy, then create a second subscription for a separate group.

```bash
reset_baseline

oc patch aiguardrail marketing-privacy -n "${TENANT_NAMESPACE}" \
  --type=merge \
  -p='{"spec":{"checks":[
    {"name":"privacy","configId":"marketing-rails","phases":["Input"]},
    {"name":"safety","configId":"marketing-rails","phases":["Input"]}
  ]}}'

oc wait --for=condition=Accepted aiguardrail/marketing-privacy \
  -n "${TENANT_NAMESPACE}" --timeout=2m

cat <<EOF | oc apply -f -
apiVersion: maas.opendatahub.io/v1alpha1
kind: MaaSSubscription
metadata:
  name: marketing-safety-sub
  namespace: ${TENANT_NAMESPACE}
spec:
  owner:
    groups:
    - name: guardrail-poc-safety
  priority: 10
  modelRefs:
  - name: ${MODEL_REF_NAME}
    namespace: ${MODEL_NAMESPACE}
    tokenRateLimits:
    - limit: 1000
      window: 1m
  guardrails:
  - ref:
      name: marketing-privacy
    checks:
    - safety
EOF

select_subscription system:authenticated
select_subscription guardrail-poc-safety
```

Expected result:

- The first request returns the `privacy` check ID.
- The second request returns the `safety` check ID.
- The two check IDs differ.

Reset:

```bash
reset_baseline
```

## MT-09: model identifier forms resolve to the same model

Confirm that the model resource name, namespace/name form, and resolved alias find the same MaaSModelRef and return the same guardrail selection.

```bash
model_alias="$(oc get maasmodelref "${MODEL_REF_NAME}" -n "${MODEL_NAMESPACE}" \
  -o jsonpath='{.status.resolvedModelAlias}')"

for requested_model in \
  "${MODEL_NAMESPACE}/${MODEL_REF_NAME}" \
  "${MODEL_REF_NAME}" \
  "${model_alias}"; do
  echo "requestedModel=${requested_model}"
  curl --fail-with-body --silent --show-error --insecure \
    -H 'Content-Type: application/json' \
    -X POST https://127.0.0.1:18080/internal/v1/subscriptions/select \
    --data "{\"groups\":[\"system:authenticated\"],\"username\":\"guardrail-poc\",\"requestedModel\":\"${requested_model}\"}" \
    | jq '{accessAllowed, resolvedModel, selectedGuardrailChecks, error}'
done
```

Expected result:

- All three requests return `accessAllowed: true`.
- They return the same resolved model and `selectedGuardrailChecks`.

This case does not change cluster resources, so no reset is needed afterward.

## MT-10: unavailable provider fails closed

Point the policy at a missing provider and confirm that selection fails closed instead of allowing a no-policy decision.

```bash
reset_baseline

oc patch aiguardrail marketing-privacy -n "${TENANT_NAMESPACE}" --type=merge \
  -p '{"spec":{"provider":{"nemo":{"ref":{"name":"does-not-exist"}},"timeout":"5s"}}}'

for _ in $(seq 1 30); do
  accepted="$(oc get aiguardrail marketing-privacy -n "${TENANT_NAMESPACE}" \
    -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}')"
  [[ "${accepted}" != "True" ]] && break
  sleep 2
done

echo "Accepted=${accepted:-<unset>}"
oc get aiguardrail marketing-privacy -n "${TENANT_NAMESPACE}" -o json \
  | jq '.status.conditions[] | select(.type == "Accepted" or .type == "ProviderReady")'

select_subscription
```

Expected result:

- The AIGuardrail is not `Accepted=True`.
- Selection returns `guardrail_unavailable`, not an allowed selection or empty check map.

Reset:

```bash
reset_baseline
./scripts/06-verify-selection-and-headers.sh
```

## Phase and streaming test fixture

The baseline provider contains only an input rail. The following one-time fixture adds a separate provider and policy for the phase tests below, leaving `nemo-noauth` and `marketing-privacy` unchanged. The input configuration uses the same deterministic `forbidden` check as the baseline. The output configuration deliberately blocks every model response so the response-phase tests do not depend on non-deterministic model text.

```bash
gateway_host="$(oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" \
  -o jsonpath='{.spec.listeners[0].hostname}')"
model_alias="$(oc get maasmodelref "${MODEL_REF_NAME}" -n "${MODEL_NAMESPACE}" \
  -o jsonpath='{.status.resolvedModelAlias}')"

cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nemo-phase-input-config
  namespace: ${TENANT_NAMESPACE}
data:
  config.yaml: |
    models:
    - type: main
      engine: openai
      parameters:
        base_url: "https://${gateway_host}/v1"
        model_name: "facebook/opt-125m"
    rails:
      input:
        flows:
        - check forbidden words
  rails.co: |
    define flow check forbidden words
      \$result = execute check_forbidden_words
      if \$result != "allowed"
        bot refuse forbidden content
        stop
  actions.py: |
    from typing import Optional
    from nemoguardrails.actions import action

    @action(is_system_action=True)
    async def check_forbidden_words(context: Optional[dict] = None) -> str:
        message = (context or {}).get("user_message", "").lower()
        return "blocked" if "forbidden" in message else "allowed"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nemo-phase-output-config
  namespace: ${TENANT_NAMESPACE}
data:
  config.yaml: |
    rails:
      output:
        flows:
        - block all output
  rails.co: |
    define flow block all output
      \$result = execute block_all_output
      if \$result != "allowed"
        bot refuse blocked output
        stop

    define bot refuse blocked output
      "Response blocked by the output guardrail."
  actions.py: |
    from typing import Optional
    from nemoguardrails.actions import action

    @action(is_system_action=True)
    async def block_all_output(context: Optional[dict] = None) -> str:
        return "blocked"
---
apiVersion: trustyai.opendatahub.io/v1alpha1
kind: NemoGuardrails
metadata:
  name: nemo-phase-tests
  namespace: ${TENANT_NAMESPACE}
  annotations:
    security.opendatahub.io/enable-auth: "false"
spec:
  allowedConsumers:
    namespaces:
      from: All
  exposeRoute: false
  nemoConfigs:
  - name: phase-input-rails
    configMaps:
    - nemo-phase-input-config
  - name: phase-output-rails
    configMaps:
    - nemo-phase-output-config
  env:
  - name: OPENAI_API_KEY
    valueFrom:
      secretKeyRef:
        name: api-token-noauth-secret
        key: token
EOF

for _ in $(seq 1 90); do
  phase_workload_namespace="$(oc get nemoguardrails nemo-phase-tests -n "${TENANT_NAMESPACE}" \
    -o jsonpath='{.status.workloadNamespace}' 2>/dev/null || true)"
  [[ -n "${phase_workload_namespace}" ]] && break
  sleep 2
done

if [[ -z "${phase_workload_namespace:-}" ]]; then
  oc get nemoguardrails nemo-phase-tests -n "${TENANT_NAMESPACE}" -o yaml
  echo "nemo-phase-tests did not become ready" >&2
  echo "Stop here and resolve the provider before applying the AIGuardrail." >&2
else
  cat <<EOF | oc apply -f -
apiVersion: aigateway.opendatahub.io/v1alpha1
kind: AIGuardrail
metadata:
  name: marketing-phase-tests
  namespace: ${TENANT_NAMESPACE}
spec:
  provider:
    nemo:
      ref:
        name: nemo-phase-tests
    timeout: 5s
  checks:
  - name: input-stream
    configId: phase-input-rails
    phases:
    - Input
  - name: output-buffered
    configId: phase-output-rails
    phases:
    - Output
EOF

  oc wait --for=condition=Accepted aiguardrail/marketing-phase-tests \
    -n "${TENANT_NAMESPACE}" --timeout=3m
fi
```

`common.sh` provides `gateway_chat_request`, which sends a request through the Gateway using the model-selection header and prints both the request and response. It accepts a stream boolean, message, and optional max-token value. The phase tests below use it with the default `GATEWAY_MAX_TOKENS` value.

```bash
phase_input_attachment='[{"ref":{"name":"marketing-phase-tests"},"checks":["input-stream"]}]'
phase_output_attachment='[{"ref":{"name":"marketing-phase-tests"},"checks":["output-buffered"]}]'
phase_both_attachment='[{"ref":{"name":"marketing-phase-tests"},"checks":["input-stream","output-buffered"]}]'

set_phase_attachment() {
  local attachment="$1"
  oc patch maassubscription marketing-cpu-sub -n "${TENANT_NAMESPACE}" \
    --type=merge -p "{\"spec\":{\"guardrails\":${attachment}}}"
  sleep 10
}
```

If the selection API port-forward from the prerequisites is still running, run `select_subscription` separately after changing an attachment to inspect the selected check IDs. The phase request tests themselves use the Gateway and do not require that port-forward.

## MT-11: input guardrail with streaming output

An input-only rail can inspect the request before the model is called and does not prevent the model from returning SSE. Verify both the allowed and denied request paths.

```bash
reset_baseline
set_phase_attachment "${phase_input_attachment}"

input_check_id="$(printf '%s' "${TENANT_NAMESPACE}:marketing-phase-tests:input-stream" | sha256sum | awk '{print $1}')"
output_check_id="$(printf '%s' "${TENANT_NAMESPACE}:marketing-phase-tests:output-buffered" | sha256sum | awk '{print $1}')"
select_subscription | jq -e --arg input "${input_check_id}" --arg output "${output_check_id}" '
  .accessAllowed == true and
  .selectedGuardrailChecks == {($input): true} and
  (.selectedGuardrailChecks | has($output) | not)
'

gateway_chat_request true 'Reply with one friendly word.'
gateway_chat_request true 'This message contains the forbidden word.'
```

Expected result:

- The selection assertion succeeds: it contains exactly `input-stream` and does not contain `output-buffered`.
- The first request returns HTTP `200` and an SSE response containing completion chunks.
- The second request returns HTTP `403` with the input rail rejection body.
- The forbidden request is rejected before reaching the model.

## MT-12: output guardrail with buffered output

An output rail requires a non-streaming response so Praxis can buffer the model completion, send it to NeMo, and replace a blocked response.

```bash
reset_baseline
set_phase_attachment "${phase_output_attachment}"

gateway_chat_request false 'Reply with one friendly word.'
```

Expected result:

- The model is called, then its buffered response is evaluated by the output rail.
- The HTTP status is `200` because the upstream response headers have already been committed.
- The response body is an OpenAI-style error object with `type: guardrail_violation` and `code: content_blocked`, rather than a normal `choices` completion.

## MT-13: output guardrail with streaming output fails closed

Praxis does not yet support incremental SSE response evaluation. A selected output rail must therefore reject a streaming request before the model is called instead of allowing unchecked output through.

```bash
reset_baseline
set_phase_attachment "${phase_output_attachment}"

gateway_chat_request true 'Reply with one friendly word.'
```

Expected result:

- The request returns HTTP `422`.
- The body contains `ai_guardrails: streaming responses are not supported while a response guardrail is active`.
- The model is not called.

## MT-14: input and output guardrails with buffered output

Select both checks together. The input rail allows the request, then the output rail blocks the buffered response. This covers simultaneous header selection and both phase entries in the Praxis chain.

```bash
reset_baseline
set_phase_attachment "${phase_both_attachment}"

gateway_chat_request false 'Reply with one friendly word.'
```

Expected result:

- Selection returns two check IDs and the AuthPolicy renders two corresponding headers.
- The input rail passes the request.
- The output rail replaces the model completion with the same `guardrail_violation` / `content_blocked` error document as MT-12.

## MT-15: input and output guardrails with streaming output fail closed

The input rail alone supports streaming, but the selected output rail still makes incremental response inspection unavailable. The output constraint wins, so this combination must have the same fail-closed result as MT-13.

```bash
reset_baseline
set_phase_attachment "${phase_both_attachment}"

gateway_chat_request true 'Reply with one friendly word.'
```

Expected result:

- The request returns HTTP `422` before the model is called.
- The response contains the same streaming-response guardrail error as MT-13.
- This proves a selected output check cannot be bypassed by also selecting an input check.

## MT-16: selected check IDs determine whether streaming is allowed

Use the same AIGuardrail with one Input check and one Output check, then change only the selected subscription attachment. This confirms that the request behavior follows the selected check IDs rather than merely the existence of an Output check in the AIGuardrail.

The selection assertions require the local maas-api port-forward from the prerequisites.

```bash
input_check_id="$(printf '%s' "${TENANT_NAMESPACE}:marketing-phase-tests:input-stream" | sha256sum | awk '{print $1}')"
output_check_id="$(printf '%s' "${TENANT_NAMESPACE}:marketing-phase-tests:output-buffered" | sha256sum | awk '{print $1}')"

# Input only: one selected ID, so streaming is allowed.
reset_baseline
set_phase_attachment "${phase_input_attachment}"
select_subscription | jq -e --arg input "${input_check_id}" --arg output "${output_check_id}" '
  .accessAllowed == true and
  .selectedGuardrailChecks == {($input): true} and
  (.selectedGuardrailChecks | has($output) | not)
'
gateway_chat_request true 'Reply with one friendly word.'

# Input and Output: two selected IDs, so use the buffered request path.
reset_baseline
set_phase_attachment "${phase_both_attachment}"
select_subscription | jq -e --arg input "${input_check_id}" --arg output "${output_check_id}" '
  .accessAllowed == true and
  .selectedGuardrailChecks == {($input): true, ($output): true}
'
gateway_chat_request false 'Reply with one friendly word.'
```

Expected result:

- The first selection contains only the Input check ID, and its `stream: true` request returns HTTP `200` with SSE chunks.
- The second selection contains both check IDs. Its `stream: false` request uses the buffered response path; the output test configuration blocks it and returns the OpenAI-style `guardrail_violation` / `content_blocked` error document.
- Sending `stream: true` in the second state is intentionally unsupported and must return HTTP `422`, as covered by MT-15.

Return to the normal one-check demo state after the phase cases. The phase-test provider and policy may remain installed because no subscription references them after this reset. Delete them when the manual test environment is no longer needed.

```bash
reset_baseline

oc delete aiguardrail marketing-phase-tests -n "${TENANT_NAMESPACE}" --ignore-not-found
oc delete nemoguardrails nemo-phase-tests -n "${TENANT_NAMESPACE}" --ignore-not-found
oc delete configmap nemo-phase-input-config nemo-phase-output-config \
  -n "${TENANT_NAMESPACE}" --ignore-not-found
```

## E2E candidate mapping

| Manual case | Later E2E coverage |
| --- | --- |
| Baseline | allowed and forbidden inference requests |
| MT-01 | attachment removal and empty catalog |
| MT-02 | invalid check fail-closed |
| MT-03 | missing policy fail-closed |
| MT-04 | spoofed header rejection |
| MT-05 | catalog add/remove reconciliation and deduplication |
| MT-06 | every composition attachment scope |
| MT-07 | cross-scope deduplication and source removal |
| MT-08 | per-subscription selection isolation for one model |
| MT-09 | requested model name/alias compatibility |
| MT-10 | unavailable provider fail-closed |
| MT-11 | input phase permits SSE and rejects forbidden input |
| MT-12 | buffered output phase replaces a blocked completion |
| MT-13 | output phase rejects streaming requests before upstream |
| MT-14 | input and output phases with buffered output |
| MT-15 | input and output phases fail closed for streaming output |
| MT-16 | selected Input versus Input+Output IDs determine streaming behavior |

The baseline has already passed. Run MT-01 through MT-15 from that state, change one resource at a time, and use each reset step before moving on. Only move cases with stable manual behavior into E2E coverage.
