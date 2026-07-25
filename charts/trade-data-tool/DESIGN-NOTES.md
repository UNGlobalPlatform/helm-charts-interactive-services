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

1. **Per-service overrides** merged over the flat default — **implemented
   (2026-07-25, chart 0.6.0)**: `services.<key>.resources` (and
   `web.resources`) replace `.Values.resources` for that deployment only
   (whole-block override, no deep merge).

2. **Rebalanced defaults** grounded in the measurements above —
   **implemented (2026-07-25, chart 0.6.0)**: coreservice 100m/256Mi →
   2000m/1Gi, web 50m/256Mi → 500m/1Gi, flat default (remaining six)
   50m/256Mi → 500m/512Mi. The flat sliders now multiply ×6, not ×8, so a
   fully maxed launch drops from the ~14.6 CPU / ~36.5 Gi of PR #47 to
   ~14.1 CPU / ~30.5 Gi (6×1500m + coreservice 2000m + web 500m + Zeppelin
   2000m + MinIO 500m + readiness 50m; memory 6×4096Mi + 1024 + 1024 + 4096
   + 512 + 16 Mi) — the PR #47 slider maxima stay valid.

3. **Schema follow-up**: instead of one "per service" slider ×8, expose a
   single "pipeline performance" control mapped to coreservice CPU, so users
   don't pay eightfold for one hot service.

A rebalanced set can *lower* the total per-instance footprint while removing
the pipeline throttle — relevant with ~20 instances expected on dev-cluster
(capacity review of 2026-07-25 in the platform repo:
`argocd/mariadb-platform/README.md`).
