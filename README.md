# Marketing Engine

Research-first, evidence-grounded marketing campaign generation platform.

**Status (2026-10-29):** the Phase 1 Research Engine backend is implemented on Xano workspace 3, branch `v1`: 29 tables, 24 functions, 80 endpoints, invite-only auth. It is tested end to end (71/71) and contains no data. The WeWeb frontend has not been started. See [docs/11](docs/11-PHASE-1-IMPLEMENTATION.md).

**Repository layout:** `xano/` (canonical XanoScript of workspace 3 `v1`), `scripts/xano-ws3.sh` (guarded CLI wrapper, workspace 3 only), `tests/` (end-to-end suite, synthetic data only), `docs/`.

## Three modules
1. **Deep Research Engine (M1):** independently researches a product, its customers, competitors and market; stores source-linked evidence; produces an approved, versioned Research Report.
2. **Campaign Strategy (M2):** consumes an immutable approved Research Report version, matches a dominant desire to product performance, and obtains approval for the one belief / Big Marketing Idea.
3. **Creative Production (M3):** builds and evaluates the persuasive narrative, drafts advertising assets and the campaign package with claim-level provenance.

## Stack
WeWeb frontend; Xano API/workflows/PostgreSQL; model-provider-agnostic AI gateway with structured outputs; external research acquisition adapters; Notion reference playbooks; GitHub as source of truth for technical documents and implementation.

## Documentation
- [Product and system boundaries](docs/01-SYSTEM-ARCHITECTURE.md)
- [Relational data architecture](docs/02-DATA-MODEL.md)
- [Workflows, contracts and guardrails](docs/03-WORKFLOWS.md)
- [Research Report and campaign schemas](docs/04-OUTPUT-CONTRACTS.md)
- [Methodology mapping](docs/05-METHODOLOGY-MAPPING.md)
- [Historical research workbook mapping](docs/06-SPREADSHEET-RESEARCH-MAPPING.md)
- [Module 1 logical schema V1](docs/07-RESEARCH-ENGINE-SCHEMA-V1.md)
- [Historical ad creation system integration](docs/08-AD-CREATION-SYSTEM-INTEGRATION.md)
- [Phase 1A Xano feasibility review (technical assessment)](docs/09-PHASE-1A-XANO-FEASIBILITY-REVIEW.md)
- [Phase 1 architecture baseline (conceptual decisions)](docs/10-PHASE-1-ARCHITECTURE-BASELINE.md)
- [**Phase 1 implementation: schema, API, security, tests (current)**](docs/11-PHASE-1-IMPLEMENTATION.md)
- [Decisions and open questions](docs/DECISIONS.md)
- [Claude implementation handoff](CLAUDE.md)

**Build order:** review and accept specifications → implement core tenancy/projects and research records → source ingestion and evidence extraction → insight review → frozen Research Report → campaign generation. Never skip evidence validation merely to produce copy quickly.
