# Architecture decisions — 2026-10-27

## Proposed / subject to owner approval
- ADR-001: Two primary modules: Deep Research Engine (approved research report) and Campaign Generator (approved campaign package).
- ADR-002: WeWeb + Xano, shared PostgreSQL, API-first, model-provider-agnostic AI tasks.
- ADR-003: Evidence-first storage; links source → excerpt → insight → benefit → idea → claim → creative revision.
- ADR-004: Human approval at report, Big Idea and final campaign; immutable snapshots and methodology versions.
- ADR-005: Notion is the reference library, GitHub the implementation spec, Xano the operational data store.
- ADR-006: Goodz first pilot; buyer and supplier segments researched independently; never promise unverified marketplace activity.
- ADR-007: AI research must be citation-bound; unverified findings are labeled, never quietly promoted to proof.
- ADR-008: Phased implementation with Phase 1 only until accepted; no marketing platform integrations yet.

## Open decisions
1. Initial tenancy: single-user owner account with future workspace design, or multi-user v1? Proposed: model workspaces and membership now, expose owner-only UI in v1.
2. Async orchestration: Xano background tasks versus dedicated queue/worker based on plan capabilities.
3. Source capture & retention rules, privacy and copyright constraints by channel/jurisdiction.
4. Report scoring rubric: human judgment plus quantitative support; sample bias and independence weighting.
5. Exact campaign output channels and approval workflow for Goodz pilot.
6. Reference methodology reconciliation: research ES vs EN and extended lead list.
7. Physical schema constraints, enums and transactions validated in Xano before creation.

**Status:** architecture baseline for review; not implementation authorization.

## 2026-10-27 schema review candidate
- Module 1 normalized logical schema is proposed in [07-RESEARCH-ENGINE-SCHEMA-V1.md](07-RESEARCH-ENGINE-SCHEMA-V1.md), based on historical spreadsheet and Notion research method.
- Three modules confirmed: Deep Research Engine → Campaign Strategy → Creative Production. Module 2 produces approved Campaign Blueprint and Master Persuasive Narrative; Module 3 produces reviewed advertising assets.
- Schema remains **unapproved** pending Xano feasibility and owner acceptance; no physical tables authorized.

## Historical Ad Creation System integrated (2026-10-27)
- See [08-AD-CREATION-SYSTEM-INTEGRATION.md](08-AD-CREATION-SYSTEM-INTEGRATION.md) for screenshot-derived process mapping.
- Confirmed module ownership: M1 research/awareness/sophistication; M2 dominant desire → product performance → one belief/core concept → idea approval; M3 lead/hook/body/objections/offer/risk reduction/CUBA.
- Evaldo p.101 ten questions remain unverified; original source needed. No implementation authorization.
