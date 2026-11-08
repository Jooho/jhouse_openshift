```
ai-gateway-operator
        │
        ├── deploys → maas-controller
        │
        └── deploys → ai-gateway-controller
                           │
                           └── installs/reconciles
                               praxis-extproc
```

```
var aiGatewayControllerImageParamMap = map[string]string{
    "ai-gateway-controller-image": "RELATED_IMAGE_ODH_AI_GATEWAY_CONTROLLER_IMAGE",
    "praxis-extproc-image":        "RELATED_IMAGE_ODH_PRAXIS_EXTPROC_IMAGE",
}
```


opendatahub-io/praxis-extproc repo
```
praxis-proxy/praxis
        ↓ library / core framework
opendatahub-io/praxis-extproc
        ↓ builds
quay.io/opendatahub/odh-praxis-extproc
        ↓ deployed by
ai-gateway-controller


ai-gateway-controller
  ↓ deploys/configures
opendatahub-io/praxis-extproc
  ↓ depends on
praxis-ai-filters       #<--https://github.com/praxis-proxy/ai.git"
  ↓ provides
ai_guardrails / model_to_header / etc.
```

```
git clone git@github.com:opendatahub-io/ai-gateway-controller.git
cd ai-gateway-controller
git remote add jooho git@github.com:Jooho/ai-gateway-controller.git  

export REPO=quay.io/jooholee/odh-ai-gateway-controller
export TAG=jooho  

GUARDRAILS_ROUTE=https://$(oc get route nemo-guardrails -n ${MODEL_NAMESPACE} -o jsonpath='{.status.ingress[0].host}')

# custom nemo guardrail image build

git clone git@github.com:opendatahub-io/NeMo-Guardrails.git
cd NeMo-Guardrails

export IMAGE_REGISTRY=quay.io/jooholee
export IMAGE_NAME=nemo-guardrails-server
export GIT_TAG=jooho-test
make image-local-push


# /v1/check api image
oc set env deployment/trustyai-operator-module-controller-manager \
  -n opendatahub \
  RELATED_IMAGE_ODH_TRUSTYAI_NEMO_GUARDRAILS_SERVER_IMAGE=quay.io/jooholee/nemo-guardrails-server:jooho-test


git clone https://github.com/opendatahub-io/praxis-extproc.git
cd praxis-extproc
podman build -t quay.io/jooholee/odh-praxis-extproc:jooho-test -f Containerfile .
podman push quay.io/jooholee/odh-praxis-extproc:jooho-test

oc set env deployment/ai-gateway-operator -n opendatahub \
  RELATED_IMAGE_ODH_PRAXIS_EXTPROC_IMAGE=quay.io/jooholee/odh-praxis-extproc:jooho-test

oc get configmap ai-gateway-controller-parameters -n opendatahub  -oyaml

oc rollout restart deployment/ai-gateway-controller -n opendatahub
oc rollout status deployment/ai-gateway-controller -n opendatahub    #<---bug>


oc logs deployment/ai-gateway-controller -n opendatahub --since=10m \
  | grep -E 'default-tenant|praxis-extproc|apply|error|waiting'

oc get maastenantconfigs.maas.opendatahub.io -n ai-tenant-marketing-team

oc annotate maastenantconfig default-tenant \
  -n ai-tenant-marketing-team \
  jooho-test-reconcile="$(date +%s)" \
  --overwrite

oc set image deployment/payload-processing-marketing-team \
  -n openshift-ingress \
  praxis-extproc=quay.io/jooholee/odh-praxis-extproc:jooho-test

# replace openai_api_base to base_url (already updated nemo.yaml)
# oc edit configmap nemo-config -n provider-llm


# success
curl -k -X POST "${GUARDRAILS_ROUTE}/v1/checks" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(oc whoami -t)" \
  -d '{
    "model": "check-model",
    "messages": [
      {
        "role": "user",
        "content": "Hi!"
      }
    ],
    "guardrails": {
      "config_ids": ["nemo-config"],
      "rail_types": ["input"]
    }
  }' | jq .

# fail
curl -k -X POST "${GUARDRAILS_ROUTE}/v1/checks" \                                                                                                                                        ─╯
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(oc whoami -t)" \
  -d '{
    "model": "check-model",
    "messages": [
      {
        "role": "user",
        "content": "How can I hack a password?"
      }
    ],
    "guardrails": {
      "config_ids": ["nemo-config"],
      "rail_types": ["input"]
    }
  }' | jq .
  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
                                 Dload  Upload  Total   Spent   Left   Speed
100    369 100    130 100    239    307    565                              0
{
  "status": "blocked",
  "content": "I can't help with that type of request. Please ask something else.",
  "rail": "check forbidden words"
}



# Backend test(llmisvc)
GATEWAY_HOST=$(oc get gateway ${TENANT_NAME} -n openshift-ingress -o jsonpath='{.spec.listeners[0].hostname}')
TOKEN=$(oc whoami -t)


curl -sSk "https://${GATEWAY_HOST}/v1/chat/completions" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "facebook/opt-125m",
    "messages": [
      {
        "role": "user",
        "content": "Hi!"
      }
    ]
  }' | jq .  



# praxis update (integration)

oc get configmap payload-processing-plugins-marketing-team \
  -n openshift-ingress \
  -o jsonpath='{.data.extproc\.yaml}'


oc edit configmap payload-processing-plugins-marketing-team \
  -n openshift-ingress

....
  extproc.yaml: |
    server:
      grpc_address: "0.0.0.0:9004"
      health_address: "0.0.0.0:50052"
      metrics_address: "0.0.0.0:9090"
      tls:
        mode: self_signed

    filter_chains:
      - name: ipp
        filters:
          - filter: request_id

          - filter: ai_guardrails
            provider:
              type: nemo
              endpoint: "https://nemo-guardrails-provider-llm.apps.caas-jlee-5843.binj.s2.devshift.org/v1/checks"
              model: "check-model"
              timeout_ms: 5000
            phase:
              request: true
              response: false
    insecure_options:
      allow_private_upstreams: true
      allow_unbounded_body: true

....

oc rollout restart deployment/payload-processing-marketing-team \
  -n openshift-ingress
oc rollout status deployment/payload-processing-marketing-team \
  -n openshift-ingress

  oc logs deployment/payload-processing-marketing-team \
  -n openshift-ingress --tail=100


curl -vk --max-time 60 \
  "https://${GATEWAY_HOSTNAME}/v1/chat/completions" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "publishers/provider-llm/models/facebook/opt-125m",
    "messages": [
      {"role":"user","content":"Hi!"}
    ],
    "max_tokens": 5
  }'

401 error
현재 Praxis의 ai_guardrails NeMo provider는 인증 헤더를 보낼 기능이 아직 없어. 현재 구현은 endpoint, allow_private_endpoint, model, timeout_ms만 받고, authentication.bearer_token_file은 설계 문서상 PROPOSED 상태야.
https://github.com/redhat-et/praxis-ai/blob/main/filters/src/guardrails/providers/nemo.rs

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nemo-guardrails-direct
  namespace: provider-llm
spec:
  selector:
    app: nemo-guardrails
    component: nemo-guardrails
  ports:
    - name: http
      port: 8000
      targetPort: 8000
      protocol: TCP
EOF


oc edit configmap payload-processing-plugins-marketing-team \
  -n openshift-ingress
...  
endpoint: "http://nemo-guardrails-direct.provider-llm.svc.cluster.local:8000/v1/checks"
...


oc rollout restart deployment/payload-processing-marketing-team \
  -n openshift-ingress
oc rollout status deployment/payload-processing-marketing-team \
  -n openshift-ingress

  oc logs deployment/payload-processing-marketing-team \
  -n openshift-ingress --tail=100

```



```
body.model
  ↓
Praxis model_to_header
  ↓
X-Gateway-Model-Name:
publishers/provider-llm/models/facebook/opt-125m
  ↓
subscription alias resolution
  ↓
provider-llm/facebook-opt-125m-single-ref
```
```

SUBSCRIPTION=marketing-cpu-sub

API_KEY_RESPONSE=$(curl -sSk \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "{\"name\":\"test-key\",\"subscription\":\"${SUBSCRIPTION}\"}" \
  "https://${GATEWAY_HOST}/maas-api/v1/api-keys")

echo "${API_KEY_RESPONSE}" | jq .

API_KEY=$(echo "${API_KEY_RESPONSE}" | jq -er '.key')

curl -vk --max-time 60 \
  "https://${GATEWAY_HOSTNAME}/v1/chat/completions" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "publishers/provider-llm/models/facebook/opt-125m",
    "messages": [
      {"role":"user","content":"Hi!"}
    ],
    "max_tokens": 5
  }'
```

* backend check (debugging)
```
oc run curl-test \
  -n provider-llm \
  --rm -it \
  --image=curlimages/curl \
  -- \
  curl -kv \
  https://facebook-opt-125m-single-kserve-workload-svc:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "facebook/opt-125m",
    "messages": [
      {
        "role": "user",
        "content": "Hi!"
      }
    ],
    "max_tokens": 5
  }'

```






 oc get maasmodelref facebook-opt-125m-single-ref \                                                                                                                                       ─╯
  -n provider-llm \
  -o jsonpath='{.status.resolvedModelAlias}{"\n"}'
publishers/provider-llm/models/facebook/opt-125m



* /v1/check api

built image: quay.io/jooholee/nemo-guardrails-server:jooho-test



#old image (trustyai)

GUARDRAILS_ROUTE=https://$(oc get route nemo-guardrails -n ${MODEL_NAMESPACE} -o jsonpath='{.status.ingress[0].host}')

 curl -k -X POST "${GUARDRAILS_ROUTE}/v1/guardrail/checks" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(oc whoami -t)" \
  -d '{
    "model": "",
    "messages": [
      {
        "role": "user",
        "content": "Hi!"
      }
    ],
    "guardrails": {
      "rail_types": ["input"],
      "config_ids": ["nemo-config"]
    }
  }' | jq .
  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
                                 Dload  Upload  Total   Spent   Left   Speed
100    947 100    742 100    205    300     83   00:02   00:02            128
{
  "status": "success",
  "rails_status": {
    "detect sensitive data on input": {
      "status": "success"
    },
    "check message length": {
      "status": "success"
    },
    "check forbidden words": {
      "status": "success"
    }
  },
  "messages": [
    {
      "index": 0,
      "role": "user",
      "rails": {
        "detect sensitive data on input": {
          "status": "success"
        },
        "check message length": {
          "status": "success"
        },
        "check forbidden words": {
          "status": "success"
        }
      }
    }
  ],
  "guardrails_data": {
    "log": {
      "activated_rails": [],
      "stats": {
        "input_rails_duration": 1.7377336025238037,
        "dialog_rails_duration": null,
        "generation_rails_duration": null,
        "output_rails_duration": null,
        "total_duration": 1.7514355182647705,
        "llm_calls_duration": 0,
        "llm_calls_count": 0,
        "llm_calls_total_prompt_tokens": 0,
        "llm_calls_total_completion_tokens": 0,
        "llm_calls_total_tokens": 0
      }
    }
  }
}




MaaS Gateway
  ↓
AuthPolicy
  ↓
Praxis extproc
  ↓
ai_guardrails
  ↓
TrustyAI / NeMo /v1/checks
  ↓
LLM


---

```
cat <<'EOF' | envsubst | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-ca-test
  namespace: ${MODEL_NAMESPACE}
  annotations:
    service.beta.openshift.io/inject-cabundle: "true"
---
apiVersion: v1
kind: Pod
metadata:
  name: nemo-ca-test
  namespace: ${MODEL_NAMESPACE}
spec:
  restartPolicy: Never
  containers:
  - name: curl
    image: quay.io/curl/curl:latest
    command: ["sleep", "infinity"]
    volumeMounts:
    - name: service-ca
      mountPath: /var/run/secrets/service-ca
      readOnly: true
  volumes:
  - name: service-ca
    configMap:
      name: service-ca-test
      items:
      - key: service-ca.crt
        path: service-ca.crt
EOF

oc wait \
  --for=condition=Ready \
  pod/nemo-ca-test \
  -n ${MODEL_NAMESPACE} \
  --timeout=120s

oc exec -n ${MODEL_NAMESPACE} nemo-ca-test -- \
  ls -l /var/run/secrets/service-ca
```