# Design notes — trade-data-tool

Open design directions recorded here because the repository has issues
disabled. Each note is dated; delete a note when it is implemented or
rejected.

## Per-service resources instead of one flat block ×8 (2026-07-25)

The chart applies one flat `resources` block to all eight app deployments
(`templates/deployments.yaml`). Live measurement on dev-cluster of an
instance mid-pipeline showed how poorly that fits the workload:

| Pod | CPU | Memory |
|---|---|---|
| coreservice | **1022m — pinned at its 1000m limit (throttled)** | 83Mi |
| web | 1m | 168Mi |
| other six services | ~1m each | 44–72Mi each |

CoreService (the Silver pipeline) is the only real CPU consumer and is
throttled by the shared limit, while the other seven idle two orders of
magnitude below it yet carry identical requests/limits. The flat block also
multiplies every schema-slider move by 8, which is why PR #47 had to cap the
slider maxima so conservatively for 16 CPU / 64 GB namespaces.

Proposed direction:

1. **Per-service overrides** merged over the flat default:

   ```yaml
   services:
     coreservice:
       resources:          # overrides .Values.resources for this deployment only
         limits: { cpu: 2000m, memory: 1Gi }
   ```

2. **Rebalanced defaults** grounded in the measurements above:
   - coreservice: the CPU budget (pipeline latency is directly bounded by
     its limit — and vertical is the only lever; see the tradedatatools
     ARCH-DEBT note of 2026-07-25 on the missing scale-out story);
   - web: the memory headroom (largest observed footprint of the eight);
   - the remaining six: lower defaults (e.g. 250m / 512Mi limits).

3. **Schema follow-up**: instead of one "per service" slider ×8, expose a
   single "pipeline performance" control mapped to coreservice CPU, so users
   don't pay eightfold for one hot service.

A rebalanced set can *lower* the total per-instance footprint while removing
the pipeline throttle — relevant with ~20 instances expected on dev-cluster
(capacity review of 2026-07-25 in the platform repo:
`argocd/mariadb-platform/README.md`).
