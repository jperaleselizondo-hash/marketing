# Phase 1A — Xano feasibility and gap analysis for Module 1 (read-only review)
Date: 2026-10-29. Status: **TECHNICAL ASSESSMENT — NOT AN APPROVED PHYSICAL SCHEMA.** No Xano writes were made.

> Founder review 2026-10-29: conditional GO for documentation consolidation and implementation planning; **NO-GO for database writes, API changes or deployment.** Table lists, endpoints, migration order and fields below are recommendations under review, not implementation authorization. The 28- vs 24-table scope is **not finalized**.
>
> **Update 2026-10-29:** the founder decisions on this review are consolidated in [10-PHASE-1-ARCHITECTURE-BASELINE.md](10-PHASE-1-ARCHITECTURE-BASELINE.md) and DECISIONS.md (ADR-009–017).
> - Scope adopted: 27 core tables (incl. existing `user`) + `invitations` = 28; `research_report_excerpts` deferred.
> - Naming in this review (`workspace_id`, `ai_jobs`, G-gates) is superseded there.
Reviews: docs/07 (proposed Module 1 schema) against docs/02 (baseline), 03, 04, 06, 08.

---

## 0. Environment audit (what was actually inspected)

| Item | Finding |
|---|---|
| Git | branch `main`, clean tree, remote `jperaleselizondo-hash/marketing` |
| Access path | Xano CLI 1.3.4 (Metadata API). No Xano MCP is configured for this repo; the one in `~/.claude.json` is registered only for the Goodz project directories. |
| Workspace targeting | Every call passed `-w 3` explicitly. **The CLI's `default` profile is pinned to workspace 1 (Goodz)**, so any command without `-w 3` would hit Goodz. |
| Identity check | `workspace get -w 3` → id 3, name "Marketing engine", created 2026-10-29 09:28 UTC, live branch `v1`, `allow_push: false`. |
| Instance | Goodz (ws 1), PMF (ws 2) and Marketing (ws 3) share the same Xano instance and the same CLI credentials. Isolation between them is procedural only, not credential-based. |
| Read-only calls made | `workspace get`, `branch list`, `function list`, `tenant list`, `knowledge list`, `workspace pull -b v1` (to a local scratch directory, without `--records` or `--env`). `sandbox get` was **not** run because it creates a sandbox. |
| Contents | Branches: `v1` (live) only. Functions, tenants, knowledge: none. Tasks: none seen in the pull. |
| **Correction to the brief** | The workspace is **not** 0 tables / 0 APIs. It contains Xano's default auth starter: table `user` (id, created_at, name, email unique, password) and API group `Authentication` with live `POST auth/signup`, `POST auth/login`, `GET auth/me`. |
| Workspace prefs | `sql_names: false` (raw SQL must use internal table names), `sql_columns: true`, `allow_push: false` (CLI push is currently blocked, which is a useful guard for now). |
| Not verifiable read-only | Plan tier, background-task limits, request timeout, data sources (live/test), whether FK references are enforced, trigger timing. See §2 spikes. |

### Immediate security findings (no data at risk yet, but fix before any data exists)
1. **Public self-signup is live.** Anyone who finds the instance URL can create an account on `auth/signup`. v1 is owner/invite-only, so replace it with an invite-only flow or remove it before any research data lands.
2. Signup inputs `email?` / `password?` are optional. The password filter (`min:8`) applies, but the unique email index allows multiple NULL emails. Make both required.
3. No login rate limiting (`redis.ratelimit` is available), 24 h tokens, and no revocation table.
4. The CLI default profile points at Goodz. **Recommendation:** create a `marketing` profile pinned to workspace 3 and run `xano profile use marketing` in this repo, which writes a local `profile.yaml` that should be git-ignored if it contains anything sensitive. Separately, there is a malformed profile literally named `xano --version`, which looks accidental; delete it at your discretion. I did not change any profiles.

---

## 1. Xano capability matrix (from Xano's XanoScript reference, developer-mcp 2.2.6)

| Need in docs/07 | Xano primitive | Verdict |
|---|---|---|
| Single-column FK | `int x_id { table = "t" }` reference field | **Metadata reference. DB-level enforcement (ON DELETE RESTRICT) is not documented.** Treat as unenforced until spike S1 shows otherwise. |
| Composite FK (`(project_id, segment_id)` must match) | none | **Not available.** Enforce in service functions. |
| Unique / composite unique | `btree|unique` with multiple fields | Supported. Postgres semantics, so NULLs are distinct (verify in S7). |
| Partial unique ("one approved report per project") | none documented | **Not available.** Use a pointer column on the parent (e.g. `research_projects.current_report_id`), which is itself unique by construction. |
| CHECK constraints ("at least one of excerpt/attestation") | none | Service layer only. |
| Constrained states | `enum` field type | Supported. Validated on write through the API layer. |
| Atomic multi-table write | `db.transaction { stack }` | Supported. |
| Race protection on approval | `db.transaction { isolation = "serializable" }`; DeadlockError catchable | Supported. Pair with an optimistic `revision` counter (see §4). |
| Row locking / job claiming | `db.direct_query` (raw SQL) | Possible (`UPDATE … WHERE status='pending' … RETURNING`, or `FOR UPDATE SKIP LOCKED`), but raw SQL needs `sql_names` or internal table names. Spike S8. |
| Append-only / immutability | no DB-level "deny update" | **Service-layer only.** Admins can still edit rows in the Xano UI. Mitigate with stored content hashes, an audit `table_trigger`, and no generic CRUD endpoints. |
| Change audit | `table_trigger` (insert/update/delete, `$new`/`$old`) | Good as a **detector** (secondary audit log). Whether it can *block* a write is unverified (S6). |
| Async jobs | scheduled `task` (freq in seconds), `run.job`, `api.request async=true` + `await` | A poller-over-jobs-table pattern is feasible. Minimum frequency, max runtime and concurrency depend on the plan (S4). Long LLM synthesis may exceed limits, so keep the external-worker option open (docs/01 already allows it). |
| Tenant scoping | `auth = "user"`, `$auth.id` | No row-level security. **Every query must filter by workspace in code** (see §3.1). |
| Branch isolation | branches version logic | **Branches are not a data or schema sandbox**, as far as the docs show; verify in S5. Use a separate data source or sandbox for tests, never live data. |
| Private file storage | `attachment` fields, cloud-storage integrations | Feasible. Confirm private-by-default and signed-URL behavior (S9). |

### Spikes required before physical DDL (each needs separate write authorization in a throwaway sandbox, not ws 3 live)
- **S1** Do `table=` references reject an orphan insert or a parent delete?
- **S2** Does a `precondition`/`throw` inside `db.transaction` roll back every prior write in that stack?
- **S3** Does serializable isolation surface a catchable conflict error under two concurrent approvals?
- **S4** Plan: task minimum frequency, max task runtime, max request duration, concurrent tasks, `api.request` timeout.
- **S5** Do branches share tables and data? Are live/test data sources available on this plan?
- **S6** Do `table_trigger`s run synchronously, inside the writing transaction, and can they abort?
- **S7** Composite unique with a nullable column: are NULLs distinct?
- **S8** `db.direct_query` inside `db.transaction` with `FOR UPDATE SKIP LOCKED`.
- **S9** Are attachments private? Do they get signed URLs, and what is the size cap?

Design below **assumes the worst case** (no FK enforcement, no DB-level immutability, no blocking triggers). If spikes show stronger guarantees, they become defense in depth, not replacements.

---

## 2. Schema mapping docs/02 → docs/07 and inconsistencies

| docs/02 | docs/07 | Issue |
|---|---|---|
| `audience_segments` | `research_segments` | Rename only. 07 drops `pains_hypothesis`. |
| `workflow_runs` | `ai_jobs` | 07 narrows to AI. Imports, fetches and report renders also need jobs. **Rename to `jobs` with `job_kind`.** |
| `audit_events` (before/after hash) | `review_events` | 07 keeps only status transitions and **loses general edit auditing and hashes**. Keep `review_events` and add `before_hash`/`after_hash`. Add trigger-based `audit_log` later. |
| `users.auth reference` | `users.auth_user_id` | Xano native auth already gives a `user` table, so **extend it** and drop `auth_user_id`. |
| `research_sources.author` | dropped | **Regression.** Without an author/handle you cannot compute `independent_source_count` or detect one person posting many times. Restore it as a pseudonymised `speaker_ref`/`author_hash`. |
| `source_excerpts.anonymized`, `consent_or_basis`, `extraction_run_id` | `redacted`, `excerpt_hash`; basis and job dropped | **Privacy and lineage regression.** Restore `lawful_basis`, `contains_pii`, and the `extracted_by_job_id` link. |
| `product_facts` + `product_fact_sources` | `product_capabilities`, `product_benefits`, `capability_benefit_links`, `product_proofs` | Better. `product_benefits` lacks `product_id`. It is fine if one project means one product, but state that rule explicitly. |
| `insight_candidates` (scores inline) | `research_insights` + `insight_rankings` | Better separation. 02's `frequency_count` becomes `evidence_count`. |
| `insight_evidence` → excerpt | `insight_support` → observation | Intentional (observation layer). OK. |
| `benefit_insight_links` | `benefit_desire_links` | OK. Only desire insights may be linked (service check). |
| `competitor_observations.dimension` hook/USP/pain/desire/ad/praise/complaint | idea/usp/pain_focus/desire_focus/social_media/ads/praise/complaint | 07 matches the spreadsheet. Accept 07. |
| `research_assessments` types incl. `ideal_client`, `trust` | awareness/sophistication/market_context/competitive_summary | **Methodology gap.** Notion playbook 1 covers ideal-customer and trust research. Restore `ideal_client` and `trust`. |
| — | `research_report_sources` | New, good. Also add the excerpt manifest (see §3.6). |

### Taxonomy conflicts to resolve (owner decision)
- **IVOC categories.** `observation_categories` has 7 values (pain_fear, desire, objection, firm_belief, shakable_belief, vocabulary, other) and matches the spreadsheet. `research_insights.insight_type` has a different 6 (merges beliefs, drops `other`, adds `opportunity`). Proposal: insight_type = the same 7 plus `opportunity`. Do not collapse firm vs shakable beliefs, because the methodology treats them differently.
- **observation_type.** docs/06 says `synthesis`, docs/07 says `secondary_summary`. Pick one. Proposal: `secondary_summary` (synthesis is the insight layer's job).
- **hypothesis_only.** docs/07 invariant 5 needs it, but it is not in the `research_insights.status` enum. Proposal: add a boolean `is_hypothesis` (not a status), so a hypothesis can still be reviewed, approved or rejected.
- **Gate numbering.** docs/01 uses G0–G6 (G3 = report frozen); docs/08 uses G1–G6 (G2 = report approved). Pick one numbering before it is encoded into enums and UI.
- **Project lifecycle.** docs/03 defines `draft → scoped → collecting → evidence_review → synthesizing → report_review → approved`, but 07 has no `research_projects.status` enum. Also "approved" is a report property, not a project state (03 says so itself). See §5.

---

## 3. Missing relational constraints and transaction checks

### 3.1 Tenancy (highest priority)
- **Denormalise `workspace_id` onto every workspace-owned table**, set server-side from the parent at insert and never updatable. Xano has no composite FKs or RLS, so this is what makes "every query filters `workspace_id = $ctx.workspace_id`" cheap and auditable. Add a `(workspace_id, …)` leading index to hot tables. This answers docs/07 §9, bullet 2: **yes**.
- Also denormalise `research_project_id` onto excerpts and categories (today they reach the project only through source or observation), so cross-project checks are a single equality.
- One shared function, `ctx_resolve(workspace_id, min_role)`, runs at the top of every endpoint. It loads the membership for `$auth.id`, fails with `accessdenied` if missing or too low, and returns the context. A client-supplied workspace_id is only a *selector*, never proof.
- Every child-by-id fetch is `db.get` followed by a precondition `row.workspace_id == ctx.workspace_id`, returning **404, not 403**, to avoid confirming existence.
- `products` needs `workspace_id`. Today it reaches the workspace only via `brands`.
- `methodology_versions` is global. Approving one needs a **platform-admin** role that sits outside workspace roles. Add `user.is_platform_admin`.

### 3.2 Cross-row consistency checks (service functions, in-transaction)
| Write | Must assert |
|---|---|
| research_projects insert | product.workspace_id == ctx.ws; methodology_version.status == published |
| research_segments | unique(project_id, name) |
| source_excerpts insert | source.project_id == excerpt.project_id; **exact_text found in the stored source content** (normalised match), or flagged `verification_status=pending_human` |
| research_observations | `verbatim_quote` ⇒ excerpt_id NOT NULL and excerpt.verification_status=verified; segment.project_id == obs.project_id |
| observation_categories | unique(observation_id, category) |
| insight_support | insight.project == obs.project; obs.segment ∈ {insight.segment, NULL-with-reviewer-note}; unique(insight_id, observation_id, stance) |
| insight_rankings | insight.project/segment == ranking.project/segment; unique(project, segment, insight_id); unique(project, segment, priority_rank) unless `tie_rule` set |
| capability_benefit_links | capability.project == benefit.project; unique(capability_id, benefit_id) |
| benefit_desire_links | insight.insight_type == desire; insight.segment == link.segment; benefit.project == insight.project |
| product_proofs | (excerpt_id OR owner_attestation_text) NOT NULL; excerpt.project == proof.project |
| competitor_observations | competitor.project == excerpt.project; analyst_note never copied into observed_claim |

### 3.3 Fields to add
- `source_excerpts`: `verification_status` (pending/verified/failed/pending_human), `verified_by`, `verified_at`, `verification_method`, `supersedes_excerpt_id`, `speaker_ref` (pseudonymised), `extracted_by_job_id`. Unique `(source_id, excerpt_hash)`.
- `research_sources`: `author_ref` (pseudonymised), `lawful_basis`, `contains_pii`, `retention_until`, `license_note`. Unique `(project_id, dedupe_key)`, where `dedupe_key` = sha256 of the canonicalised URL, or of the content hash if there is no URL.
- `research_observations`, `research_insights`: `generated_by_job_id`, `revision` int.
- `research_projects`: `status`, **`content_revision` int** (see §4), `current_report_id` (nullable, added last because it creates a circular FK), `ai_budget_usd`.
- `research_reports`: `based_on_revision` int, `report_json_hash`, `schema_version`.
- `jobs`: `job_kind`, `lease_owner`, `lease_expires_at`, `next_attempt_at`, `max_attempts`, `cost_usd`, `input_tokens`, `output_tokens`, `input_ref`, `output_json`, `output_schema_version`, `validation_errors`.
- `review_events`: `before_hash`, `after_hash`, `idempotency_key` unique per workspace.

### 3.4 Idempotency
- `jobs`: unique(workspace_id, idempotency_key). The key is derived server-side, e.g. hash(kind, project, input_hash), so double-clicks and retries collapse onto one row.
- Imports: unique(import_batch_id, sheet_name, cell_ref, value_index). `value_index` handles merged or multi-value cells (docs/07 invariant 9).
- Transitions: re-sending "approve" on an already-approved row returns the existing result, not an error and not a second event.

### 3.5 Score uncertainty
`insight_rankings` must store `evidence_count`, `independent_source_count`, `independent_speaker_count`, `sample_denominator`, `scoring_rubric_version`, and per-score `basis` (human/ai_proposed). The UI must label these figures "in the collected sample". Independence needs `speaker_ref`/`author_ref`, which is why their removal is a blocker.

### 3.6 Snapshot immutability
- `report_json` embeds the **text** of every cited excerpt, not just IDs, so the frozen report survives later excerpt redaction.
- `research_report_sources` keeps `content_hash_at_approval`. Add `research_report_excerpts(report_id, excerpt_id, excerpt_hash_at_approval)` so docs/03's test "quote changed after approval → detectable mismatch" is a query, not a recomputation.
- `report_json_hash` is stored at approval. `GET /reports/{id}/verify` recomputes it to detect out-of-band edits (e.g. via the Xano admin UI).
- Lawful deletion of an excerpt in an approved report goes through a governed `redaction` event that replaces the text with a tombstone and records the reason. It never deletes silently.

---

## 4. Transactional review gates (Xano-feasible pattern)

**Problem:** docs/07 invariant 7 requires that a report approval racing with an evidence edit is rejected as stale. Row locks are awkward in Xano.

**Pattern: project-level optimistic revision + serializable transaction.**
1. Every write to project-scoped research data (sources, excerpts, observations, categories, insights, support, rankings, links, assessments) runs inside `db.transaction` and increments `research_projects.content_revision`.
2. Report generation records `based_on_revision = content_revision` at the moment it reads.
3. `POST /reports/{id}/approve` runs in `db.transaction { isolation = "serializable" }`:
   - ctx role ≥ reviewer, and reviewer ≠ generator when policy requires it;
   - report.status == in_review;
   - project.content_revision == report.based_on_revision; **otherwise fail `stale_report`**;
   - zero blocking validations: every cited insight approved, with ≥1 support link or `is_hypothesis`; every verbatim excerpt verified; every manifest source has a content_hash;
   - recompute and store manifest hashes and `report_json_hash`;
   - previous approved report → `superseded`; project.current_report_id = this report;
   - insert `review_events`.
   On a serialization conflict, return 409 to the client; it should not auto-retry an approval.
4. Concurrent edits bump the revision inside their own transaction, so exactly one of the two commits wins. This satisfies the docs/03 and docs/07 race tests without row locks, **conditional on spikes S2 and S3**.

The same pattern applies to `insight approve` (checks support links) and `excerpt verify`.

---

## 5. State machines (Phase 1)

```
research_project: draft → scoped → collecting ⇄ synthesizing → archived
                  (report review/approval lives on research_reports, not here)
research_source:  captured → excerpted → reviewed | rejected   (retrieval_status separate: ok/failed/gone)
source_excerpt:   pending → verified | failed | pending_human → verified|failed   (immutable after verified; correction = new excerpt with supersedes_excerpt_id)
observation:      unclassified → classified → reviewed | rejected
                  provenance_status: unverified → verified (only via verified excerpt) | disputed
insight:          candidate → reviewed → approved | rejected ; approved → candidate only via explicit reopen (bumps revision, logs reason)
report:           draft → in_review → approved → superseded ; in_review → draft (rejected with reason)
job:              pending → running → succeeded | failed_retryable → pending (backoff) | failed_final | cancelled
                  running with expired lease → failed_retryable (poller reclaims)
```
Every transition is a named endpoint (`/approve`, `/reject`, `/reopen`), never a PATCH of `status`. Each one checks role and current state in-transaction and writes `review_events`.

---

## 6. Minimum viable Phase 1 physical schema

**Recommendation: Phase 1 ships the evidence and report path with humans entering the evidence and AI added later as a proposal source.** AI extraction then lands in 1B as rows with `generated_by_job_id` and status `candidate`/`pending`, which reviewers act on through the same gates. This proves provenance, tenancy and approval before any model cost or prompt-injection exposure.

| Group | Phase 1 (28 tables) | Deferred to 1B |
|---|---|---|
| Tenancy | `user` (extend existing), `workspaces`, `workspace_members`, `brands`, `products`, `methodology_versions` | — |
| Execution / audit | `jobs` (used first for report rendering), `review_events` | `audit_log` via table_triggers |
| Project | `research_projects`, `research_segments` | `research_questions` |
| Provenance | `research_sources`, `source_excerpts`, `research_observations`, `observation_categories` | `import_batches` (historical spreadsheet: its provenance is weak and it needs the import policy first) |
| Product | `product_capabilities`, `product_benefits`, `capability_benefit_links`, `product_proofs` | — |
| Competitors | `competitors`, `competitor_observations` | — |
| Synthesis | `research_insights`, `insight_support`, `insight_rankings`, `benefit_desire_links`, `research_assessments` | — |
| Report | `research_reports`, `research_report_sources`, `research_report_excerpts` | — |

That list has 28 tables. A leaner 24-table MVP is possible if competitors (2), product_proofs and research_report_excerpts are moved to 1B. **Owner call:** I recommend keeping all 28, because the Goodz report needs the competitor matrix and the claim substrate, and none of these tables is hard to build.

ID type: Xano `int` auto-increment for all PKs (native, matches `user`). Expose no sequential IDs publicly; everything is behind auth plus workspace checks.

---

## 7. Phase 1 API surface (all `auth = "user"`, all through `ctx_resolve`)

Shared functions (built first): `ctx_resolve`, `assert_same_project`, `bump_revision`, `log_review_event`, `hash_canonical_json`, `paginate`.

| Domain | Endpoints | Min role |
|---|---|---|
| Workspace | `GET /workspaces` (mine), `GET /workspaces/{id}/members` | viewer |
| Catalog | `POST/GET /brands`, `POST/GET /products` | editor / viewer |
| Projects | `POST /projects`, `GET /projects/{id}`, `POST /projects/{id}/transition` | editor |
| Segments | `POST/GET/PATCH /projects/{id}/segments` | editor |
| Sources | `POST /sources` (dedupe → returns existing on conflict), `GET /projects/{id}/sources`, `POST /sources/{id}/reject` | editor |
| Excerpts | `POST /excerpts`, `POST /excerpts/{id}/verify`, `POST /excerpts/{id}/supersede` | editor / **reviewer** for verify |
| Observations | `POST/GET/PATCH /observations`, `PUT /observations/{id}/categories` | editor |
| Product | `POST/GET/PATCH capabilities, benefits`, `POST /capability-benefit-links`, `POST /proofs`, `POST /capabilities/{id}/verify` | editor / reviewer |
| Competitors | `POST/GET /competitors`, `POST/GET /competitor-observations` | editor |
| Insights | `POST/PATCH /insights`, `POST /insights/{id}/support`, `POST /insights/{id}/approve|reject|reopen`, `PUT /projects/{id}/rankings` | editor / reviewer |
| Assessments | `POST/PATCH /assessments`, `POST /assessments/{id}/approve` | editor / reviewer |
| Reports | `POST /projects/{id}/reports` (enqueue render job), `POST /reports/{id}/submit|approve|reject`, `GET /reports/{id}`, `GET /reports/{id}/verify` | editor / reviewer |
| Jobs | `GET /jobs/{id}` | viewer |
| Auth | replace `auth/signup` with owner-issued invites; keep login/me with rate limiting | — |

There are no generic CRUD endpoints on approved or immutable rows. Errors use one envelope `{code, message, details}` with codes `not_found | forbidden | invalid_state | stale_report | validation_failed | duplicate`.

---

## 8. Physical migration order (after approval and after spikes)

- **M0 Environment (no schema):** dedicated CLI profile; decide data sources/sandbox for tests; disable public signup; add login rate limit; decide `sql_names`; adopt XanoScript files in this repo under `xano/` with `allow_push` enabled only when a push is authorized.
- **M1 Tenancy:** extend `user` → `workspaces` → `workspace_members` → `brands` → `products` → `methodology_versions`; shared `ctx_resolve`.
- **M2 Project and execution:** `research_projects` (without `current_report_id`) → `research_segments` → `jobs` → `review_events`.
- **M3 Provenance:** `research_sources` → `source_excerpts` → `research_observations` → `observation_categories`.
- **M4 Product and competitors:** capabilities → benefits → links → proofs → competitors → competitor_observations.
- **M5 Synthesis:** insights → support → rankings → benefit_desire_links → assessments.
- **M6 Reports:** reports → report_sources → report_excerpts → add `research_projects.current_report_id`.
- **M7 Async:** job poller task, lease reclaim, then (1B) AI extraction jobs and `import_batches`.

Each step ships its endpoints and its tests from docs/03 and docs/07 before the next step starts. Cross-tenant tests use two seeded workspaces from M1 onward.

---

## 9. CLAUDE.md review checklist

| Item | Status |
|---|---|
| Data model integrity | Feasible via service-layer checks (§3.2). The DB alone will not enforce it. |
| Tenant isolation | Feasible. Requires denormalised `workspace_id` + `ctx_resolve` on every endpoint. **Public signup must go first.** |
| Source provenance | 07 is good. Restore author/speaker, lawful basis and the extraction-job link. |
| IVOC taxonomy | Conflict between observation and insight enums (§2). Owner decision. |
| Score uncertainty | Needs speaker independence fields and sample denominators (§3.5). |
| Async reliability | Jobs table + lease poller feasible. Limits unknown (S4). External worker remains the fallback. |
| Privacy / licensing | 07 regressed: restore `lawful_basis`, `contains_pii`, `retention_until`, `license_note`. |
| Big Idea approval / claims | Out of Phase 1 (Module 2). `product_proofs` provides the substantiation substrate. |
| AI output validation | Deferred to 1B by design. Jobs store `output_schema_version` and `validation_errors`. |
| Snapshot immutability | Service-layer + hash verification. Not DB-enforced: Xano admins can edit rows. |
| Reviewer correction UX | Supersede, don't edit (excerpts); reopen with reason (insights); every change in `review_events`. |
| Cost / runtime budgets | `jobs.cost_usd`/tokens + `research_projects.ai_budget_usd` checked at enqueue. |

---

## 10. Decisions requested from the founder
1. Approve the corrections to docs/07: restore author/speaker, privacy and job-lineage fields; add `workspace_id` everywhere; rename `ai_jobs` to `jobs`.
2. IVOC enum unification, the `observation_type` name, `is_hypothesis` flag, and which gate numbering to keep.
3. Phase 1 = human-entered evidence first, AI extraction in 1B? (recommended)
4. MVP scope: 28 tables (recommended) or 24.
5. Authorize **spikes S1–S9** in a throwaway sandbox or test data source, not ws 3 live. These are the first writes and need explicit approval.
6. Authorize M0 hygiene: dedicated CLI profile, and removing or replacing the live public `auth/signup` in ws 3.
7. Xano plan tier and any known task/timeout limits, if you have them.
