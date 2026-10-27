#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_file() {
    local path="$1"

    if [[ ! -f "${path}" ]]; then
        echo "Required file not found: ${path}" >&2
        exit 1
    fi
}

require_file "${ODH_OPERATOR_REPO_PATH}/manifests-config.yaml"
require_file "${AI_GATEWAY_OPERATOR_REPO_PATH}/config/component_metadata.yaml"

if [[ -n "${AI_GATEWAY_OPERATOR_MANIFEST_REF}" ]]; then
    aigo_ref="${AI_GATEWAY_OPERATOR_MANIFEST_REF}"
else
    aigo_ref="main@$(git -C "${AI_GATEWAY_OPERATOR_REPO_PATH}" rev-parse HEAD)"
fi

if [[ ! "${aigo_ref}" =~ ^[^@]+@[0-9a-f]{40}$ ]]; then
    echo "AI_GATEWAY_OPERATOR_MANIFEST_REF must be branch@40-character-commit." >&2
    exit 1
fi

echo "Pinning ODH AIGateway manifests to ${aigo_ref}"

(
    cd "${ODH_OPERATOR_REPO_PATH}"

    current_ref="$(yq -r '.components.aigateway.odh.ref' manifests-config.yaml)"
    if [[ "${current_ref}" != "${aigo_ref}" ]]; then
        if ! git diff --quiet -- manifests-config.yaml; then
            echo "Refusing to overwrite modified manifests-config.yaml in ${ODH_OPERATOR_REPO_PATH}." >&2
            exit 1
        fi
        yq -i ".components.aigateway.odh.ref = \"${aigo_ref}\"" manifests-config.yaml
    fi

    make IMAGE_BUILDER=podman get-manifests

    if ! rg -q 'aiGrid' opt/manifests/aigateway; then
        echo "Downloaded AIGateway manifests do not contain spec.aiGrid." >&2
        exit 1
    fi

    make IMAGE_BUILDER=podman \
        IMG="${ODH_OPERATOR_IMAGE}" \
        image image-push

    make IMAGE_BUILDER=podman \
        VERSION="${ODH_OPERATOR_VERSION}" \
        BUNDLE_IMG="${ODH_OPERATOR_BUNDLE_IMAGE}" \
        bundle-build bundle-push

    make IMAGE_BUILDER=podman \
        VERSION="${ODH_OPERATOR_VERSION}" \
        CATALOG_IMG="${ODH_OPERATOR_CATALOG_IMAGE}" \
        BUNDLE_IMGS="${ODH_OPERATOR_BUNDLE_IMAGE}" \
        catalog-build catalog-push
)

echo
echo "Custom ODH images pushed:"
echo "  operator: ${ODH_OPERATOR_IMAGE}"
echo "  bundle:   ${ODH_OPERATOR_BUNDLE_IMAGE}"
echo "  catalog:  ${ODH_OPERATOR_CATALOG_IMAGE}"
echo
echo "Install with:"
echo "  --operator-catalog ${ODH_OPERATOR_CATALOG_IMAGE} --channel fast"
