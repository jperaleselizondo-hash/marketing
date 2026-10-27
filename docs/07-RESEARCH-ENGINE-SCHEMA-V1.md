# Module 1 — Deep Research Engine: logical schema V1 (review candidate)
Status: **PROPOSED, NOT APPROVED FOR IMPLEMENTATION**. Updated 2026-10-27.
Supersedes the *Module 1 portion* of docs/02-DATA-MODEL.md when accepted. This is a logical relational design, not Xano DDL.

## 0. Domain and workflow
Workspace → Brand → Product → Research Project → Audience Segments.
Research Project → Sources → Excerpts/Observations → Insights → Prioritization → Approved Research Report.
Product → Capabilities → Benefits → (evidenced) customer desires.
Competitors → Observations and evidence.
Report versions are immutable; campaigns later bind a specific approved version.

Scope: one project may have multiple segments, regions and languages; **all observations, insights and rankings must remain segment-aware**. For Goodz, buyers and suppliers are distinct segments. Avoid forced joins of unrelated spreadsheet cells.

## 1. Universal conventions
- PK `id`: consistent Xano-compatible ID type selected during physical design.
- Business tables have `created_at`, `updated_at`; soft-delete `deleted_at` only where explicitly required.
- Required FKs must be non-null; all FKs indexed; enforce workspace scope server-side on reads, writes, imports, exports and background jobs.
- Store `status` as constrained values; no free-text states. Each transition validates actor role and current state transactionally.
- Do not use JSON arrays of foreign IDs. JSON is reserved for snapshots, provider metadata and flexible configuration.
- User content is never translated in place. `language_code` retained on source, observation and report.
- Derived AI scores include rubric version, method, sample size and uncertainty. Scores are not population prevalence.
- No raw credentials in database records, logs, prompts or GitHub.

## 2. Identity, tenancy and execution

| Table | Key columns | Constraints |
|---|---|---|
| `workspaces` | id, name, status | unique slug if added |
| `users` | id, auth_user_id, display_name, status | unique(auth_user_id) |
| `workspace_members` | id, workspace_id FK, user_id FK, role | unique(workspace_id,user_id); role owner/editor/reviewer/viewer |
| `brands` | id, workspace_id FK, name, default_locale | workspace-scoped |
| `products` | id, brand_id FK, name, description, lifecycle_status | no product claims automatically considered verified |
| `methodology_versions` | id, key, version, source_url, source_hash, instructions_ref, status, approved_by, approved_at | unique(key,version); published versions immutable |
| `research_projects` | id, workspace_id FK, product_id FK, title, objective, target_geography, target_locale, status, owner_id FK, methodology_version_id FK | verify product's brand belongs to workspace |
| `research_segments` | id, research_project_id FK, name, buyer_or_supplier_role, geography, locale, awareness_hypothesis, description | unique(project,name) |
| `research_questions` | id, research_project_id FK, research_segment_id FK nullable, question, priority, status | question can apply to whole project |
| `ai_jobs` | id, workspace_id FK, project_id FK, stage, status, idempotency_key, input_hash, prompt_version, model_id, schema_version, attempt_count, usage_json, error_code, started_at, finished_at | unique(workspace_id,idempotency_key); retryable jobs idempotent |
| `review_events` | id, workspace_id FK, actor_id FK, entity_type, entity_id, from_status, to_status, decision, reason, created_at | append-only |
| `import_batches` | id, research_project_id FK, filename, file_hash, imported_by FK, imported_at, status, mapping_version | file stored privately, not GitHub |

## 3. Product investigation — preserve the spreadsheet's capability → benefit → desire chain

| Table | Key columns | Constraints |
|---|---|---|
| `product_capabilities` | id, product_id FK, research_project_id FK, capability_type (feature/service/performance/limitation), description, verification_status, verified_by nullable | source/owner verification required before factual claims |
| `product_benefits` | id, research_project_id FK, benefit_text, benefit_type, review_status | benefits may depend on multiple capabilities |
| `capability_benefit_links` | id, capability_id FK, benefit_id FK, rationale | unique(capability_id,benefit_id) |
| `product_proofs` | id, research_project_id FK, capability_id FK nullable, benefit_id FK nullable, source_id FK nullable, evidence_excerpt_id FK nullable, owner_attestation_text nullable, proof_type, review_status | require evidence or documented attestation; scope check |
| `benefit_desire_links` | id, benefit_id FK, insight_id FK, research_segment_id FK, rationale, review_status | insight must be desire-category and belong to same project/segment |

Do not create a generic global `human_desires` table as if a taxonomy were verified market demand. Optional methodology-controlled desire tags can be stored separately; actual market desires must be evidence-backed insights.

## 4. Acquisition, provenance and observations

| Table | Key columns | Constraints |
|---|---|---|
| `research_sources` | id, research_project_id FK, source_kind (public_web/interview/survey/customer_document/competitor_asset/import/owner_attestation), canonical_url nullable, title, publisher nullable, published_at nullable, captured_at, language_code, rights_status, retrieval_status, content_hash nullable, storage_ref nullable, dedupe_key nullable | source uniqueness only when canonical identity known; imported material can lack URL |
| `source_excerpts` | id, source_id FK, exact_text, locator, captured_at, language_code, redacted, excerpt_hash | immutable raw transcription after validation; changes create new version/excerpt |
| `research_observations` | id, research_project_id FK, research_segment_id FK nullable, source_excerpt_id FK nullable, import_batch_id FK nullable, sheet_name nullable, cell_ref nullable, original_text, observation_type (verbatim_quote/paraphrase/analyst_hypothesis/secondary_summary), provenance_status (verified/unverified/disputed), classification_status, created_by FK nullable | verbatim_quote requires linked excerpt; imported unsupported notes remain unverified |
| `observation_categories` | id, observation_id FK, category (pain_fear/desire/objection/firm_belief/shakable_belief/vocabulary/other), confidence, reviewer_id nullable | one observation may have multiple categories; unique(observation_id,category) |
| `competitors` | id, research_project_id FK, name, website nullable, alternative_type (direct/indirect/substitute), status | unique(project,name) after normalized matching |
| `competitor_observations` | id, competitor_id FK, source_excerpt_id FK nullable, research_observation_id FK nullable, dimension (idea/usp/pain_focus/desire_focus/social_media/ads/praise/complaint), observed_claim, analyst_note, provenance_status, review_status | competitor claims ≠ independent proof; analyst_note explicitly separate |

**Import rule:** spreadsheet column alignment does not imply common respondent or common source. Store original cell addresses and text. Never auto-create source quotes from unsupported notes. Excerpts may be limited by copyright and retention policies.

## 5. Synthesis and research decisions

| Table | Key columns | Constraints |
|---|---|---|
| `research_insights` | id, research_project_id FK, research_segment_id FK, insight_type (pain_fear/desire/objection/belief/vocabulary/opportunity), statement, status (candidate/reviewed/approved/rejected), confidence, generated_by_job_id FK nullable, reviewer_id FK nullable | no approval without evidence or explicit `hypothesis_only` designation |
| `insight_support` | id, insight_id FK, observation_id FK, stance (support/contradict), reviewer_note | unique(insight_id,observation_id,stance); scope and segment consistency |
| `insight_rankings` | id, research_project_id FK, research_segment_id FK, insight_id FK, priority_rank, urgency_score nullable, intensity_score nullable, staying_power_score nullable, scope_score nullable, evidence_count, independent_source_count, scoring_rubric_version, rationale, reviewed_by FK nullable | unique(project,segment,insight_id); rank may tie only with explicit rule |
| `research_assessments` | id, research_project_id FK, research_segment_id FK nullable, assessment_type (awareness/sophistication/market_context/competitive_summary), assessment_json, confidence, rationale, review_status | must identify audience and evidence basis |
| `research_reports` | id, research_project_id FK, version_no, status (draft/in_review/approved/superseded), schema_version, report_json, report_markdown, source_manifest_hash, methodology_version_id FK, generated_job_id FK nullable, approved_by FK nullable, approved_at nullable | unique(project,version_no); approved payload immutable |
| `research_report_sources` | id, report_id FK, source_id FK, content_hash_at_approval nullable | unique(report_id,source_id); preserves source manifest |

**Important:** An `insight` is an analyst synthesis, never a verbatim quote. Its evidence graph points to `research_observations`, which may point to immutable `source_excerpts` and `research_sources`. Hypothesis-only insights can appear in the report's gaps/ideas section but cannot be portrayed as established customer sentiment.

## 6. Referential integrity and review invariants
1. Enforce transitive project/workspace consistency on every cross-table join; validate in transactional service functions if DB composite FK unsupported.
2. `benefit_desire_links` must reference a desire insight from the same project/segment. Never link one buyer's desire to supplier benefit without explicit cross-segment rationale and separate approved mapping.
3. `source_excerpts.exact_text` cannot be AI-generated. AI can propose extraction, but a verification step compares excerpt to source text before marking verified.
4. `research_observations.observation_type=verbatim_quote` requires `source_excerpt_id` and verified provenance.
5. `research_insights.status=approved` requires at least one reviewed support link, unless explicitly approved as hypothesis-only with visible caveat (separate status/flag in physical schema).
6. Counts are independent observations/sources in the collected sample, not percentages of a market. Deduplicate cross-posts before ranking.
7. Approval of a report requires authorized reviewer, no unresolved blocking errors, verified source manifest, and an atomic snapshot of approved insights and mappings. Concurrency guard/lock rechecks version at commit.
8. Approved reports are immutable. Revisions create `version_no+1`; downstream campaign uses a specific report id and must detect supersession.
9. Imports must be idempotent by (import_batch, sheet_name, cell_ref), with collision policy for merged cells/multiple values.
10. Every research query/export is workspace-scoped and authorized. No global user enumeration.

## 7. Report contract and acceptance checks
Report must include: scope/objective; product capability–benefit–desire matrix; audience segments; market awareness/sophistication with rationale; competitor-by-dimension matrix; IVOC category summary with verbatim source excerpts distinguished from analyst notes; ranked insights and benefit fit; supporting/contradicting evidence; data limitations; campaign implications; sources appendix; approval metadata.

Minimum validation tests:
- Cross-tenant reads/writes/imports rejected.
- Unsupported spreadsheet note stays `unverified`; cannot become verified quote by AI.
- Feature→benefit→desire links resolve only within project/segment.
- Duplicate imported cell and duplicate research job are idempotent.
- Source extraction with forged quote fails verification.
- Contradicting evidence survives synthesis.
- Report approval races with source/insight edit: one transaction wins, other fails stale.
- Approved report cannot be mutated; next revision creates new version.
- Draft report cannot be used to create a campaign.
- Reports with no data label conclusions as hypotheses, not research findings.

## 8. Physical schema build order (after approval)
A. tenancy, products, projects, segments, methodology versions, job runs;
B. sources, excerpts, import batches, observations and categories;
C. capabilities, benefits, proof, competitor observations;
D. insights, support, rankings, benefit links and assessments;
E. report versions, source manifest, approval events.

## 9. Open decisions for Claude's read-only technical review
- Confirm Xano plan, workspace ID, branch isolation, DB constraints, transactional primitives, async task limits, file storage, and access controls.
- Evaluate whether `workspace_id` should be repeated on high-volume child tables for composite indexes / authorization.
- Determine Xano-safe implementation for append-only review events and immutable report snapshots.
- Choose exact enum and score scale definitions, independent-source deduplication, nullable audience scope, consent/retention.
- Propose minimal v1 tables vs future-ready logical schema; do not sacrifice provenance or authorization.
- Produce a mapping from existing docs/02-DATA-MODEL.md to this schema and list any inconsistent table names.
- **No Xano writes until owner explicitly approves physical schema and environment.**
