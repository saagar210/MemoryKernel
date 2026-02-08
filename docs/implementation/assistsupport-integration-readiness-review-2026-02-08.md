# AssistSupport Integration Readiness Review (MemoryKernel)

Date: 2026-02-08  
Scope: Read-only architecture/integration review of `/Users/d/Projects/AssistSupport/docs/MEMORYKERNEL_INTEGRATION_BRAINSTORM.md` against current MemoryKernel monorepo state.

## A) Executive Verdict

**Verdict: Conditional Go for service-first integration now.**

Reasoning:
- The service-first direction in the brainstorm is still the right integration posture for now, given decoupling and blast-radius advantages.
- Core controls for determinism, contract parity, and trilogy cross-repo compatibility are strong and test-backed.
- However, there are important gaps that must be closed before calling this production-grade for AssistSupport:
  - machine-readable service error contract is not ready for robust UI mapping,
  - OpenAPI is under-specified for strict consumer contract testing,
  - runtime health/lifecycle semantics are too shallow for operational confidence.

Bottom line:
- **Proceed with a thin-slice service integration behind a feature flag**, but treat full rollout as blocked on the high-severity contract and lifecycle items below.

## B) Findings by Severity

### Critical

1. **Service error model does not match integration error schema expectations.**  
   Evidence:
   - Service returns `{ service_contract_version, error }` and always HTTP 400 for errors:
     `/Users/d/Projects/MemoryKernel/crates/memory-kernel-service/src/main.rs:35`  
     `/Users/d/Projects/MemoryKernel/crates/memory-kernel-service/src/main.rs:61`  
     `/Users/d/Projects/MemoryKernel/crates/memory-kernel-service/src/main.rs:63`  
   - Canonical integration error schema expects `{ code, message }`:
     `/Users/d/Projects/MemoryKernel/contracts/integration/v1/schemas/error-envelope.schema.json:7`  
   - Brainstorm expects “stable machine-readable format” for UI-safe mapping:
     `/Users/d/Projects/AssistSupport/docs/MEMORYKERNEL_INTEGRATION_BRAINSTORM.md:161`  
   Impact:
   - AssistSupport cannot reliably branch on error classes (validation vs not-found vs storage/transient), which increases brittle string parsing and unsafe fallback behavior.

### High

2. **OpenAPI contract is too thin to enforce consumer correctness.**  
   Evidence:
   - OpenAPI paths include mostly descriptions, minimal request schema coverage, and no explicit response/error schemas:
     `/Users/d/Projects/MemoryKernel/openapi/openapi.yaml:7`  
     `/Users/d/Projects/MemoryKernel/openapi/openapi.yaml:60`  
   - Service contract claims OpenAPI is source of truth:
     `/Users/d/Projects/MemoryKernel/docs/spec/service-contract.md:40`  
   Impact:
   - Generated clients and schema-based CI checks cannot strongly catch drift in envelope fields or payload semantics.

3. **Health handshake is not a readiness check.**  
   Evidence:
   - `/v1/health` returns static `status: "ok"` and does not verify DB accessibility/schema readiness:
     `/Users/d/Projects/MemoryKernel/crates/memory-kernel-service/src/main.rs:109`  
   - Brainstorm depends on startup handshake for feature gating:
     `/Users/d/Projects/AssistSupport/docs/MEMORYKERNEL_INTEGRATION_BRAINSTORM.md:55`  
   Impact:
   - AssistSupport may mark integration “healthy” while real query endpoints fail.

4. **Implicit per-request migration creates lifecycle and latency ambiguity.**  
   Evidence:
   - API path migrates on operations (add/query/context show):
     `/Users/d/Projects/MemoryKernel/crates/memory-kernel-api/src/lib.rs:173`  
     `/Users/d/Projects/MemoryKernel/crates/memory-kernel-api/src/lib.rs:221`  
     `/Users/d/Projects/MemoryKernel/crates/memory-kernel-api/src/lib.rs:306`  
   Impact:
   - First-call behavior may mutate DB unexpectedly, raising startup-time variance and operational uncertainty for sidecar lifecycle.

5. **Release/evidence references are stale in key docs, increasing pinning drift risk.**  
   Evidence:
   - MemoryKernel README still declares current release as `v0.1.0`:
     `/Users/d/Projects/MemoryKernel/README.md:149`  
   - Compatibility matrix RC lock is pinned to older SHAs/releases:
     `/Users/d/Projects/MemoryKernel/docs/implementation/trilogy-compatibility-matrix.md:50`  
   - Brainstorm snapshot pins MemoryKernel at `b62fa63`, not latest promoted baseline:
     `/Users/d/Projects/AssistSupport/docs/MEMORYKERNEL_INTEGRATION_BRAINSTORM.md:12`  
   Impact:
   - AssistSupport may pin against stale producer evidence and lose reproducibility.

### Medium

6. **Integration schemas are loosely typed and currently malformed in `$id` field naming.**  
   Evidence:
   - Schemas use `""` instead of `$id`:
     `/Users/d/Projects/MemoryKernel/contracts/integration/v1/schemas/context-package-envelope.schema.json:3`  
   - Context package envelope schema allows broad `object` with `additionalProperties: true` for key nested semantics:
     `/Users/d/Projects/MemoryKernel/contracts/integration/v1/schemas/context-package-envelope.schema.json:20`  
   Impact:
   - Schema tooling interop is weaker, and semantic drift can slip through despite passing schema checks.

7. **Seven-standard compliance suite is useful but largely evidence-by-presence/grep.**  
   Evidence:
   - Compliance checks rely heavily on `require_file`/`require_grep` patterns:
     `/Users/d/Projects/MemoryKernel/scripts/compliance/common.sh:24`  
     `/Users/d/Projects/MemoryKernel/scripts/compliance/check_nist_80053.sh:10`  
     `/Users/d/Projects/MemoryKernel/scripts/compliance/check_gdpr.sh:10`  
   Impact:
   - Strong for governance hygiene; insufficient alone for external audit-grade control effectiveness claims.

8. **Hosted closeout checks verify historical success existence, not commit-specific freshness.**  
   Evidence:
   - Hosted checks pass if any successful run exists in recent list:
     `/Users/d/Projects/MemoryKernel/scripts/run_trilogy_phase_8_11_closeout.sh:266`  
     `/Users/d/Projects/MemoryKernel/scripts/run_trilogy_phase_8_11_closeout.sh:274`  
   Impact:
   - Could produce green closeout evidence even when current commit lacks hosted validation.

### Low

9. **Service bind is configurable beyond localhost despite localhost-only intent.**  
   Evidence:
   - `--bind` is user-supplied and not constrained to loopback:
     `/Users/d/Projects/MemoryKernel/crates/memory-kernel-service/src/main.rs:57`  
   - Brainstorm guardrail calls for localhost-only communication:
     `/Users/d/Projects/AssistSupport/docs/MEMORYKERNEL_INTEGRATION_BRAINSTORM.md:167`  
   Impact:
   - Misconfiguration risk, especially on enterprise desktops.

10. **Closeout report summary line is ambiguous.**  
    Evidence:
    - “Hosted status: PASS or SKIPPED (not required)”:
      `/Users/d/Projects/MemoryKernel/docs/implementation/trilogy-closeout-report-latest.md:125`  
    Impact:
    - Human reviewers may misread strictness level of final evidence.

## C) Direct Answers to Required Questions

### 1) Version handshake sufficiency

**Not sufficient for production-grade safety yet.**

What works:
- `service_contract_version` + `api_contract_version` are surfaced in success envelopes:
  `/Users/d/Projects/MemoryKernel/crates/memory-kernel-service/src/main.rs:30`
  `/Users/d/Projects/MemoryKernel/crates/memory-kernel-service/src/main.rs:31`

What is missing:
- health endpoint readiness signal (DB/schema/readiness) is shallow,
- no explicit endpoint-level compatibility capability matrix,
- no machine-readable error taxonomy compatibility.

Recommendation:
- Keep handshake, but add a strict preflight sequence in AssistSupport:
  `GET /v1/health` + `POST /v1/db/schema-version` + `GET /v1/openapi` digest check.

### 2) Pinning strategy

**Pin by immutable producer release + commit, and pin contract identifiers separately.**

Consumer pin set should include:
- MemoryKernel Git tag and commit SHA (e.g., current promoted baseline tag),
- `service_contract_version` (expected `service.v1`),
- `api_contract_version` (expected `api.v1`),
- integration contract baseline (`contracts/integration/v1/*` digest set),
- expected `determinism.ruleset_version` values for used endpoints.

Enforcement:
- CI must fail if any pin element drifts without explicit upgrade PR.

### 3) Error contract readiness

**Not ready for robust UI-safe production integration.**

Current service error shape is too coarse (`error: string`, one status class).  
Need:
- stable error `code`,
- predictable HTTP status families,
- optional typed metadata field for remediation hints.

### 4) Runtime lifecycle model

**Partially defined; needs explicit production policy.**

Current model:
- service exposes bind/db args and handles requests,
- API methods migrate implicitly during operations.

Needed:
- explicit startup preflight contract,
- explicit migration ownership policy (who runs migrate, when),
- restart/retry policy and bounded timeouts in consumer adapter,
- sidecar lifecycle ownership (auto-start vs externally managed).

### 5) Persistence policy for context packages

**Functionally present, policy absent.**

Current behavior:
- ask/recall persist context packages in SQLite:
  `/Users/d/Projects/MemoryKernel/crates/memory-kernel-api/src/lib.rs:249`
  `/Users/d/Projects/MemoryKernel/crates/memory-kernel-api/src/lib.rs:297`

Missing for AssistSupport use:
- retention window,
- redaction policy for query text and sensitive fields,
- deletion/compaction policy for compliance posture.

### 6) CI drift-prevention coverage/gaps

Coverage strengths:
- contract parity checks in CI:
  `/Users/d/Projects/MemoryKernel/.github/workflows/ci.yml:25`
- compatibility artifact checks:
  `/Users/d/Projects/MemoryKernel/.github/workflows/ci.yml:28`
- deterministic smoke/compliance scripts are integrated.

Gaps:
- no AssistSupport consumer contract tests in MemoryKernel CI,
- OpenAPI schema-level strictness is weak,
- hosted evidence freshness is not commit-bound.

### 7) Roadmap sequencing quality

**Good structure, needs tighter exit criteria granularity.**

Brainstorm phases are logical (service-first thin slice -> hardening -> expansion).  
Additions needed:
- explicit measurable go/no-go checks for each phase,
- explicit blocking criteria tied to error model and readiness preflight,
- explicit ownership of pin upgrade approvals and rollback authority.

## D) Proposed “MemoryKernel v1 Integration Contract” (Concrete + Testable)

This is the recommended contract AssistSupport should adopt now:

1. **Transport + version handshake**
   - `GET /v1/health` must return:
     - `service_contract_version == "service.v1"`
     - `api_contract_version == "api.v1"`
     - readiness bit (required extension for production integration).

2. **Thin-slice endpoint contract**
   - `POST /v1/query/ask` with fixed request shape (`text`, `actor`, `action`, `resource`, optional `as_of`).
   - Response must include:
     - deterministic `context_package_id`,
     - `determinism.ruleset_version`,
     - explainable `selected_items` + `excluded_items` + reasons.

3. **Error contract for service consumers**
   - Required envelope:
     - `code: string`
     - `message: string`
     - optional `details: object`
   - Status mapping:
     - 400 validation/input,
     - 404 not found (`context show`),
     - 409 compatibility/version mismatch,
     - 500 internal/storage.

4. **Preflight/readiness contract**
   - Consumer startup requires:
     - health/version pass,
     - schema-version read pass,
     - openapi digest match (or approved override).

5. **Determinism contract**
   - For fixed seed dataset + fixed `as_of`, normalized outputs must be stable across runs.
   - Explicitly pin expected ruleset versions used by consumer path.

6. **Persistence policy contract**
   - Consumer must define retention policy for persisted context packages.
   - If persistence is enabled in consumer DB, include expiry + purge job + audit log of deletions.

## E) 2-Week Action Plan

### MemoryKernel-side (Week 1-2)

1. Define and publish service error envelope v1 with `code` + status taxonomy in:
   - service contract doc,
   - OpenAPI responses,
   - service implementation/tests.
2. Add readiness semantics to health/preflight path (DB open + schema status).
3. Tighten OpenAPI with concrete request/response schemas for the endpoints AssistSupport will use first (`health`, `db/schema-version`, `query/ask`, `context/{id}`).
4. Update stale release evidence docs (`README`, compatibility matrix, closeout summary wording).

### AssistSupport-side (Week 1-2)

1. Build single adapter boundary for MemoryKernel service calls in Tauri backend.
2. Implement startup preflight gate and feature-flag fallback mode.
3. Add contract tests against pinned MemoryKernel baseline:
   - handshake pass/fail,
   - ask-response contract shape,
   - deterministic replay fixture,
   - failure-mode handling (down/timeout/mismatch/invalid payload).
4. Add compatibility matrix file and upgrade PR template enforcing pin updates.

### Joint (Week 1-2)

1. Agree on one canonical “consumer integration fixture” dataset for ask-path assertions.
2. Freeze initial AssistSupport integration target as explicit pair:
   - AssistSupport version ↔ MemoryKernel tag/commit + contract versions.
3. Run one joint release-candidate drill:
   - break error contract intentionally in branch,
   - prove consumer CI blocks rollout.

## F) Residual Risk Register

| Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|
| Service error semantics remain string-only | Medium | High | Introduce coded error envelope + status taxonomy before broad rollout | MemoryKernel |
| Handshake passes while runtime DB path is unhealthy | Medium | High | Add readiness preflight checks (health + schema probe) | MemoryKernel + AssistSupport |
| AssistSupport pins stale producer evidence | Medium | High | Lock tag+SHA+contract versions in compatibility matrix and CI | AssistSupport |
| OpenAPI drift not caught by consumer CI | Medium | Medium | Add schema-rich OpenAPI + digest pin checks | Joint |
| Compliance interpretation overstates assurance | Medium | Medium | Distinguish technical readiness vs formal certification scope in release notes | Joint |
| Context package retention/privacy ambiguity | Medium | High | Define retention + redaction + purge policy before production | AssistSupport |

---

### Summary Judgment for Integration Start

- **Start now** with service-first thin slice and hard fallback guardrails.
- **Do not** claim full production hardening until error contract + readiness + pinning governance are upgraded as listed above.
