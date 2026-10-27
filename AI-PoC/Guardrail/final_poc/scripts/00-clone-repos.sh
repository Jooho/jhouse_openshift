#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_clean_checkout() {
    local path="$1"

    if ! git -C "${path}" diff --quiet || ! git -C "${path}" diff --cached --quiet; then
        echo "Refusing to change ${path}: it has tracked local changes." >&2
        exit 1
    fi
}

checkout_main() {
    local repository="$1"
    local path="$2"

    if [[ ! -d "${path}/.git" ]]; then
        git clone --branch main "${repository}" "${path}"
    else
        require_clean_checkout "${path}"
        git -C "${path}" fetch origin main
        git -C "${path}" checkout main
        git -C "${path}" pull --ff-only origin main
    fi
}

checkout_pull_request() {
    local repository="$1"
    local path="$2"
    local pull_request="$3"

    if [[ ! -d "${path}/.git" ]]; then
        git clone "${repository}" "${path}"
    else
        require_clean_checkout "${path}"
    fi

    git -C "${path}" fetch origin \
        "+pull/${pull_request}/head:refs/remotes/origin/poc-pr-${pull_request}"
    git -C "${path}" checkout --detach "origin/poc-pr-${pull_request}"
}

mkdir -p "${POC_SOURCES_DIR}"

checkout_main \
    https://github.com/opendatahub-io/models-as-a-service.git \
    "${MAAS_REPO_PATH}"
checkout_pull_request \
    https://github.com/trustyai-explainability/trustyai-service-operator.git \
    "${TRUSTYAI_SERVICE_OPERATOR_REPO_PATH}" \
    973
checkout_pull_request \
    https://github.com/praxis-proxy/ai.git \
    "${PRAXIS_AI_REPO_PATH}" \
    1507
checkout_main \
    https://github.com/opendatahub-io/praxis-extproc.git \
    "${PRAXIS_EXTPROC_REPO_PATH}"
checkout_pull_request \
    https://github.com/opendatahub-io/ai-gateway-controller.git \
    "${AI_GATEWAY_REPO_PATH}" \
    159
checkout_main \
    https://github.com/opendatahub-io/ai-gateway-operator.git \
    "${AI_GATEWAY_OPERATOR_REPO_PATH}"
checkout_main \
    https://github.com/opendatahub-io/opendatahub-operator.git \
    "${ODH_OPERATOR_REPO_PATH}"

echo
echo "Prepared source checkouts:"
for path in \
    "${MAAS_REPO_PATH}" \
    "${TRUSTYAI_SERVICE_OPERATOR_REPO_PATH}" \
    "${PRAXIS_AI_REPO_PATH}" \
    "${PRAXIS_EXTPROC_REPO_PATH}" \
    "${AI_GATEWAY_REPO_PATH}" \
    "${AI_GATEWAY_OPERATOR_REPO_PATH}" \
    "${ODH_OPERATOR_REPO_PATH}"; do
    printf '%s  %s\n' "$(git -C "${path}" rev-parse --short HEAD)" "${path}"
done
