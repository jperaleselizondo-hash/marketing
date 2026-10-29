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

## Phase 1A founder decisions (2026-10-29) — APPROVED conceptual decisions
Founder decision: **GO for architecture consolidation and M0 preparation; NO-GO for Xano writes or implementation.** Consolidated in [10-PHASE-1-ARCHITECTURE-BASELINE.md](10-PHASE-1-ARCHITECTURE-BASELINE.md); technical assessment in [09-PHASE-1A-XANO-FEASIBILITY-REVIEW.md](09-PHASE-1A-XANO-FEASIBILITY-REVIEW.md).
- ADR-009: **Three modules**: Research (M1) → Campaign Strategy (M2) → Creative Production (M3). Supersedes ADR-001's two-module wording.
- ADR-010: **Research workflow.** Phase 1A is human-entered evidence and human review. Phase 1B is AI extraction as proposals requiring human acceptance. Source evidence, interpretation and campaign claims are structurally distinct layers.
- ADR-011: **Canonical taxonomy.**
  - IVOC categories: `pain_fear, desire, objection, firm_belief, shakable_belief, vocabulary, other` (pains and fears combined in V1).
  - `insight_kind`: `ivoc_theme | opportunity`.
  - `observation_type`: `verbatim_quote | paraphrase | secondary_summary | analyst_hypothesis`.
  - `origin`: `human_entered | imported | ai_proposed`.
  - `evidence_basis`: `evidenced | hypothesis`.
  - Pseudonymous author/speaker attribution and AI job provenance.
  - Five awareness levels.
  - Five sophistication stages, *provisional* pending methodology reconciliation.
- ADR-012: **Privacy model** separates five dimensions:
  1. legal basis for personal-data processing;
  2. provenance and acquisition method;
  3. usage and quotation rights;
  4. personal-data classification;
  5. retention.

  No single `lawful_basis` enum. Legal classifications require jurisdiction-specific review.
- ADR-013: **Naming.** `organizations` (not application `workspaces`), `jobs`, a shared review vocabulary with entity-specific lifecycles where necessary.
- ADR-014: **Stable gate identifiers:** `R0_SCOPE … R5_REPORT`, `S1_DESIRE_MATCH`, `S2_BIG_IDEA`, `P1_NARRATIVE`, `P2_ASSET_REVIEW`, `P3_PACKAGE`. They replace the G0–G6 / G1–G6 numbering in docs/01 and docs/08.
- ADR-015: S1 desire-match and S2 Big Idea are **separate approvals**. The M2 one-belief decision (S2) must be approved before M3 begins drafting. The **Evaldo ten-question framework moves to M3**, evaluating the persuasive narrative at P1 before asset approval. Its content remains an unresolved source dependency.
- ADR-016: **Logical scope.**
  - 27 core Research Engine tables (including the existing starter `user` table, to be extended) + `invitations` = **28**.
  - `competitors`, `competitor_observations` and `product_proofs` are retained.
  - `research_report_excerpts` is deferred.
  - This is not table-creation authorization.
- ADR-017: **Security.**
  - Xano workspace 3 is the only authorized target for Marketing Engine work.
  - Invite-only authentication; owner bootstrap preferred via the Xano dashboard.
  - The global CLI default profile and Goodz/PMF configuration are preserved.
  - Repository-level command safeguards.

### Resolved open decisions
- **Item 1 (tenancy):** model organizations and membership now; invite-only.
- **Item 7 (physical constraints):** remains open, tracked as V1–V17 in docs/10 §8.
- **Items 2–6:** remain open.

### Pending implementation authorization
- M0 security batch: docs/10 §7, §9 Batch 1.
- M1 tenancy schema: docs/10 §9 Batch 2.
- S1–S9 verification spikes: not authorized. An isolated environment must first be confirmed (V1).
