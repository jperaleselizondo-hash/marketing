# Logical relational data model — v0.1 (draft)

> **Baseline only.** The Module 1 portion is superseded by [07](07-RESEARCH-ENGINE-SCHEMA-V1.md) as amended by [10-PHASE-1-ARCHITECTURE-BASELINE.md](10-PHASE-1-ARCHITECTURE-BASELINE.md) (2026-10-29): `workspaces` → `organizations`, `workflow_runs` → `jobs`, approved taxonomy and the 28-table inventory. Campaign tables below remain an unreviewed M2/M3 sketch.

This is **platform-neutral logical schema**, NOT a request to create Xano tables immediately. Use integer/bigint keys or UUID consistently after Xano feasibility review. Every business row has created_at/updated_at where sensible. Every user-owned entity is workspace-scoped (directly or via an enforced FK path). Prefer normalized keys over arrays of IDs.

## Foundation

| Table | Essential fields / relationships |
|---|---|
| workspaces | id, name, status |
| users | id, auth reference, name, status |
| workspace_members | id, workspace_id FK, user_id FK, role (owner/editor/reviewer/viewer), unique(workspace_id,user_id) |
| brands | id, workspace_id FK, name, description, market, primary_locale |
| products | id, brand_id FK, name, functional_description, state |
| research_projects | id, workspace_id FK, product_id FK, title, objective, scope, status, owner_id, methodology_version_id FK |
| methodology_versions | id, slug, semantic_version, source_url, content_hash, approved_at, instructions_ref, status |
| workflow_runs | id, workspace_id FK, project_id FK nullable, module, step, status, idempotency_key, input_hash, prompt_version, model, started_at, finished_at, attempts, error_code, usage_json |
| audit_events | id, workspace_id FK, actor_id nullable, entity_type, entity_id, action, before_hash, after_hash, occurred_at |

## Research acquisition and evidence

| Table | Essential fields / relationships |
|---|---|
| audience_segments | id, research_project_id FK, name, role/job, geography, pains_hypothesis, awareness_hypothesis |
| research_questions | id, research_project_id FK, audience_segment_id nullable, question, priority, status |
| research_sources | id, research_project_id FK, source_type, canonical_url nullable, title, publisher, author nullable, published_at nullable, captured_at, language, rights_status, retrieval_status, content_hash, storage_ref nullable, trust_notes, dedupe_key |
| source_excerpts | id, source_id FK, exact_text, locator, language, anonymized, consent_or_basis nullable, extraction_run_id FK nullable |
| competitors | id, research_project_id FK, name, website nullable, category, segment_scope, positioning_summary, review_status |
| competitor_observations | id, competitor_id FK, source_excerpt_id FK nullable, dimension (hook/USP/pain/desire/ad/praise/complaint), observation_text, review_status |
| product_facts | id, product_id FK, research_project_id FK, fact_type (feature/benefit/USP/proof/limitation), text, verified_status, owner_verified_by nullable, verified_at nullable |
| product_fact_sources | id, product_fact_id FK, source_id FK nullable, source_excerpt_id FK nullable, provenance_note; check at least one reference or verified owner record |
| insight_candidates | id, research_project_id FK, audience_segment_id FK, category (pain/fear/desire/objection/firm_belief/shakable_belief/vocabulary/other), statement, status, ai_generated, frequency_count, intensity_score, urgency_score, staying_power_score, scope_score, confidence, scoring_method_version |
| insight_evidence | id, insight_id FK, source_excerpt_id FK, evidence_role (support/contradict), unique(insight_id,source_excerpt_id,evidence_role) |
| benefit_insight_links | id, insight_id FK, product_fact_id FK, rationale, review_status |
| research_assessments | id, research_project_id FK, audience_segment_id FK, assessment_type (awareness/sophistication/ideal_client/trust/market_summary), content_json, rationale, status |
| research_reports | id, research_project_id FK, version_no, status (draft/in_review/approved/superseded), report_json, report_markdown, source_manifest_hash, methodology_version_id, generated_run_id nullable, approved_by nullable, approved_at nullable, unique(research_project_id,version_no) |

## Campaign generator (logical v2 domain — design now, implement after research)

| Table | Essential fields / relationships |
|---|---|
| campaigns | id, workspace_id FK, brand_id FK, product_id FK, research_report_id FK (MUST reference approved immutable version), audience_segment_id nullable, objective, locale, channel_plan_json, state |
| idea_candidates | id, campaign_id FK, concept, dominant_desire_insight_id FK, selected_benefit_id FK, proposed_mechanism, awareness_level, sophistication_stage, rationale, score_json, status |
| idea_approvals | id, idea_candidate_id FK, reviewer_id FK, decision, note, decided_at |
| claim_registry | id, campaign_id FK, claim_text, claim_kind (product/market/comparison/promise), substantiation_status, review_note |
| claim_evidence | id, claim_id FK, source_excerpt_id nullable, product_fact_id nullable, support_type; at least one evidence reference |
| campaign_structures | id, campaign_id FK, idea_candidate_id FK, lead_family, lead_subtype, directness, angle, objections_outline_json, approval_status |
| creative_assets | id, campaign_id FK, asset_type, channel, locale, name, status, current_revision_id nullable |
| creative_revisions | id, creative_asset_id FK, version_no, content, generated_run_id nullable, editor_id nullable, review_state, cuba_review_json, created_at, unique(creative_asset_id,version_no) |
| asset_claims | id, creative_revision_id FK, claim_id FK, text_span_ref; unique(creative_revision_id,claim_id,text_span_ref) |
| campaign_packages | id, campaign_id FK, version_no, snapshot_json, exported_at, approved_by, approved_at, unique(campaign_id,version_no) |

## Important FK / consistency invariants
1. Workspace boundaries enforced on EVERY endpoint, ideally composite FK or transactional scope checks where Xano cannot implement composite FKs.
2. Every excerpt belongs to an existing source; every evidence link points to an excerpt; unsupported insights must show a visible unverified status.
3. Report approval is atomic: recheck insights, sources, reviewer role, then freeze snapshot in a transaction.
4. Campaign creation requires an **approved** report; verify project/product/workspace consistency.
5. One approved Big Idea per campaign version (or explicit new version); no ambiguous current idea.
6. Delete policy: prefer soft delete on projects; published/signed snapshots retain internal provenance subject to lawful deletion/redaction.
7. Scores are estimates, not statistical truth; store sample sizes, denominator, source diversity and calculation/version; never equate repeated viral comments with independent respondents.

## Suggested indexes
- workspace_members unique(workspace_id,user_id)
- research_sources (research_project_id,canonical_url), (research_project_id,content_hash)
- source_excerpts (source_id)
- insight_candidates (research_project_id,audience_segment_id,category,status)
- insight_evidence unique(insight_id,source_excerpt_id,evidence_role)
- research_reports unique(research_project_id,version_no)
- workflow_runs unique(workspace_id,idempotency_key)
- idea_candidates (campaign_id,status)
- creative_revisions unique(creative_asset_id,version_no)
- all FKs indexed for joins and deletion checks

## Design review outstanding
Choose workspace/role scope, external worker/queue design, source content retention, report JSON schema version and campaign output requirements before physical DDL. Any changes should update this file and DECISIONS.md.
