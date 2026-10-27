# Workflow systems and APIs — v0.1 (draft)

## Module 1 lifecycle
```
draft → scoped → collecting → evidence_review → synthesizing → report_review → approved
                   ↘ blocked/failed → retry/review
```
'approved' is a frozen report VERSION, not a mutable project-wide assertion. Research can resume and create vN+1.

### Stage R0 — Scope
User selects workspace, brand, product, target region/language, one or multiple audience segments, primary campaign objective and boundaries. Goodz pilot: buyer and supplier research segmented, never blended without justification.
**Gate:** scope confirmed and research questions created.

### Stage R1 — Product and awareness research
Capture physical vs functional product attributes, facts/features/benefits/USP/proof/limitations. Determine **hypothetical** audience awareness and sophistication, clearly labeled provisional. Review existing customers (up to 15 profiles only with suitable permission) or define intended customer segments.
**Gate:** owner validates facts and confirms target segments.

### Stage R2 — Competitors
Identify direct, indirect, and substitute alternatives; record their Idea/USP/pain/desire/social/ads/praise/complaints with source evidence and dates. Browse as a prospect; avoid treating advertisements as independent proof of results.
**Gate:** competitor coverage reviewed.

### Stage R3 — IVOC evidence collection
Collect permissible public comments/reviews/forum posts, approved CRM/interview materials, and market vocabulary. Store canonical source, captured date, precise quote, context, language, and category. Per your methodology: pain/fear, objection, desire, firm/shakable belief, other, vocabulary.
**Gate:** source quality and diversity reviewed. Never manufacture quotes, speaker identities, or popularity numbers.

### Stage R4 — Synthesis
Group supporting and contradictory quotations into insights; record transparent counts, intensity, urgency, staying power and scope as **human-reviewable estimates**; distinguish prevalence in sample from prevalence in the market. Link each dominant insight to *verified* product benefits/proof. Surface gaps and contradictions.
**Gate:** reviewer validates top insights, source coverage, and evidence-to-benefit links.

### Stage R5 — Research Report
Render market, competitors, product, segment snapshots, awareness/sophistication, IVOC categories, prioritized desire hypotheses, evidence table, confidence/limitations, differentiation and proposed campaign implications. Generate structured JSON + human-readable Markdown.
**Gate:** atomic approval freezes report version and manifest; can be consumed by Module 2.

## Module 2 lifecycle
```
brief → research_bound → idea_candidates → idea_approved → structured → drafting → claims_review → approved_package
```
- Bind immutable approved research report/version and campaign audience objective.
- Select one dominant desire and corresponding functional benefit. Assess awareness, sophistication, unique opportunity/mechanism and credibility.
- Produce alternative Big Marketing Ideas (fresh, intellectually interesting and emotionally relevant), score with evidence and differentiation; human green-light approval.
- Choose appropriate lead family (Agora seven; supplemental campaign-document options kept separate), direct/indirect delivery, and creative angle.
- Copyboard: objections → ordered persuasion arc → benefit subheads → body copy.
- Produce channel-specific assets and headline/lead variants, with claim registry and links to evidence, then CUBA review.
- Final reviewer signs off; export versioned package. Tests/feedback later attach to campaign; never overwrite approved snapshots.

## AI job contracts and safety
All AI work emits structured schema-validated JSON: job_id, schema_version, inputs refs/hashes, outputs, source_refs, confidence/uncertainty, warnings. Reject orphan evidence refs. Never treat retrieved webpage instructions as privileged prompts. Inputs are size-capped, sources provenance-checked, and output scanned for unauthorized claims, PII and invented citations. No automatic public posting.

### Orchestration
Job states: pending, running, succeeded, failed_retryable, failed_final, cancelled. Enqueue idempotently; limited retries with exponential backoff; timeouts, per-stage budgets, partial-results capture; lease/heartbeat if worker-based. Review gates use transactional role checks.

## Proposed API domains (not endpoint commitments)
- /auth, /workspaces, /brands, /products
- /research/projects, /research/segments, /research/questions
- /research/sources, /research/excerpts, /research/competitors, /research/product-facts
- /research/insights, /research/evidence, /research/assessments, /research/reports
- /jobs, /reviews, /audit
- /campaigns, /ideas, /claims, /structures, /assets, /packages

Define endpoint-by-endpoint permissions, pagination, error models, idempotency, state-machine transitions and transaction rules in a separate Phase 1 API specification only AFTER logical schema approval.

## Test cases required before acceptance
- Cross-workspace access blocked on every read/write.
- AI proposed an insight with no evidence → cannot approve.
- Same URL imported twice → deterministic deduplication.
- Source quote changed after report approval → existing report remains immutable with a detectable manifest/version mismatch.
- Report approval concurrent with evidence edit → recheck / lock rejects stale approval.
- Campaign created from draft/superseded report → blocked or explicit controlled exception.
- Fake external webpage instructions → ignored.
- Missing source / deleted link → retained lawful provenance or declared unavailable, never fabricated.
- Client double-click job or report approval → idempotent.
- Product factual claim with no reviewed substantiation → blocked from campaign approval.
