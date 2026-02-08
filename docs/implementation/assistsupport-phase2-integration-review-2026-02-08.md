# AssistSupport ↔ MemoryKernel Integration Readiness Review (Phase 2/3)

Date: 2026-02-08  
Reviewer: MemoryKernel Codex (read-only architecture review)

## A) Executive Verdict

**Verdict: Conditional Go for service-first rollout now.**

Rationale:
- AssistSupport implemented the right control skeleton (single adapter, startup preflight handshake, fallback path, pin file, CI contract job) and this materially reduces blast radius.
- MemoryKernel service contracts are stable at `service.v1` + `api.v1` and CI/release gates are strong for trilogy parity and benchmark thresholds.
- Broad production rollout is **not yet full-Go** because machine-readable error contracts and spec strictness are still insufficient for robust consumer-side policy handling.

Go condition for Phase 2 broad rollout:
1. Error envelope is standardized and versioned end-to-end.
2. OpenAPI is upgraded from endpoint summaries to strict request/response schemas (including non-2xx).
3. Pin governance is refreshed to current producer release and commit.

## B) Findings by Severity

### Critical

1) **Error contract mismatch between integration schema and service runtime**
- Integration schema expects `{code, message}`: `/Users/d/Projects/MemoryKernel/contracts/integration/v1/schemas/error-envelope.schema.json:7`
- Service currently returns `{service_contract_version, error}` with generic `400`: `/Users/d/Projects/MemoryKernel/crates/memory-kernel-service/src/main.rs:35`, `/Users/d/Projects/MemoryKernel/crates/memory-kernel-service/src/main.rs:61`
- Impact: consumer cannot reliably branch on error type (validation vs schema vs compatibility vs transient failure).

2) **AssistSupport pin is stale against current MemoryKernel release/head**
- AssistSupport pin: `/Users/d/Projects/AssistSupport/config/memorykernel-integration-pin.json:3`
- AssistSupport matrix still pinned to `v0.1.0`: `/Users/d/Projects/AssistSupport/docs/MEMORYKERNEL_COMPATIBILITY_MATRIX.md:10`
- MemoryKernel repo has `v0.2.0` and newer head available.
- Impact: declared compatibility state is behind actual producer posture; governance signal is degraded.

### High

1) **OpenAPI is not strict enough for production contract enforcement**
- Current file is path/summary only, minimal request schema coverage, no explicit error schemas: `/Users/d/Projects/MemoryKernel/openapi/openapi.yaml:7`
- Impact: weak tooling-level drift detection and poor SDK/client contract generation.

2) **Schema metadata bug in integration schemas (`$id` missing, empty-key used)**
- Example: `/Users/d/Projects/MemoryKernel/contracts/integration/v1/schemas/context-package-envelope.schema.json:3`
- Same issue appears across all integration schemas.
- Impact: downstream JSON Schema tooling behavior may be inconsistent; canonical schema identity is weakened.

3) **Service readiness semantics are shallow**
- Health endpoint only returns static `{status:"ok"}` and contract versions in envelope: `/Users/d/Projects/MemoryKernel/crates/memory-kernel-service/src/main.rs:109`
- Schema compatibility is checked by AssistSupport preflight (good), but service does not expose richer readiness/degraded details.
- Impact: operational diagnosis and triage are harder in real incidents.

### Medium

1) **Context package persistence policy is implicit (no explicit retention policy)**
- Context packages are persisted indefinitely in `context_packages`: `/Users/d/Projects/MemoryKernel/crates/memory-kernel-store-sqlite/src/lib.rs:57`, `/Users/d/Projects/MemoryKernel/crates/memory-kernel-store-sqlite/src/lib.rs:600`
- Impact: growth/privacy/retention expectations are unclear for consumer integration lifecycle.

2) **Closeout hosted checks validate “a successful recent run”, not commit-specific evidence**
- Run checks use last 20 completed-success workflows: `/Users/d/Projects/MemoryKernel/scripts/run_trilogy_phase_8_11_closeout.sh:266`
- Impact: evidence can pass while not proving the exact target commit pair.

3) **Release/readme evidence pointers are stale in places**
- README points to `v0.1.0`: `/Users/d/Projects/MemoryKernel/README.md:151`
- Trilogy matrix RC lock reflects `0.1.0`: `/Users/d/Projects/MemoryKernel/docs/implementation/trilogy-compatibility-matrix.md:50`
- Impact: humans can make wrong adoption decisions despite strong automated gates.

### Low

1) **Compliance suite is valuable but partly document/pattern based**
- Suite runner: `/Users/d/Projects/MemoryKernel/scripts/run_trilogy_compliance_suite.sh:59`
- Common checks rely on file/pattern assertions: `/Users/d/Projects/MemoryKernel/scripts/compliance/common.sh:24`
- Impact: good governance/evidence checks, but not a substitute for runtime adversarial testing.

## C) Direct Answers

### 1) Version handshake sufficiency
**Partially sufficient.**  
AssistSupport preflight validates service+API versions and schema endpoint success, which is strong for thin-slice safety: `/Users/d/Projects/AssistSupport/src-tauri/src/commands/memory_kernel.rs:170`, `/Users/d/Projects/AssistSupport/src-tauri/src/commands/memory_kernel.rs:227`.  
Gap: handshake does not prove integration baseline semantics (`integration/v1`) at runtime.

### 2) Pinning strategy
**Strategy is correct; execution is lagging.**  
Pin manifest + matrix + CI gate are present: `/Users/d/Projects/AssistSupport/config/memorykernel-integration-pin.json:1`, `/Users/d/Projects/AssistSupport/.github/workflows/ci.yml:81`.  
Action: immediately repin to current approved MemoryKernel release/commit and update matrix in same PR.

### 3) Error contract readiness
**Not ready for broad rollout.**  
Service error shape is string-based and coarse (`400` for all): `/Users/d/Projects/MemoryKernel/crates/memory-kernel-service/src/main.rs:63`.  
Needs machine-readable codes and typed categories aligned with integration schema.

### 4) Runtime lifecycle model
**Service-first lifecycle is workable but under-specified operationally.**  
AssistSupport safely degrades on unavailable/mismatch (`fallback`) and keeps app functional: `/Users/d/Projects/AssistSupport/src-tauri/src/commands/memory_kernel.rs:373`.  
Need explicit policy for startup/health polling/backoff/circuit-breaker and user-visible state transitions.

### 5) Persistence policy for context packages
**Current behavior: persist all context packages; no explicit retention contract.**  
Persist path exists and is deterministic; retention/deletion semantics are undocumented and unenforced in the service contract.

### 6) CI drift-prevention coverage/gaps
Strengths:
- MemoryKernel parity/artifact/smoke/compliance gates are strong: `/Users/d/Projects/MemoryKernel/.github/workflows/ci.yml:25`.
- AssistSupport has dedicated memorykernel contract job and pin-change doc gate: `/Users/d/Projects/AssistSupport/.github/workflows/ci.yml:73`.

Gaps:
- No commit-pair artifact proving exact producer/consumer compatibility in one machine-readable output.
- No OpenAPI strict schema diff gate for breaking changes.
- No explicit compatibility test against producer release artifact in hosted integration workflow.

### 7) Roadmap sequencing quality
**Good sequence, needs one correction:**  
Do **error/OpenAPI hardening before broader feature expansion** (recall expansion, deeper trust workflows). Otherwise rollout will accumulate coupling debt.

## D) Proposed “MemoryKernel v1 Integration Contract” (Concrete/Testable)

This is the contract AssistSupport should pin and test against in Phase 2:

1. Runtime handshake
- `GET /v1/health` returns:
  - `service_contract_version == "service.v1"`
  - `api_contract_version == "api.v1"`
  - `data.status in {"ok","degraded"}`
- `POST /v1/db/schema-version` returns success envelope and contract versions matching health.

2. Ask query contract
- `POST /v1/query/ask` success response envelope includes a valid context package with:
  - `context_package_id`
  - deterministic block (`ruleset_version`, `snapshot_id`, `tie_breakers`)
  - `selected_items[]`, `excluded_items[]`, each with `memory_version_id` + `why`.

3. Recall contract
- `POST /v1/query/recall` supports omitted/empty `record_types` default scope semantics (`decision|preference|event|outcome`) and deterministic ordering.

4. Error contract (required for broad rollout)
- Non-2xx response body must be machine-readable with:
  - `service_contract_version`
  - `error.code` (stable enum)
  - `error.message`
  - optional `error.details` object
- Distinct status mapping at minimum:
  - `400` validation
  - `404` missing context package
  - `409` semantic conflict (when applicable)
  - `503` readiness/unavailable/transient dependency

5. Compatibility governance
- Producer change that affects required fields, status codes, or error code taxonomy requires contract version bump.
- Consumer pin change requires matrix update + passing contract tests in the same PR.

## E) 2-Week Action Plan

### MemoryKernel actions
1. Define and publish strict service error envelope spec (`service.v1` patch-level compatible or versioned extension).
2. Harden `/Users/d/Projects/MemoryKernel/openapi/openapi.yaml` with full schemas for requests/responses/errors.
3. Fix schema metadata identity keys (`$id`) in integration schema files.
4. Add tests for error-code/status mapping and include in CI.
5. Refresh stale release/matrix docs to current baseline.

### AssistSupport actions
1. Update `memorykernel-integration-pin.json` + compatibility matrix to latest approved MemoryKernel release/commit.
2. Expand contract tests to assert typed error-code handling once producer exposes it.
3. Add explicit startup lifecycle policy in docs (timeout, retries, disable state, re-enable behavior).
4. Persist and surface preflight + fallback telemetry with stable reason categories for support diagnostics.

### Joint actions
1. Agree a single machine-readable compatibility artifact format for AssistSupport↔MemoryKernel pair.
2. Run commit-pair integration check in hosted CI (producer release artifact + consumer tests).
3. Formalize upgrade choreography:
   - producer release candidate
   - consumer pin PR + tests
   - compatibility artifact publish
   - promotion gate.

## F) Residual Risk Register

1. **Semantic drift under unchanged `api.v1`/`service.v1`**
- Risk: behavior changes without version field changes.
- Mitigation: stricter consumer golden tests + producer contract fixtures + changelog discipline.

2. **Operational ambiguity on service lifecycle**
- Risk: intermittent unavailable states degrade UX unpredictably.
- Mitigation: documented retry/backoff/circuit-breaker and explicit UI status classes.

3. **Evidence mismatch across repos**
- Risk: local pass but hosted pair not truly validated for exact commit set.
- Mitigation: commit-pair artifact and workflow checks tied to exact SHAs.

4. **Retention/privacy ambiguity for stored context packages**
- Risk: uncontrolled data growth or policy nonconformance.
- Mitigation: explicit retention policy + cleanup/export controls in service contract docs.

5. **Compliance confidence overestimation**
- Risk: assuming pattern checks equal full control effectiveness.
- Mitigation: add runtime adversarial tests and periodic manual control reviews.

## Positive validation of AssistSupport work completed

These controls are correctly implemented and should be retained:
- Single adapter boundary: `/Users/d/Projects/AssistSupport/src-tauri/src/commands/memory_kernel.rs:1`
- Startup preflight handshake + graceful degradation: `/Users/d/Projects/AssistSupport/src-tauri/src/commands/memory_kernel.rs:156`
- Feature-flagged enrichment fallback path: `/Users/d/Projects/AssistSupport/src/hooks/useMemoryKernelEnrichment.ts:23`
- CI contract gate + pin/matrix guard: `/Users/d/Projects/AssistSupport/.github/workflows/ci.yml:73`

