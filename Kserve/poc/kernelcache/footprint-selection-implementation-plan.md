# Footprint Selection

## Current state

The Pod webhook now calculates the same identity as the KCC reconciler and selects a Ready KC by exact footprint. The capture flow, OCI publishing, KC creation, preparation Jobs, KernelCacheNode status, linker, RBAC, and short-lived credentials remain unchanged.

```text
Pod -> current identity -> Ready KC exact search -> mount
                         -> no match -> capture without a KC mount
```

## Existing footprint contract

The current factors are:

| Factor | Workload footprint | Compatibility footprint |
| --- | --- | --- |
| ISVC namespace | Excluded | Excluded |
| ISVC name | Excluded | Excluded |
| Declared runtime image | Included for digest references | Included for digest or explicit version tags |
| `modelURIHash` | Required | Required |
| `tensorParallelSize` | Included when available | Included when available |
| `commandHash` | Included when available | Excluded |
| `argsHash` | Included when available | Excluded |

Namespace and workload name are still stored in `identity.factors` for weighted scoring, but they do not change either footprint. Missing optional values are omitted. `captureSessionID`, Pod UID, capture time, cache size, and cache OCI digest are not identity factors.

The same factor map must always produce the same SHA-256 footprint. Map keys are serialized in deterministic order. The model URI is stripped of user information, query, and fragment before it is hashed.

The declared PodSpec image is used as-is. A resolved container `imageID` is not used because it is unavailable during admission.

## Selection rules

Selection uses exact footprints first, followed by equal-weight factor scoring. It does not perform registry lookups.

When a new ISVC Pod is admitted, the webhook finds the runtime container and calculates every factor available from the PodSpec:

- A digest-pinned image produces both workload and compatibility footprints.
- An explicit version tag other than `latest` produces only a compatibility footprint.
- `latest` and an omitted tag produce neither footprint and are excluded from automatic KC selection.

The selector lists Ready KCs in the same namespace and searches in this order:

1. Exact workload footprint
2. Exact compatibility footprint

`modelURIHash` must also match before either footprint can select a KC. If no exact candidate is found, the Pod starts without a KC mount and the existing MCV flow can create a new artifact.

If neither footprint matches, every factor available from the admitted Pod is compared with the candidate KC. All factors have equal weight, including namespace, workload name, runtime image, model URI hash, TP, command hash, and args hash. A missing or different candidate value is a mismatch. The highest candidate at or above 80 percent is selected. There are no hard-mismatch factors in this scoring stage.

The result is deterministic. If several KCs satisfy the same match level, the KC referenced by the workload's current KCC is preferred, followed by KC name order. A stale KCC reference does not block the search.

## Code boundary

The implementation is contained in these areas:

- Add a small shared identity package for factor construction and deterministic hashing.
- Add a selector next to the Kernel Cache admission code.
- Replace the local footprint helpers in the KCC reconciler with calls to the shared package.
- Change the consumer lookup to call the selector before the existing mount injector.

The footprint fields are optional because tagged, latest, and implicitly-latest images do not all produce both values. This requires regenerating the CRD and generated API artifacts. No MCV image, preparation Job, KernelCacheNode controller, LocalModel logic, or RBAC change is part of this work.

## Tests for the first implementation

Keep the tests focused on selection behavior:

- Same ISVC and same factors select the workload-exact KC.
- A different ISVC with the same compatibility factors selects the compatibility-exact KC.
- A version-tagged image selects only by exact compatibility footprint.
- `latest` and implicitly-latest images are not selected automatically.
- Exact workload and compatibility mismatches fall through to weighted scoring.
- One mismatch among five factors is accepted at 80 percent.
- Candidates below 80 percent are rejected.
- Multiple equal candidates always select the same KC.
- A stale KCC reference does not prevent searching for another Ready KC.
- No candidate leaves the Pod without a cache mount and does not block MCV injection.
- Disabling MCV sidecar injection still allows a matching KC to be mounted.

The capture reconciler and admission selector must continue to calculate identical values from the same input.

## Follow-up work

Registry tag resolution remains separate because a registry call in the admission path can delay or block Pod creation.

Useful selection annotations can be added with scoring later:

```yaml
internal.serving.kserve.io/kernelcache-selected: <kernel-cache-name>
internal.serving.kserve.io/kernelcache-match-type: Workload
```

These annotations are for diagnostics and are not required for the first exact-selection implementation.
