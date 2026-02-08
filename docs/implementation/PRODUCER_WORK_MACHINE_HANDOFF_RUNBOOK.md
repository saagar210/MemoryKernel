# MemoryKernel Producer Work-Machine Handoff Runbook

Status: Validated  
Date: 2026-02-08

## Goal
Provide deterministic bootstrap and validation instructions for running MemoryKernel producer workflows on the work machine.

## Runtime Baseline
1. `release_tag`: `v0.4.0`
2. `commit_sha`: `7e4806a34b98e6c06ee33fa9f11499a975e7b922`
3. `service_contract_version`: `service.v3`
4. `api_contract_version`: `api.v1`

## Bootstrap
```bash
git clone https://github.com/saagar210/MemoryKernel.git
cd MemoryKernel
cargo fetch
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-targets --all-features
```

## Governance Validation
```bash
./scripts/verify_service_contract_alignment.sh --memorykernel-root /Users/d/Projects/MemoryKernel
./scripts/verify_contract_parity.sh --canonical-root /Users/d/Projects/MemoryKernel
./scripts/verify_trilogy_compatibility_artifacts.sh --memorykernel-root /Users/d/Projects/MemoryKernel
./scripts/run_trilogy_smoke.sh --memorykernel-root /Users/d/Projects/MemoryKernel
./scripts/run_trilogy_compliance_suite.sh --memorykernel-root /Users/d/Projects/MemoryKernel --skip-baseline
./scripts/verify_producer_contract_manifest.sh --memorykernel-root /Users/d/Projects/MemoryKernel
./scripts/verify_producer_handoff_payload.sh --memorykernel-root /Users/d/Projects/MemoryKernel
```

## Rollback Readiness
1. Confirm rollback communication protocol:
   1. `docs/implementation/SERVICE_V3_ROLLBACK_COMMUNICATION_PROTOCOL.md`
   2. `docs/implementation/SERVICE_V3_CUTOVER_DAY_CHECKLIST.md`
2. Confirm rollback governance packet exists:
   1. `docs/implementation/JOINT_RUNTIME_CUTOVER_GATE_REVIEW_2026-02-08.md`

## Signoff
1. Producer Platform Owner: Approved
2. Producer Contract Owner: Approved
3. Producer Program Owner: Approved
