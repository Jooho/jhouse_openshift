# Guardrail PoC

This is a repeatable OpenShift proof of concept for the MaaS to AI Gateway guardrail handoff. It uses the normal LoadBalancer Gateway path. Do not use the old ClusterIP plus OpenShift Route approach for this PoC.

The flow is intentionally split into small phases. Stop after each phase and inspect the resources before moving on.

## Start here

Run every command below from this directory after loading the shared settings:

```bash
cd /path/to/AI-PoC/Guardrail/final_poc
source ./scripts/common.sh
```

First prepare the exact source revisions used by this PoC:

```bash
./scripts/00-clone-repos.sh
source ./scripts/common.sh
```

The script clones the current `models-as-a-service`, Praxis ExtProc, AI Gateway Operator, and ODH Operator `main` branches, plus the three feature pull requests, into `/tmp/aiguardrail_poc`:

- Models as a Service `main`
- Praxis ExtProc `main`
- AI Gateway Operator `main`
- ODH Operator `main`
- TrustyAI Service Operator [PR #973](https://github.com/trustyai-explainability/trustyai-service-operator/pull/973)
- Praxis AI [PR #1507](https://github.com/praxis-proxy/ai/pull/1507)
- AI Gateway Controller [PR #159](https://github.com/opendatahub-io/ai-gateway-controller/pull/159)

`common.sh` is the only place that defines local checkout paths, the demo tenant, image registry user, and image tag. Set overrides before sourcing it.

```bash
export QUAY_USER=jooholee
export IMAGE_TAG=guardrail-poc
export POC_SOURCES_DIR=/tmp/aiguardrail_poc
export MAAS_REPO_PATH="${POC_SOURCES_DIR}/models-as-a-service"
export TRUSTYAI_SERVICE_OPERATOR_REPO_PATH="${POC_SOURCES_DIR}/trustyai-service-operator"
export PRAXIS_AI_REPO_PATH="${POC_SOURCES_DIR}/praxis-ai"
export PRAXIS_EXTPROC_REPO_PATH="${POC_SOURCES_DIR}/praxis-extproc"
export AI_GATEWAY_REPO_PATH="${POC_SOURCES_DIR}/ai-gateway-controller"
export AI_GATEWAY_OPERATOR_REPO_PATH="${POC_SOURCES_DIR}/ai-gateway-operator"
export ODH_OPERATOR_REPO_PATH="${POC_SOURCES_DIR}/opendatahub-operator"
source ./scripts/common.sh
```

## Prerequisites

- An OpenShift cluster with cluster-admin access.
- ODH, KServe, TrustyAI, Kuadrant, MaaS, and AI Gateway enabled.
- `oc`, `jq`, `curl`, `envsubst`, a container engine, and access to an image registry.
- Git access to the source repositories used by `00-clone-repos.sh`.

The scripts default to `marketing-team`, `ai-tenant-marketing-team`, and `provider-llm`. `scripts/common.sh` also defaults `QUAY_USER=jooholee` and `IMAGE_TAG=guardrail-poc`. Override variables only when a different isolated test tenant, registry user, or image tag is required.

## 1. Build custom component images

Build and push images to a registry reachable by the cluster. Example:

```bash
(
  cd "${MAAS_REPO_PATH}/maas-api"
  make CONTAINER_ENGINE=podman REPO="quay.io/${QUAY_USER}/maas-api" TAG="${IMAGE_TAG}" build-push-image
)

(
  cd "${MAAS_REPO_PATH}/maas-controller"
  make CONTAINER_ENGINE=podman REPO="quay.io/${QUAY_USER}/maas-controller" TAG="${IMAGE_TAG}" build-push-image
)

(
  cd "${PRAXIS_AI_REPO_PATH}"
  make CONTAINER_ENGINE=podman IMAGE="quay.io/${QUAY_USER}/praxis-ai" VERSION="${IMAGE_TAG}" container
  podman push "${PRAXIS_AI_IMAGE}"
)

(
  cd "${PRAXIS_EXTPROC_REPO_PATH}"
  make CONTAINER_ENGINE=podman EXTPROC_IMAGE="${PRAXIS_EXTPROC_IMAGE}" container-release
  podman push "${PRAXIS_EXTPROC_IMAGE}"
)

(
  cd "${AI_GATEWAY_REPO_PATH}"
  make CONTAINER_ENGINE=podman REPO="quay.io/${QUAY_USER}/ai-gateway-controller" TAG="${IMAGE_TAG}" build-push-image
)

(
  cd "${AI_GATEWAY_OPERATOR_REPO_PATH}"
  USE_LOCAL=true make CONTAINER_TOOL=podman IMG="${AI_GATEWAY_OPERATOR_IMAGE}" container-build
  make CONTAINER_TOOL=podman IMG="${AI_GATEWAY_OPERATOR_IMAGE}" container-push
)

(
  cd "${TRUSTYAI_SERVICE_OPERATOR_REPO_PATH}"
  make BUILD_TOOL=podman IMG="${TRUSTYAI_SERVICE_OPERATOR_IMAGE}" docker-build docker-push
)
```

`USE_LOCAL=true` makes the AI Gateway operator gather manifests from the adjacent MaaS and AI Gateway Controller checkouts. The resulting operator image therefore contains their current local manifest revisions, including MaaS RBAC.

The `praxis-ai` image builds PR #1507 and is kept as an explicit PoC artifact. The ODH Gateway data plane currently deploys `praxis-extproc`, not this standalone image. Building it does not by itself place it on the request path.

## 2. Build a custom ODH Operator catalog

The ODH Operator owns the AIGateway CRD installation. A custom AI Gateway Operator image alone is therefore insufficient when its API is newer than the CRD bundled by the released ODH Operator. Build a custom ODH catalog that vendors the matching AI Gateway Operator `config/` manifests:

```bash
./scripts/02-build-custom-odh-catalog.sh
```

The script changes only the disposable ODH clone. It pins `components.aigateway.odh.ref` in `manifests-config.yaml` to the checked-out AI Gateway Operator commit, runs `make get-manifests`, verifies that the vendored AIGateway CRD includes `spec.aiGrid`, and builds/pushes the operator, bundle, and catalog images.

The bundle image tag is `v${ODH_OPERATOR_VERSION}` because OLM derives the bundle name from this tag and must match the generated CSV version. The catalog image can keep the PoC-specific `${IMAGE_TAG}`.

The selected AI Gateway Operator commit must be published in its GitHub repository because ODH manifest tooling fetches it by commit. To use another published commit explicitly:

```bash
export AI_GATEWAY_OPERATOR_MANIFEST_REF="main@<40-character-commit>"
./scripts/02-build-custom-odh-catalog.sh
```

## 3. Install the platform with the custom ODH catalog

The OLM Subscription configuration is immutable after creation. Install a fresh PoC platform with the custom AI Gateway operator and MaaS images from the start:

```bash
(
  cd "${MAAS_REPO_PATH}"
  INGRESS_MODE=loadbalancer ./scripts/deploy.sh --operator-type odh \
    --operator-catalog "${ODH_OPERATOR_CATALOG_IMAGE}" \
    --channel fast \
    --ai-gateway-operator-image "${AI_GATEWAY_OPERATOR_IMAGE}" \
    --maas-api-image "${MAAS_API_IMAGE}" \
    --maas-controller-image "${MAAS_CONTROLLER_IMAGE}"
)
```

* Enable TrustyAI

```bash
oc patch subscription opendatahub-operator -n opendatahub-operator-system --type=json -p='[
  {"op":"add","path":"/spec/config/env/-","value":{
    "name":"RELATED_IMAGE_ODH_TRUSTYAI_MODULE_OPERATOR_IMAGE",
    "value":"quay.io/opendatahub/odh-trustyai-module-operator:odh-stable"}},
  {"op":"add","path":"/spec/config/env/-","value":{
    "name":"RELATED_IMAGE_ODH_TRUSTYAI_SERVICE_OPERATOR_IMAGE",
    "value":"quay.io/jooholee/trustyai-service-operator:guardrail-poc"}}]'

kubectl patch datasciencecluster default-dsc \
  --type=merge \
  -p '{
    "spec": {
      "components": {
        "trustyai": {
          "managementState": "Managed"
        }
      }
    }
  }'
```
Do not use `--operator-image`, which patches the installed ODH CSV. Do not patch the ODH CSV, the AI Gateway operator Deployment, a rendered MaaS Deployment, or a generated parameter ConfigMap. The custom catalog supplies the ODH Operator, while the ODH operator passes the three component image values to the AI Gateway operator when it creates the Subscription.

Verify the images installed through OLM before creating tenant resources:

```bash
oc get deployment ai-gateway-operator -n "${ODH_NAMESPACE}" -o json | jq -r \
  '.spec.template.spec.containers[] | select(.name == "manager") | .image'

oc get deployment maas-controller -n "${ODH_NAMESPACE}" -o json | jq -r \
  '.spec.template.spec.containers[] | select(.name == "manager") | .image'
```

The first value must match `${AI_GATEWAY_OPERATOR_IMAGE}` and the second must match `${MAAS_CONTROLLER_IMAGE}`. If either value does not match, stop here and fix the initial OLM installation before continuing.

## 4. Create the demo tenant

```bash
./scripts/01-create-tenant.sh
```

The script delegates Gateway and AITenant creation to the MaaS repository's supported tenant script. It allows routes from `opendatahub`, `odh-ai-gateway-infra`, and `provider-llm`.

Before continuing, confirm that the tenant controller created its inputs and that the tenant MaaS API is running:

```bash
oc get aitenant "${TENANT_NAME}" -n ai-tenants \
  -o jsonpath='{.status.tenantNamespace}{"\\n"}'
oc get maastenantconfig default-tenant -n "${TENANT_NAMESPACE}"
oc get deployment "maas-api-${TENANT_NAME}" -n "${INFRA_NAMESPACE}"
oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}"
```

Expected result:

- The first command prints `${TENANT_NAMESPACE}`.
- `default-tenant` exists in that namespace.
- `maas-api-${TENANT_NAME}` is `Available` with a ready replica.
- The Gateway is accepted and programmed. Check its conditions if it is not:

```bash
oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}{": "}{.message}{"\\n"}{end}'
```

Do not proceed to model creation until these resources are ready. A missing `MaasTenantConfig` or tenant API deployment indicates a tenant-controller problem, not a guardrail problem.

### Tenant Gateway TLS handling

`01-create-tenant.sh` verifies that the TLS Secret selected by the supported MaaS
tenant helper exists. If it does not, the script detects the certificate Secret used
by the OpenShift default Router and replaces only the tenant Gateway certificate
reference. It then waits until the HTTPS listener reports both `Programmed=True` and
`ResolvedRefs=True`.

This covers clusters where the tenant helper falls back to `router-certs-default`,
but that Secret does not exist. It does not change the tenant hostname,
route-namespace selector, AuthPolicy, or any other tenant resource.

If the script cannot detect the Router certificate, inspect the Gateway conditions
and apply the same narrowly scoped patch manually:

```bash
ROUTER_TLS_SECRET="$(oc get deployment router-default -n "${GATEWAY_NAMESPACE}" \
  -o jsonpath='{.spec.template.spec.volumes[?(@.name=="default-certificate")].secret.secretName}')"

test -n "${ROUTER_TLS_SECRET}"
oc get secret "${ROUTER_TLS_SECRET}" -n "${GATEWAY_NAMESPACE}"

oc patch gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" --type=json -p "[
  {\"op\":\"replace\",\"path\":\"/spec/listeners/0/tls/certificateRefs/0/name\",\"value\":\"${ROUTER_TLS_SECRET}\"}
]"

```

Confirm both conditions are `True` before continuing:

```bash
oc get gateway "${TENANT_NAME}" -n "${GATEWAY_NAMESPACE}" -o json | jq -r '
  .status.listeners[]
  | select(.name == "https")
  | .conditions[]
  | select(.type == "Programmed" or .type == "ResolvedRefs")
  | "\(.type)=\(.status)"
'
```

Confirm the tenant API uses the expected custom image:

```bash
oc get deployment "maas-api-${TENANT_NAME}" -n "${INFRA_NAMESPACE}" -o json | jq -r \
  '.spec.template.spec.containers[] | select(.name == "maas-api") | .image'
```

The value must match `${MAAS_API_IMAGE}`.

## 5. Deploy a model and its MaaS resources

```bash
./scripts/03-deploy-model.sh
```

This deploys the small CPU OPT model, creates a `MaaSModelRef`, subscription, and access policy, then waits for the model reference to become usable.

## 6. Deploy NeMo and an AIGuardrail

The NeMo provider calls the model through the tenant Gateway. Provide a token that is valid for the demo subscription:

```bash
export NEMO_OPENAI_API_KEY="$(oc whoami -t)"
./scripts/04-deploy-nemo.sh
./scripts/05-deploy-aiguardrail.sh
```

`05-deploy-aiguardrail.sh` waits for `AIGuardrail.status.conditions[Accepted]` to become `True`. It does not patch status. The controller validates the NeMo provider reference, its allowed-consumer policy, the named NeMo config, and the published HTTPS endpoint before accepting the policy.

The installed TrustyAI CRD currently has no `allowedConsumers` field. The NeMo provider is therefore created in the tenant namespace, which satisfies the default same-namespace consumer rule.

## 7. Verify selection and rendered headers

```bash
./scripts/06-verify-selection-and-headers.sh
```

The verification has two independent checks:

- The MaaS API selection response contains a non-empty `selectedGuardrailChecks` map.
- The generated Gateway `AuthPolicy` contains a corresponding `x-aigateway-guardrail-<check-id>` success-header rule.

These checks prove the control-plane handoff. A success header is written to the upstream request, not returned to the client, so a wire-level header proof requires an upstream request recorder. Use the AI Gateway controller E2E suite in the final phase for that boundary test.

## 8. Deploy the custom AI Gateway Controller and Praxis ext-proc

ODH owns the AI Gateway Controller and Praxis Deployments. This step updates the
ODH Operator Subscription's supported `spec.config.env` image overrides, then waits
for ODH, the AI Gateway Operator, the controller, and both Praxis Deployments to
reconcile. It does not patch a CSV or an operator-managed Deployment directly.
Run it only after the control-plane checks above pass:

```bash
./scripts/07-use-custom-aigateway-controller.sh
```

## 9. Verify requests through the Gateway

```bash
./scripts/08-verify-guardrail-requests.sh
```

This is the data-plane check. It sends both requests to the tenant Gateway's model route; it does not use a port-forward. The script first verifies that the Gateway HTTPS listener is programmed and its references resolve, then it sends a normal chat request and expects HTTP 200 with a completion. It sends the same request shape with the word `forbidden` and expects HTTP 403 from the input guardrail.

The request uses `/v1/chat/completions` with `X-Gateway-Model-Name` set to the
resolved MaaS model alias. This preserves the complete alias for subscription
selection and matches the header-based HTTPRoute created for the model.

The script obtains an OpenShift token with `oc whoami -t`. To use another credential, export `TOKEN` before running it. The current PoC uses `curl --insecure` because its Gateway certificate is not intended to be trusted by the local workstation.

## 10. Run the AI Gateway Controller E2E suite

```bash
(
  cd "${AI_GATEWAY_REPO_PATH}"
  MAAS_E2E_DIR="${MAAS_REPO_PATH}" \
  E2E_PARALLEL_WORKERS=1 \
  bash test/e2e/scripts/run_e2e_tests.sh
)
```

Use one worker for this shared-cluster PoC. The MaaS E2E suite contains Gateway and AuthPolicy mutators that are unreliable when parallel tenants share a cluster.

## Cleanup

Preview the resources that cleanup will delete:

```bash
./scripts/cleanup.sh --dry-run
```

Delete the demo resources:

```bash
./scripts/cleanup.sh
```

Cleanup deletes the demo model and NeMo resources, then deletes the AITenant so the controller removes tenant-scoped MaaS resources. It finally deletes the Gateway and tenant namespace created for this PoC. It does not delete ODH, operators, CRDs, the default MaaS tenant, `provider-llm`, or registry images. It never removes finalizers.

To remove the complete platform installation before another custom-catalog test, use a dedicated PoC cluster and run:

```bash
./scripts/cleanup.sh --platform
```

Platform cleanup deletes `default-dsc` first and waits for ODH to reconcile component removal. It then removes `default-dsci`, the `rhoai-deps` Helm release, the custom `odh-custom-catalog` CatalogSource, and a leftover MaaS `Config/default` resource. Finally, it deletes the PoC-only `odh-ai-gateway-infra`, `opendatahub`, `opendatahub-operator-system`, and `rhoai-deps` namespaces. It retains `kuadrant-system` as a shared dependency for repeated PoC installs. It does not delete CRDs, the OLM marketplace namespace, CatalogSources other than `odh-custom-catalog`, or force-remove finalizers.

The final AIGC companion step applies shared `opendatahub` and `openshift-ingress` resources. `cleanup.sh` intentionally does not remove or restore those shared resources. Run the final E2E phase on a disposable test cluster, or restore the product AI Gateway Controller separately after testing.




~~~

oc apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kserve-module-confidential-scc-user
rules:
- apiGroups:
  - security.openshift.io
  resources:
  - securitycontextconstraints
  resourceNames:
  - openshift-ai-llmisvc-confidential-bare-metal
  verbs:
  - use
- apiGroups:
  - extensions.kuadrant.io
  resources:
  - telemetrypolicies
  verbs:
  - get
  - list
  - watch  
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kserve-module-confidential-scc-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kserve-module-confidential-scc-user
subjects:
- kind: ServiceAccount
  name: kserve-module-controller-manager
  namespace: opendatahub
EOF


kubectl create clusterrole ai-gateway-operator-aiguardrails-crd \
  --verb=get,list,watch,patch,update \
  --resource=customresourcedefinitions.apiextensions.k8s.io \
  --resource-name=aiguardrails.aigateway.opendatahub.io

kubectl create clusterrolebinding ai-gateway-operator-aiguardrails-crd \
  --clusterrole=ai-gateway-operator-aiguardrails-crd \
  --serviceaccount=opendatahub:ai-gateway-operator

kubectl auth can-i patch customresourcedefinitions/aiguardrails.aigateway.opendatahub.io \
  --as=system:serviceaccount:opendatahub:ai-gateway-operator  


kubectl create clusterrole ai-gateway-operator-guardrail-grants \
  --verb=get,patch --resource=aiguardrails.aigateway.opendatahub.io/status

# nemoguardrails 는 verb 가 달라서 규칙을 하나 더 넣어야 함
kubectl patch clusterrole ai-gateway-operator-guardrail-grants --type=json -p='[
  {"op":"add","path":"/rules/-","value":{
    "apiGroups":["trustyai.opendatahub.io"],
    "resources":["nemoguardrails"],
    "verbs":["get","list","watch"]}}]'

kubectl create clusterrolebinding ai-gateway-operator-guardrail-grants \
  --clusterrole=ai-gateway-operator-guardrail-grants \
  --serviceaccount=opendatahub:ai-gateway-operator  
~~~
