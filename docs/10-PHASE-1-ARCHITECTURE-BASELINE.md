# Phase 1 architecture baseline — Research Engine and M0 security
Date: 2026-10-29. Founder decision: **GO for architecture consolidation and M0 preparation. NO-GO for Xano writes, table creation, endpoint changes, credential configuration, tests or deployment.**

> **Update 2026-10-29: implemented.** A later founder decision (ADR-018) authorized direct development on workspace 3 `v1`.
> - The conceptual decisions here stand.
> - The physical schema, API, M0 security, verification answers (§8) and deviations are recorded in [11-PHASE-1-IMPLEMENTATION.md](11-PHASE-1-IMPLEMENTATION.md), which wins over this document's [PROPOSED]/[UNVERIFIED] items.
> - The sandbox/spike plan in §8–§9 was superseded and not executed.

This document consolidates the founder decisions taken on [09-PHASE-1A-XANO-FEASIBILITY-REVIEW.md](09-PHASE-1A-XANO-FEASIBILITY-REVIEW.md). Where it conflicts with docs/02, 07 or 08, **this document wins**. Every section carries one status label:

| Label | Meaning |
|---|---|
| **[APPROVED]** | Approved conceptual decision. Changing it needs a new founder decision and a DECISIONS.md entry. |
| **[PROPOSED]** | Proposed physical schema or implementation detail. Not approved for creation. |
| **[UNVERIFIED]** | Technical assumption about Xano not yet demonstrated. Design must not depend on it. |
| **[DEFERRED]** | Out of Phase 1 scope by decision. |
| **[AWAITING AUTH]** | Change fully specified, waiting for explicit implementation authorization. |

---

## 1. Research workflow — [APPROVED]
- **Phase 1A:** human-entered evidence and human review only. No AI writes.
- **Phase 1B:** AI-assisted extraction produces **proposals** that require human acceptance before they count as verified evidence.
- AI-generated interpretations remain distinguishable from source evidence at all times (see §2.3).
- Three structurally distinct layers, never stored in the same table or field:

| Layer | Tables | Rule |
|---|---|---|
| **Source evidence** | `research_sources`, `source_excerpts`, `research_observations` where `observation_type = verbatim_quote` | Faithful to the source. Never AI-authored text. Verified against the source. |
| **Interpretation** | `research_observations` (paraphrase / secondary_summary / analyst_hypothesis), `observation_categories`, `research_insights`, `insight_support`, `insight_rankings`, `research_assessments`, `benefit_desire_links`, `competitor_observations.analyst_note` | Analyst or AI synthesis. Always labelled with origin and evidence basis. |
| **Campaign claims** | Module 2/3 (`claim_registry`/equivalent, **[DEFERRED]**) | May only cite evidence through `product_proofs`, `source_excerpts` and an approved report version. |

## 2. Canonical research taxonomy — [APPROVED]

### 2.1 IVOC categories (`ivoc_category`, shared by observations and insights)
`pain_fear | desire | objection | firm_belief | shakable_belief | vocabulary | other`
- Pains and fears stay **combined** in V1.
- Reconciliation with the Spanish methodology guide remains open (DECISIONS open item 6).

### 2.2 Insight kind (`insight_kind`)
`ivoc_theme | opportunity`. An opportunity is analyst output, never an IVOC category.

### 2.3 Origin and AI provenance
- `origin`: `human_entered | imported | ai_proposed`, on every content table.
- `generated_by_job_id` is required when `origin = ai_proposed`.
- `accepted_by` / `accepted_at` are required before an `ai_proposed` row can reach any verified, reviewed or approved state.
- `source_excerpts.exact_text` is never accepted from AI without verification against stored source content.

### 2.4 Observation type (`observation_type`)
`verbatim_quote | paraphrase | secondary_summary | analyst_hypothesis`.
- `verbatim_quote` requires a verified `source_excerpt_id`.

### 2.5 Evidence basis (`evidence_basis`, on insights)
`evidenced | hypothesis`.
- This is independent of review status.
- `evidenced` requires ≥1 reviewed `support` link.
- An approved `hypothesis` appears only in the report's gaps and hypotheses section.

### 2.6 Attribution
- `author_ref` (on sources) and `speaker_ref` (on excerpts and observations) are pseudonyms that stay stable within one organization.
- Each is a keyed hash of platform + handle, with a per-organization secret. **The hashing scheme is [PROPOSED].**
- `speaker_role`: `buyer | supplier | prospect | customer | competitor | expert | owner | unknown`.
- Raw handles are not stored in V1. Independence counts use these refs.

### 2.7 Assessments
- `assessment_type`: `awareness | sophistication | ideal_client | trust | market_context | competitive_summary`.
- `awareness_level`: `unaware | problem_aware | solution_aware | product_aware | most_aware`.
- `sophistication_stage`: `1–5`, **provisional** pending reconciliation with the original methodology. Assessed **per segment**.

### 2.8 Competitors
- `alternative_type`: `direct | indirect | substitute`.
- `dimension`: `idea | usp | pain_focus | desire_focus | social_media | ads | praise | complaint`.
- `observed_claim` (what the competitor says) and `analyst_note` (our interpretation) are separate fields. A competitor claim is never independent proof.

## 3. Privacy, provenance and rights model — [APPROVED principle] / [PROPOSED fields]
The founder rejected a single `lawful_basis` enum. Five independent dimensions are recorded instead. **All legal classifications require jurisdiction-specific review by qualified counsel.** The values below are engineering placeholders. The system *records* determinations; it does not make them.

| # | Dimension | Proposed fields (on `research_sources`; † = excerpt-level override) | Notes |
|---|---|---|---|
| 1 | **Legal basis for personal-data processing** | `processing_basis_code` (text, validated against a counsel-approved, versioned code list), `processing_basis_jurisdiction` (e.g. `MX`, `EU`), `processing_basis_status` (`not_applicable \| undetermined \| proposed \| legally_reviewed`), `processing_basis_reviewed_by`, `processing_basis_reviewed_at`, `privacy_policy_version` | Deliberately **not** an enum: bases differ by jurisdiction (e.g. Mexico's data-protection regime vs GDPR Art. 6). Only meaningful when personal data is present. |
| 2 | **Source provenance and acquisition** | `source_kind` (existing), `acquisition_method` (`manual_capture \| owner_upload \| interview_record \| survey_export \| crm_export \| spreadsheet_import \| automated_fetch`), `access_conditions` (`public_no_login \| login_required \| paywalled \| privately_shared`), `acquired_by`, `captured_at`, `terms_note` | `automated_fetch` is Phase 1B. Login-walled or paywalled scraping is excluded in v1 (docs/01). |
| 3 | **Content usage and quotation rights** | `usage_rights` (`internal_analysis_only \| paraphrase_permitted \| quote_anonymized_permitted \| quote_attributed_permitted \| prohibited \| undetermined`) †, `usage_rights_basis`, `license_ref` | Internal analysis and external publication are different uses. Module 3 must re-check before any quote appears in an asset. |
| 4 | **Personal-data classification** | `personal_data_class` (`none \| pseudonymized \| identifiable \| special_category \| undetermined`) †, `redaction_status` † | `special_category` blocks inclusion pending explicit policy. |
| 5 | **Retention** | `retention_rule_code`, `retention_until`, `deletion_status` (`active \| scheduled \| redacted \| tombstoned`) | Redaction of an excerpt cited by an approved report goes through a governed redaction event (docs/09 §3.6). |

**Fail-closed rules [APPROVED principle]:**
- An excerpt is excluded from an approved report if it contains personal data and `processing_basis_status ∈ {undetermined}`.
- An excerpt is also excluded if `usage_rights ∈ {prohibited, undetermined}`.
- It may still be counted in internal statistics only if `usage_rights ≠ prohibited`. **This last sub-rule needs counsel confirmation.**

## 4. Naming, review vocabulary and gates — [APPROVED]

### 4.1 Naming
- **`organizations`** is the application tenancy entity, with `organization_members` and `organization_id`. "Workspace" now refers **only** to the Xano workspace (ID 3).
- `jobs` (with `job_type`) replaces `ai_jobs`/`workflow_runs`.
- Other conventions: snake_case plural tables; FK `<singular>_id`; `*_at` timestamps; `*_on` dates; `is_*`/`has_*` booleans; `*_status` lifecycles; `*_type` classifications (plus the approved `insight_kind`); `*_hash` (sha256 hex); `*_ref` pseudonyms; `*_score` + `scoring_rubric_version`; link tables `<a>_<b>_links`.
- `research_segments` is retained. `review_events` is retained. `audit_log` is **[DEFERRED]**, pending trigger verification.

### 4.2 Review vocabulary
- Shared review states: `candidate → in_review → approved | rejected`, plus `superseded` for versioned artifacts.
- Entity-specific lifecycles only where needed:
  - **jobs:** `pending, running, succeeded, failed_retryable, failed_final, cancelled`
  - **excerpt verification:** `pending, verified, failed, pending_human`
  - **projects:** `draft, scoped, collecting, synthesizing, archived`
  - **invitations:** `pending, accepted, revoked, expired`

### 4.3 Approval gates (stable identifiers)
| Code | Module | Gate | Replaces |
|---|---|---|---|
| `R0_SCOPE` | M1 | scope and segments confirmed | 01-G0, 03-R0 |
| `R1_PRODUCT_FACTS` | M1 | owner validates product facts | 03-R1 |
| `R2_COMPETITORS` | M1 | competitor coverage reviewed | 03-R2 |
| `R3_EVIDENCE` | M1 | source quality and diversity reviewed | 01-G1, 08-G1, 03-R3 |
| `R4_INSIGHTS` | M1 | top insights and benefit links validated | 01-G2, 03-R4 |
| `R5_REPORT` | M1 | report version approved and frozen | 01-G3, 08-G2, 03-R5 |
| `S1_DESIRE_MATCH` | M2 | dominant desire matched to verified product performance | part of 01-G4 / 08-G3 |
| `S2_BIG_IDEA` | M2 | one belief / Big Idea approved; blueprint version frozen | 01-G4, 08-G3 |
| `P1_NARRATIVE` | M3 | persuasive narrative, offer and claims reviewed, **including the Evaldo ten-question evaluation** | 01-G5 (part), 08-G4 |
| `P2_ASSET_REVIEW` | M3 | asset-level CUBA and factual review; asset approval | 01-G5, 08-G5 |
| `P3_PACKAGE` | M3 | campaign package approved | 01-G6, 08-G6 |

- S1 and S2 are **separate** approvals.
- **Module 3 may not begin drafting until `S2_BIG_IDEA` is approved.** This is a hard precondition on every M3 create/generate endpoint.
- The Evaldo framework belongs to Module 3 and evaluates the narrative **before** asset approval. Its content remains an unresolved source dependency. **Do not synthesize the questions.**

## 5. Reconciled table inventory — [APPROVED logical scope] / [PROPOSED physical]
Founder decision: **27 core Research Engine tables + `invitations` = 28.** This is logical scope, not creation authorization.

**Reconciliation of the existing starter `user` table:**
- `user` **counts toward the 27**. It was part of the shared 24-table base in docs/09.
- It will be **extended, not recreated**.
- Totals:
  - **27 tables to create** (26 core + `invitations`);
  - **1 existing table to modify** (`user`);
  - **28 tables in total**.

| # | Group | Table | State | Migration |
|---|---|---|---|---|
| 1 | Identity | `user` | **exists** (starter) → extend | M1 |
| 2 | Tenancy | `organizations` | new | M1 |
| 3 | Tenancy | `organization_members` | new | M1 |
| 4 | Tenancy | `brands` | new | M1 |
| 5 | Tenancy | `products` | new | M1 |
| 6 | Method | `methodology_versions` | new | M1 |
| 7 | Execution | `jobs` | new | M2 |
| 8 | Audit | `review_events` | new | M1 (moved forward to log membership/invite decisions) |
| 9 | Project | `research_projects` | new | M2 |
| 10 | Project | `research_segments` | new | M2 |
| 11 | Provenance | `research_sources` | new | M3 |
| 12 | Provenance | `source_excerpts` | new | M3 |
| 13 | Provenance | `research_observations` | new | M3 |
| 14 | Provenance | `observation_categories` | new | M3 |
| 15 | Product | `product_capabilities` | new | M4 |
| 16 | Product | `product_benefits` | new | M4 |
| 17 | Product | `capability_benefit_links` | new | M4 |
| 18 | Product | `product_proofs` | new | M4 |
| 19 | Competitors | `competitors` | new | M4 |
| 20 | Competitors | `competitor_observations` | new | M4 |
| 21 | Synthesis | `research_insights` | new | M5 |
| 22 | Synthesis | `insight_support` | new | M5 |
| 23 | Synthesis | `insight_rankings` | new | M5 |
| 24 | Synthesis | `benefit_desire_links` | new | M5 |
| 25 | Synthesis | `research_assessments` | new | M5 |
| 26 | Report | `research_reports` | new | M6 |
| 27 | Report | `research_report_sources` | new | M6 |
| 28 | Security | `invitations` | new | M1 |

**[DEFERRED]**
- **Later phases:**
  - `research_report_excerpts`. The excerpt manifest lives inside the immutable `report_json` until then. It can be backfilled deterministically.
  - `research_questions`.
  - `import_batches`. Historical spreadsheet import waits for an import policy.
- **Pending verification:**
  - `audit_log` (trigger-based, pending S6).
  - `login_attempts`, only needed if Redis rate limiting is unavailable.
- **Possible future tables:**
  - a counsel-approved legal-basis catalog and retention-policy table (possible future, §3);
  - prompt/version registry (Phase 1B).
- **Later modules:** all Module 2/3 tables.

## 6. Relationship model — [APPROVED logical] / [PROPOSED physical]
`→` = many-to-one FK. `(org)` = carries a denormalised, immutable `organization_id`. `(proj)` = carries a denormalised `research_project_id`. All cross-row consistency is enforced in transactional service functions; see §8 for why.

```
user ─────────────────────────────────────────────────── global identity (is_platform_admin, status)
methodology_versions ─────────────────────────────────── global; approved_by → user

organizations
├── organization_members (org)        → organization, → user          unique(organization_id, user_id)
├── invitations (org)                 → organization, invited_by/accepted_by → user   unique(token_hash)
├── review_events (org)               actor → user; polymorphic (entity_type, entity_id); append-only by policy
├── jobs (org, proj?)                 → research_project (nullable)    unique(organization_id, idempotency_key)
├── brands (org)                      unique(organization_id, name)
│   └── products (org)                → brand                          unique(brand_id, name)
└── research_projects (org)           → product, → methodology_version, owner → user,
    │                                   current_report_id → research_reports (nullable, added last; circular)
    ├── research_segments (org,proj)                                    unique(research_project_id, name)
    ├── research_sources (org,proj)                                     unique(research_project_id, dedupe_key)
    │   └── source_excerpts (org,proj) → source; supersedes → source_excerpt; extracted_by → job
    │                                                                   unique(source_id, excerpt_hash)
    ├── research_observations (org,proj) → segment?, → source_excerpt?, → job?
    │   └── observation_categories (org,proj) → observation             unique(observation_id, ivoc_category)
    ├── product_capabilities (org,proj) → product
    ├── product_benefits (org,proj)
    ├── capability_benefit_links (org,proj) → capability, → benefit     unique(capability_id, benefit_id)
    ├── product_proofs (org,proj) → capability? | benefit?; → source_excerpt? | owner_attestation_text
    ├── competitors (org,proj)                                          unique(research_project_id, normalized_name)
    │   └── competitor_observations (org,proj) → competitor, → source_excerpt?, → observation?
    ├── research_insights (org,proj) → segment, → job?
    │   ├── insight_support (org,proj) → insight, → observation         unique(insight_id, observation_id, stance)
    │   ├── insight_rankings (org,proj) → insight, → segment            unique(research_project_id, research_segment_id, insight_id)
    │   └── benefit_desire_links (org,proj) → benefit, → insight(desire), → segment
    │                                                                   unique(benefit_id, insight_id, research_segment_id)
    ├── research_assessments (org,proj) → segment?
    └── research_reports (org,proj) → methodology_version, → job?, approved_by → user
        │                                                               unique(research_project_id, version_no)
        └── research_report_sources (org,proj) → report, → source       unique(report_id, source_id)
```

**Evidence chain (traceability path):**
```
research_sources → source_excerpts → research_observations ─(insight_support)→ research_insights
                         ↑                                                         │ (desire)
                  product_proofs → product_capabilities ─(capability_benefit_links)→ product_benefits ─(benefit_desire_links)┘
                                                     ↓ frozen at R5_REPORT
                     research_reports.report_json (+ excerpt text, hashes) + research_report_sources
```

**Service-enforced invariants:**
- docs/09 §3.2 applies, plus:
  - `insight_support.observation` and `insight` share project, and segment unless a cross-segment note exists;
  - `benefit_desire_links.insight.ivoc_category = desire` and `insight_kind = ivoc_theme`;
  - `verbatim_quote ⇒ verified excerpt`;
  - `ai_proposed ⇒ generated_by_job_id`, and no verified state without `accepted_by`.
- **Optimistic revision:** every project-scoped write bumps `research_projects.content_revision`. `R5_REPORT` approval requires `report.based_on_revision = project.content_revision`.

## 7. M0 security implementation plan — [AWAITING AUTH]
**Nothing in this section has been executed.** The global CLI default profile and all Goodz configuration stay unchanged.

### 7.0 Read-only findings (2026-10-29)
| Finding | Evidence | Consequence |
|---|---|---|
| Four CLI profiles hold **non-expiring, full-permission (level 15) admin tokens** for the same Xano user. No token carries a workspace restriction. | Token claim *structure* decoded locally; values not printed | Any profile can reach Goodz, PMF and Marketing. Isolation is procedural today. |
| `~/.xano/credentials.yaml` is **world-readable** (`-rw-r--r--`) | `ls -l` | Any local process or user can read all four tokens. |
| Profile `xano --version`: no workspace, no branch, token issued 2026-06-17 21:26 UTC; `goodz` token issued 21:32 UTC the same day, identical scope set, distinct token | Same | Most likely an accidental first profile created during Goodz setup (the CLI command name was used as the profile name). **Purpose unconfirmed. Left untouched.** |
| Global `default` profile → workspace 1, branch `v55` | Same | Any un-pinned command targets Goodz `v55`. |
| Xano Metadata API scopes are per resource type (`workspace:database`, `workspace:api`, …), with no workspace field. Workspace access comes from **instance membership/RBAC**; this account is `admin` with all-workspace access. | Xano Meta API docs; `profile me` structure | A token cannot be restricted to workspace 3 by scope alone. Restriction requires a separate Xano member limited by RBAC. **[UNVERIFIED]** whether the plan includes RBAC: purchased add-on count for `rbac` is 0. |
| Instance has Redis deployed (`redis_isolation: true`); `direct_query_access: true`. Add-on counts for rbac, data_sources, tenants, private_storage, tasks are all 0. | `profile me` structure | `redis.ratelimit` is probably usable **[UNVERIFIED]**. Tenants, extra data sources and private storage may be unavailable **[UNVERIFIED — base plan entitlements unknown]**. |

### 7.1 Local credential hygiene (founder executes)
1. `chmod 600 ~/.xano/credentials.yaml && chmod 700 ~/.xano`. This does not change content and does not affect Goodz.
2. **`xano --version` profile:** keep as is until its purpose is confirmed. The founder checks Xano dashboard → Settings → Access Tokens for a token created 2026-06-17 ≈21:26 UTC. If it is unused, the follow-up decision (revoke, then remove the profile) is separate and needs explicit approval.

### 7.2 Dedicated Marketing Engine credential (founder executes; Claude never handles tokens)
- **Option A (strongest, preferred if available):**
  - Invite a separate Xano team member, e.g. `marketing-ops@…`.
  - Restrict its RBAC to workspace 3 only, without billing, tenant_center, secrets or backup permissions.
  - Generate this member's tokens.
  - Requires RBAC on the plan. Founder checks the dashboard → Team/RBAC; it may require the add-on.
- **Option B (fallback):** two new tokens from the founder's account with minimum scopes.
  - `marketing-engine-ro`: read scopes only.
  - `marketing-engine-rw`: `workspace:database`, `workspace:api`, `workspace:function`, `workspace:task`, `workspace:file` only; no `tenant_center:*`, `instance:billing`, `*:secrets`, `backup`.
  - **Still instance-wide across workspaces.** Isolation then relies on §7.4 and §7.5.
- In both options, set an expiry if the dashboard supports it, and label each token with its purpose.

### 7.3 Profiles (founder runs; token read without echo or shell history)
```sh
read -rs XANO_TOKEN && xano profile create marketing-ro \
  -i "$XANO_INSTANCE_ORIGIN" -t "$XANO_TOKEN" -w 3 -b v1 && unset XANO_TOKEN
# XANO_INSTANCE_ORIGIN = the instance URL shown by `xano profile list` (kept out of this public repo)
# repeat later for marketing-rw only when a write batch is authorized
cd ~/marketing && xano profile use marketing-ro -w 3 -b v1 --gitignore
```
**Verify:**
- `xano profile get` (global) still prints `default`.
- `xano profile list` still shows `default` → workspace 1 / v55. Goodz is unchanged.
- In `~/marketing`, `xano workspace get -o json` (no `-w`) returns id 3.
- `.gitignore` contains `profile.yaml`.

**[UNVERIFIED]** The help text calls `-w` a "workspace name", but existing profiles store numeric IDs. Confirm with `profile list` after creation.

### 7.4 Repository command safeguards ([PROPOSED] files; created only after approval)
**`scripts/xano-preflight.sh`** must pass before any write. It aborts on any mismatch:
1. `XANO_PROFILE` is unset or equals `marketing-*`.
2. `xano workspace get -w 3 -o json` returns `id == 3`, `name == "Marketing engine"` and `created_at == "2026-10-29 09:28:04+0000"`. The creation time is the immutable fingerprint, since names can be renamed.
3. The target branch equals the authorized branch.
4. A dated approval marker `ops/approvals/<date>-<batch>.md` exists and names the batch.
5. Append command, operator, fingerprint and commit hash to `ops/xano-changes.log` (no secrets).

**`.claude/settings.json` + `scripts/xano-guard.sh`** is a Claude Code `PreToolUse` hook on `Bash`. It **blocks** any command containing `xano` that:
- lacks `-w 3` / `--workspace 3` / `--workspace=3`, except `profile get|list|workspace` and `--help`;
- contains `-w 1`, `-w 2`, `--workspace[= ]1|2`, `-p goodz`, `-p pmf`, `-p default`, `-p "xano --version"`, or `XANO_PROFILE=` set to a non-`marketing-*` value;
- is destructive or state-changing — `push` without `--dry-run`, `delete`, `set_live`, `sandbox reset|delete|push`, `profile create|edit|delete|set`, `workspace create|edit`, `tenant`, `ephemeral`, `release` — unless an approval marker exists for today.

**Permission deny rules** mirror these patterns. Plus:
- no Xano MCP server registered for this repo;
- never change the global default profile.

### 7.5 Verification of existing users (read-only; founder executes)
- **Dashboard:** workspace 3 → Database → `user` → record count. **Expected 0.** This keeps password hashes off any local disk, which is why it isn't done via `workspace pull --records`.
- **If the count is > 0, treat it as an incident:**
  - review the rows in the dashboard;
  - check request history for `POST auth/signup`;
  - stop M0 until resolved.

### 7.6 Disable public signup (Claude executes after authorization)
1. Pull ws 3 to `xano/` in the repo, record the baseline commit, and diff against the 6-document baseline.
2. Edit `api/authentication/auth/signup_POST.xs` so its first stack step is an unconditional `precondition (false) { error_type = "accessdenied" error = "Signup is disabled." }`. This is a one-file partial push, with **no `--sync --delete`**. The endpoint itself is deleted in M1 once `auth/accept-invite` exists.
3. Run §7.4 preflight, then `xano workspace edit -w 3 --allow-push`.
4. `xano workspace push -w 3 -b v1 -d xano --dry-run`, then show the founder the dry-run output.
5. Push, then `xano workspace edit -w 3 --no-allow-push`.
6. **Verify:** `POST auth/signup` returns `accessdenied`, and the pull diff shows only that file changed.
- **Rollback:** `git revert` plus the same push procedure.
- **Fallback:** the founder disables or deletes the endpoint in the dashboard, and Claude verifies via pull diff.

### 7.7 Owner bootstrap — founder's preferred method (dashboard)
1. Only after §7.5 shows 0 users and §7.6 is live.
2. Founder adds one `user` row in the dashboard: name, email (lower-case), and a strong password of at least 12 characters entered in the `password`-type field.
3. **[UNVERIFIED]** Does the dashboard hash `password`-type fields on manual entry? Do table-level filters (`min:8`, `minAlpha`, `minDigit`) apply there?
   - **Verification:** `POST auth/login` with the new credentials must succeed. `security.check_password` only matches a stored hash, so a plaintext row would fail.
   - Login with a wrong password must fail.
4. Organization and owner membership rows are created in M1, through a platform-admin-only `POST /organizations` that inserts the creator as `owner` in one transaction. They are never inserted by hand, which avoids bypassing service checks.
5. Set `user.is_platform_admin = true` for the founder in M1 (dashboard edit plus a `review_events` entry recorded by the M1 bootstrap function).

### 7.8 Login hardening and rate limiting (Claude executes after authorization; same push procedure)
- **`auth/login`:**
  - Make `email` and `password` required.
  - Add `redis.ratelimit` with key `login:email:<lower(email)>` at 5 attempts per 900 s, and key `login:ip:<$env.$remote_ip>` at 20 per 900 s. Both return HTTP 429 with a generic message.
  - The identical "Invalid Credentials." error stays.
- **Token lifetime:** 86400 s → 28800 s (8 h) **[PROPOSED]**.
- **`auth/accept-invite` (M1):** 10 per 3600 s per IP, plus 5 failed token attempts per invitation.
- **[UNVERIFIED]**
  - `redis.ratelimit` availability on this plan;
  - whether `$env.$remote_ip` reflects the client IP behind Xano's ingress.
- **Fallback if Redis is unavailable:** the deferred `login_attempts` table, which needs separate approval.

### 7.9 Post-M0 acceptance checks
- signup → `accessdenied`;
- 6 wrong logins → 429;
- correct login → token;
- `auth/me` → the owner;
- `profile list` unchanged for Goodz/PMF;
- the guard hook blocks `xano workspace get -w 1` and `xano branch list -p goodz`;
- pull diff limited to the intended files.

## 8. Xano verification questions — [UNVERIFIED]
None of these may be assumed. Hooks, table triggers, raw SQL and DB-enforced immutability are **unverified until demonstrated**. Branches are **not** treated as isolated databases.

**Isolation (must be answered before any test runs):**
- **V1** Is a truly isolated environment available?
  - **(a) Sandbox.** The CLI sandbox is a per-user singleton that holds one workspace's contents at a time, on paid plans. Open questions:
    - Does it already exist?
    - Does it currently hold **Goodz** work? If so, `sandbox reset` would destroy it, and its "promote to workspace" path could target Goodz.
    - Is its database separate from workspaces 1–3?
    - **Founder check in the dashboard first.** `xano sandbox get` auto-creates a sandbox, so it is not read-only.
  - **(b) Ephemeral tenant of workspace 3.** Tenants have their own database. However, the purchased tenant add-on count is 0, tenants receive code only via releases, and they may incur cost.
  - **(c)** Neither (a) nor (b) available → no isolated environment exists. The founder then decides between workspace-3 `zz_spike_*` tests and no tests.
- **V2** Plan base entitlements: RBAC, data sources (live/test), tenants, private file storage, task count, sandbox. Source: billing page or Xano support.

**Behavior (spikes S1–S3 and S5–S9 from docs/09, run only in an approved isolated environment):**
- **V3 (S1)** Are FK references enforced?
- **V4 (S2)** Does a failure inside a transaction roll back?
- **V5 (S3)** Does serializable isolation raise a catchable conflict?
- **V6 (S5)** Do branches share schema and data?
- **V7 (S6)** Can table triggers run synchronously or block writes?
- **V8 (S7)** Are NULLs distinct in composite unique indexes?
- **V9 (S8)** Does raw SQL `FOR UPDATE SKIP LOCKED` work inside a transaction?
- **V10 (S9)** Are attachments private? Do they get signed URLs? What is the size cap?

**From documentation or Xano support, not stress tests (S4):**
- **V11** Execution and scheduling limits: minimum task frequency, maximum task and request runtime, concurrency, `api.request` timeout, async-dedicated availability.

**Auth and M0:**
- **V12** Dashboard password hashing and filters on manual entry.
- **V13** `redis.ratelimit` availability and `$env.$remote_ip` correctness.
- **V14** Token expiry and revocation options for Metadata API tokens.
- **V15** Does `profile create -w` accept a numeric ID?
- **V16** Does `allow_push` gate CLI pushes, and does toggling it have side effects?
- **V17** Is a workspace-3-only RBAC member possible?

## 9. Proposed implementation batches — [AWAITING AUTH]

### Batch 1 — M0 security (no tables, no research data)
**Order:**
1. §7.1 local hygiene (founder)
2. §7.5 user count (founder)
3. §7.2 credential (founder)
4. §7.3 profiles (founder)
5. §7.4 safeguard files (Claude: repo-only commit)
6. §7.6 signup disabled (Claude: workspace 3 push)
7. §7.7 owner bootstrap (founder: dashboard)
8. §7.8 login hardening (Claude: workspace 3 push)
9. §7.9 acceptance checks

**Xano writes:**
- 2 endpoint files (`signup_POST.xs`, `login_POST.xs`);
- 1 manual `user` row;
- 2 `allow_push` toggles.

**Preconditions:**
- separate founder authorization;
- V13 answered or accepted as a risk;
- V12 verified at step 7.

### Batch 2 — M1 tenancy schema (first table batch; preview only)
**Scope:**
- **New tables (6):** `organizations`, `organization_members`, `invitations`, `brands`, `products`, `methodology_versions`.
- **Also new:** `review_events`.
- **Extended:** `user`.

So that's **7 new tables + 1 modified**.

**Shared functions:** `ctx_resolve`, `log_review_event`, `hash_token`.

**Endpoints:**
- `POST /organizations` (platform admin; creates the owner membership atomically)
- `GET /me/organizations`
- `GET /organizations/{id}/members`
- `PATCH /organizations/{id}/members/{user_id}` (owner)
- `POST /organizations/{id}/invitations` and `POST /invitations/{id}/revoke` (owner)
- `POST auth/accept-invite`
- `POST/GET /brands`, `POST/GET /products`
- `POST /methodology-versions` and `POST /methodology-versions/{id}/publish` (platform admin)
- delete `auth/signup`

**Proposed physical columns:**
| Table | Columns | Indexes |
|---|---|---|
| `user` (+) | add `status` enum(active,suspended)=active, `is_platform_admin` bool=false, `updated_at`; make `email` required | existing unique(email) |
| `organizations` | id, created_at, updated_at, name, slug, status enum(active,archived), created_by→user | unique(slug) |
| `organization_members` | id, created_at, updated_at, organization_id→organizations, user_id→user, role enum(owner,editor,reviewer,viewer), status enum(active,removed), added_by→user | unique(organization_id,user_id); (user_id) |
| `invitations` | id, created_at, organization_id, email, role enum(editor,reviewer,viewer), token_hash, expires_at, status enum(pending,accepted,revoked,expired), invited_by→user, accepted_by→user?, accepted_at?, failed_attempts int=0 | unique(token_hash); (organization_id,email,status) |
| `brands` | id, created_at, updated_at, organization_id, name, description, market, default_locale | unique(organization_id,name) |
| `products` | id, created_at, updated_at, organization_id, brand_id→brands, name, description, lifecycle_status enum(concept,beta,live,retired) | unique(brand_id,name); (organization_id) |
| `methodology_versions` | id, created_at, key, version, title, source_url, source_hash, reviewed_on, instructions_ref, status enum(draft,published,retired), approved_by→user?, approved_at? | unique(key,version) |
| `review_events` | id, created_at, organization_id?, actor_id→user, entity_type, entity_id, gate_code?, from_status, to_status, decision, reason, before_hash, after_hash, idempotency_key? | (organization_id,entity_type,entity_id); unique(organization_id,idempotency_key) |

**Invitation rules:**
- Only one pending invitation per (organization, email). This is a service check, because partial unique indexes are unavailable; a new invite revokes the previous one.
- Invitation tokens are 32 random bytes, stored only as sha256, single-use, with a 72 h expiry.

**Acceptance tests:**
- A non-member gets 404 on every org-scoped read or write.
- A viewer cannot invite.
- An expired, revoked or reused invitation is rejected.
- Accepting an invite creates the user and membership atomically (depends on V4).
- Duplicate membership is rejected (V8).
- A cross-org brand/product id returns 404.
- A published methodology version is immutable.

**Preconditions:** Batch 1 accepted; V1 resolved; V4 and V8 demonstrated in an approved environment, or the founder accepts the risk explicitly.
