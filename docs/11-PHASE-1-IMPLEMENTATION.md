# Phase 1 implementation: Research Engine backend (Xano workspace 3)
Date: 2026-10-29. Status: **IMPLEMENTED on Xano workspace 3 ("Marketing engine"), branch `v1` (live). Tested end to end with synthetic data, which has since been removed.**

Founder authorization (2026-10-29, ADR-018) allowed direct development on workspace 3 `v1`, without sandboxes, extra branches, tenants or per-item approvals. This document records what was actually built. It supersedes the *proposed* physical details in docs/09 and docs/10 where they differ. Conceptual decisions remain those in docs/10 and DECISIONS.md.

- **Source of truth:** `xano/`, the canonical `xano workspace pull` layout of `v1`. It covers 29 tables, 24 functions, 8 API groups and 80 endpoints, and it is in sync with the live branch (see §8).
- **Tests:** `tests/e2e_research_engine.py`.
- **Safe CLI wrapper:** `scripts/xano-ws3.sh`. It always targets workspace 3 and refuses to run if the workspace fingerprint does not match.

---

## 1. Database schema (as deployed)
There are 29 tables: the 28 approved in docs/10 §5, plus **`login_attempts`** (§6, ADR-019).
- The existing starter `user` table was **extended, not recreated**.
- Every organization-owned table carries a denormalized `organization_id`. Research tables also carry `research_project_id`.
- **The database does not enforce FK references (verified, §5).** Every cross-row reference is checked in the API layer.

| Table | Unique constraints (beyond `id`) | Purpose |
|---|---|---|
| `user` | (email) | Accounts. Added `status`, `is_platform_admin`, `updated_at`, `last_login_at`. |
| `organizations` | (slug) | Application tenancy. |
| `organization_members` | (organization_id, user_id) | Roles: owner > reviewer > editor > viewer. |
| `invitations` | (token_hash) | Invite-only registration. Only the sha256 of each token is stored. |
| `brands` | (organization_id, name) | |
| `products` | (brand_id, name) | |
| `methodology_versions` | (key, version) | Global. Published versions are immutable. |
| `review_events` | — | Append-only audit trail with gate codes, from/to status, hashes and details. |
| `jobs` | (organization_id, idempotency_key) | Audited work units. Phase 1A uses only `report_render`. |
| `research_projects` | — | Holds `content_revision` (optimistic revision) and `current_report_id`. |
| `research_segments` | (research_project_id, name) | |
| `research_sources` | (research_project_id, dedupe_key) | Includes the five-dimension privacy model (§3) and a pseudonymized `author_ref`. |
| `source_excerpts` | (source_id, excerpt_hash) | Exact text is immutable. Corrections use `supersedes_excerpt_id`. |
| `research_observations` | — | Observation types: verbatim quote, paraphrase, secondary summary, analyst hypothesis. Provenance is derived. |
| `observation_categories` | (observation_id, ivoc_category) | The 7 approved IVOC categories. |
| `product_capabilities` | — | Includes `availability_status` (live/beta/roadmap) and verification state. |
| `product_benefits` | — | |
| `capability_benefit_links` | (capability_id, benefit_id) | |
| `product_proofs` | — | Either a verified excerpt or an owner attestation. |
| `competitors` | (research_project_id, normalized_name) | |
| `competitor_observations` | — | `observed_claim` and `analyst_note` are stored separately. |
| `research_insights` | — | Includes `insight_kind`, `ivoc_category` and `evidence_basis` (evidenced/hypothesis). |
| `insight_support` | (insight_id, observation_id, stance) | Supporting and contradicting evidence. |
| `insight_rankings` | (research_project_id, research_segment_id, insight_id) | Counts are computed server-side. |
| `benefit_desire_links` | (benefit_id, insight_id, research_segment_id) | Desire insights only, same segment only. |
| `research_assessments` | — | Awareness, sophistication, ideal_client, trust, market_context, competitive_summary. |
| `research_reports` | (research_project_id, version_no) | Immutable snapshot JSON plus hashes. |
| `research_report_sources` | (report_id, source_id) | Source manifest frozen at approval, with content hashes. |
| `login_attempts` | — | Table-based rate limiting (§6). |

Every content table also carries `origin` (`human_entered | imported | ai_proposed`), `generated_by_job_id`, `accepted_by` and `accepted_at`. Phase 1A writes only `human_entered`.

## 2. API inventory (80 endpoints)
Base URL: `<instance>/api:<canonical>/<path>`. Every endpoint except `auth/login`, `auth/accept-invite` and `auth/bootstrap-admin` requires a Bearer token.
- "Minimum access" is the minimum organization role, unless the entry says otherwise.
- A non-member always receives **404 `NOT_FOUND`**, never 403, so the existence of other organizations' data is not disclosed.

**Error envelope:** Xano returns `{"code": "...", "message": "CODE: human text"}`. Read the machine code from the `message` prefix, e.g. `STALE_REPORT`, `EVIDENCE_REQUIRED`, `RATE_LIMITED`, `INVALID_TRANSITION`. HTTP status codes used: 400 (input or state), 401 (no token), 403 (role, credentials, rate limit), 404 (not found or not a member).

| Group (canonical) | Method | Path | Minimum access | Notes |
|---|---|---|---|---|
| Authentication (`Sbj3o3SC`) | POST | `auth/accept-invite` | public | Invite-only registration: create an account from a pending invitation token and join its organization. Existing accounts must sign in and use POST inv |
| Authentication (`Sbj3o3SC`) | POST | `auth/bootstrap-admin` | public | One-time owner bootstrap. Creates the first platform administrator only while none exists and only with the secret held in the workspace environment v |
| Authentication (`Sbj3o3SC`) | POST | `auth/login` | public | Login and retrieve an authentication token. Rate limited per IP and per email; suspended accounts cannot log in. |
| Authentication (`Sbj3o3SC`) | GET | `auth/me` | authenticated | Current user and their active organization memberships. |
| organizations (`mkteng-org`) | POST | `invitations/accept` | authenticated | Accept an invitation with an existing, signed-in account. The account email must match the invitation. |
| organizations (`mkteng-org`) | POST | `invitations/{invitation_id}/revoke` | owner |  |
| organizations (`mkteng-org`) | PATCH | `members/{member_id}` | owner | Change a member's role or remove them (owners only). The last active owner cannot be demoted or removed. |
| organizations (`mkteng-org`) | GET | `organizations/{organization_id}` | viewer |  |
| organizations (`mkteng-org`) | GET | `organizations/{organization_id}/invitations` | owner |  |
| organizations (`mkteng-org`) | POST | `organizations/{organization_id}/invitations` | owner | Invite someone to an organization (owners only). Returns the plaintext token once; only its sha256 is stored. A new invitation for the same email revo |
| organizations (`mkteng-org`) | GET | `organizations/{organization_id}/members` | viewer |  |
| organizations (`mkteng-org`) | GET | `organizations/{organization_id}/review-events` | viewer | Append-only audit trail for an organization, newest first. |
| catalog (`mkteng-catalog`) | PATCH | `brands/{brand_id}` | editor |  |
| catalog (`mkteng-catalog`) | POST | `brands/{brand_id}/products` | editor |  |
| catalog (`mkteng-catalog`) | GET | `methodology-versions` | authenticated |  |
| catalog (`mkteng-catalog`) | POST | `methodology-versions` | authenticated | Register a methodology version as a draft (platform administrators only). |
| catalog (`mkteng-catalog`) | PATCH | `methodology-versions/{methodology_version_id}` | authenticated | Edit a draft methodology version. Published and retired versions are immutable. |
| catalog (`mkteng-catalog`) | POST | `methodology-versions/{methodology_version_id}/transition` | authenticated | Publish (draft -> published) or retire (published -> retired) a methodology version. |
| catalog (`mkteng-catalog`) | GET | `organizations/{organization_id}/brands` | viewer |  |
| catalog (`mkteng-catalog`) | POST | `organizations/{organization_id}/brands` | editor |  |
| catalog (`mkteng-catalog`) | GET | `organizations/{organization_id}/products` | viewer |  |
| catalog (`mkteng-catalog`) | PATCH | `products/{product_id}` | editor |  |
| research (`mkteng-research`) | PATCH | `excerpts/{excerpt_id}` | editor | Update an excerpt's classification only (speaker, usage rights, personal data, redaction). exact_text never changes. |
| research (`mkteng-research`) | POST | `excerpts/{excerpt_id}/supersede` | editor | Correct an excerpt by creating a new one that supersedes it. The original row is never altered. |
| research (`mkteng-research`) | POST | `excerpts/{excerpt_id}/verify` | reviewer | Reviewer verification of an excerpt. Sources with stored content are always re-checked by content match (a mismatch cannot be overridden). Without sto |
| research (`mkteng-research`) | PATCH | `observations/{observation_id}` | editor | Edit a candidate observation. Verbatim quote text cannot be edited (it mirrors the excerpt). Reviewers may mark provenance as disputed; "verified" is  |
| research (`mkteng-research`) | PUT | `observations/{observation_id}/categories` | editor | Replace the IVOC category set of a candidate observation. |
| research (`mkteng-research`) | GET | `organizations/{organization_id}/projects` | viewer |  |
| research (`mkteng-research`) | POST | `organizations/{organization_id}/projects` | editor |  |
| research (`mkteng-research`) | GET | `projects/{project_id}` | viewer | Project detail with evidence counts for dashboards. |
| research (`mkteng-research`) | PATCH | `projects/{project_id}` | editor |  |
| research (`mkteng-research`) | GET | `projects/{project_id}/excerpts` | viewer |  |
| research (`mkteng-research`) | GET | `projects/{project_id}/observations` | viewer | Observations with their IVOC categories. Optional filters: segment, type, review status, category. |
| research (`mkteng-research`) | POST | `projects/{project_id}/observations` | editor | Record a research observation. verbatim_quote must cite a verified excerpt and always takes the excerpt's exact text. provenance_status is derived (ve |
| research (`mkteng-research`) | GET | `projects/{project_id}/segments` | viewer |  |
| research (`mkteng-research`) | POST | `projects/{project_id}/segments` | editor |  |
| research (`mkteng-research`) | GET | `projects/{project_id}/sources` | viewer |  |
| research (`mkteng-research`) | POST | `projects/{project_id}/sources` | editor | Register a research source. Deduplicates deterministically: same canonical URL (normalized) or same content in a project returns the existing source w |
| research (`mkteng-research`) | POST | `projects/{project_id}/transition` | editor | Project lifecycle: draft -> scoped -> collecting <-> synthesizing; any -> archived (owner); archived -> collecting (owner). draft -> scoped is gate R0 |
| research (`mkteng-research`) | PATCH | `segments/{segment_id}` | editor |  |
| research (`mkteng-research`) | GET | `sources/{source_id}` | viewer |  |
| research (`mkteng-research`) | PATCH | `sources/{source_id}` | editor | Update source metadata and its privacy / provenance / rights / retention classification. canonical_url is immutable (register a new source instead). c |
| research (`mkteng-research`) | POST | `sources/{source_id}/excerpts` | editor | Record a verbatim excerpt of a source. exact_text is immutable after creation. If the source has stored content, the excerpt is checked against it imm |
| product (`mkteng-product`) | PATCH | `benefits/{benefit_id}` | editor |  |
| product (`mkteng-product`) | PATCH | `capabilities/{capability_id}` | editor | Edit a capability while it is still unverified. |
| product (`mkteng-product`) | POST | `capabilities/{capability_id}/verify` | reviewer | Reviewer decision on a capability. verify requires at least one approved proof (gate R1_PRODUCT_FACTS); dispute and unverify require a reason. |
| product (`mkteng-product`) | GET | `projects/{project_id}/benefits` | viewer |  |
| product (`mkteng-product`) | POST | `projects/{project_id}/benefits` | editor |  |
| product (`mkteng-product`) | GET | `projects/{project_id}/capabilities` | viewer |  |
| product (`mkteng-product`) | POST | `projects/{project_id}/capabilities` | editor |  |
| product (`mkteng-product`) | GET | `projects/{project_id}/capability-benefit-links` | viewer |  |
| product (`mkteng-product`) | POST | `projects/{project_id}/capability-benefit-links` | editor | Link a product capability to a benefit it delivers. Both must belong to the project. |
| product (`mkteng-product`) | GET | `projects/{project_id}/proofs` | viewer |  |
| product (`mkteng-product`) | POST | `projects/{project_id}/proofs` | editor | Record proof for a capability and/or benefit: a verified source excerpt or a documented owner attestation. |
| competitors (`mkteng-competitors`) | PATCH | `competitor-observations/{competitor_observation_id}` | editor |  |
| competitors (`mkteng-competitors`) | PATCH | `competitors/{competitor_id}` | editor |  |
| competitors (`mkteng-competitors`) | POST | `competitors/{competitor_id}/observations` | editor | Record what a competitor says or does along one dimension. observed_claim (the competitor's claim) and analyst_note (our interpretation) stay separate |
| competitors (`mkteng-competitors`) | GET | `projects/{project_id}/competitor-observations` | viewer |  |
| competitors (`mkteng-competitors`) | GET | `projects/{project_id}/competitors` | viewer |  |
| competitors (`mkteng-competitors`) | POST | `projects/{project_id}/competitors` | editor |  |
| synthesis (`mkteng-synthesis`) | PATCH | `assessments/{assessment_id}` | editor |  |
| synthesis (`mkteng-synthesis`) | GET | `insights/{insight_id}` | viewer | Insight detail with its evidence graph (support/contradict links enriched with the observation), ranking and counts. |
| synthesis (`mkteng-synthesis`) | PATCH | `insights/{insight_id}` | editor |  |
| synthesis (`mkteng-synthesis`) | POST | `insights/{insight_id}/support` | editor | Link an observation to an insight as supporting or contradicting evidence. Contradicting evidence is kept, never dropped. |
| synthesis (`mkteng-synthesis`) | GET | `projects/{project_id}/assessments` | viewer |  |
| synthesis (`mkteng-synthesis`) | POST | `projects/{project_id}/assessments` | editor | Record an assessment. Awareness and sophistication are always per segment. |
| synthesis (`mkteng-synthesis`) | GET | `projects/{project_id}/benefit-desire-links` | viewer |  |
| synthesis (`mkteng-synthesis`) | POST | `projects/{project_id}/benefit-desire-links` | editor | Link a product benefit to an evidenced desire insight of the same segment. |
| synthesis (`mkteng-synthesis`) | GET | `projects/{project_id}/insights` | viewer |  |
| synthesis (`mkteng-synthesis`) | POST | `projects/{project_id}/insights` | editor |  |
| synthesis (`mkteng-synthesis`) | GET | `projects/{project_id}/rankings` | viewer |  |
| synthesis (`mkteng-synthesis`) | PUT | `projects/{project_id}/rankings` | editor | Upsert the priority ranking of an approved insight within its segment. Evidence counts are computed from approved support links, never accepted from t |
| workflow (`mkteng-workflow`) | GET | `jobs/{job_id}` | viewer |  |
| workflow (`mkteng-workflow`) | GET | `projects/{project_id}/reports` | viewer |  |
| workflow (`mkteng-workflow`) | POST | `projects/{project_id}/reports` | editor | Generate a draft Research Report version from approved project data. Idempotent per project content revision: repeating the call without evidence chan |
| workflow (`mkteng-workflow`) | GET | `reports/{report_id}` | viewer |  |
| workflow (`mkteng-workflow`) | POST | `reports/{report_id}/approve` | reviewer | Gate R5_REPORT. Atomic approval that freezes the report version. Concurrency: the transaction first updates the project row (taking its row lock) and  |
| workflow (`mkteng-workflow`) | POST | `reports/{report_id}/reject` | reviewer | in_review -> draft with a reason. A rejected version can be resubmitted only if it is still current. |
| workflow (`mkteng-workflow`) | POST | `reports/{report_id}/submit` | editor | draft -> in_review. Refuses stale reports (evidence changed since generation) and reports with blocking issues. |
| workflow (`mkteng-workflow`) | GET | `reports/{report_id}/verify` | viewer | Integrity check of a report against its recorded hashes and the current state of its sources and excerpts. |

**Review decisions:** all review decisions on research items go through `POST reviews` with `{entity_type, entity_id, decision: submit|approve|reject|reopen, reason}`. Supported entity types: research_sources, research_observations, product_benefits, capability_benefit_links, product_proofs, competitors, competitor_observations, insight_support, insight_rankings, benefit_desire_links, research_assessments, research_insights. Excerpts and capabilities use their own `verify` endpoints.

## 3. Shared functions (24)
| Function | Responsibility |
|---|---|
| `auth/org_context` | Resolves the caller's active membership and enforces the minimum role. Non-member → notfound; insufficient role → accessdenied; suspended account → accessdenied. |
| `auth/rate_limit` | Fixed-window limiter on `login_attempts`. |
| `research/project_context` | Loads a project, authorizes the caller through its organization, and rejects writes to archived projects. |
| `research/touch_project` | Increments `content_revision`. Called inside the transaction of every research write. |
| `research/text_contains` | Whitespace-insensitive check that an excerpt appears in the stored source content. |
| `privacy/pseudonymize` | Keyed HMAC per organization (`psn_…`). Raw handles are never stored. Fails closed without `MKTENG_PSEUDONYM_KEY`. |
| `audit/log_event` | Appends to `review_events`. |
| `workflow/next_status` | The shared review state machine (see below). |
| `review/<12 entity tables>` | Per-entity transition: scope, role, state, entity-specific integrity checks, revision bump, audit, and AI-acceptance stamping. |
| `synthesis/evidence_counts` | Approved supporting/contradicting counts, plus independent sources and speakers, from the evidence graph. |
| `reports/build_snapshot` | Assembles the immutable report JSON (schema 1.0), a Markdown summary and the source manifest with its hash. |
| `reports/evidence_item` | Applies the fail-closed privacy and rights rules to one evidence entry. Text may be withheld; IDs are never dropped. |
| `reports/report_hash` | sha256 of the report JSON *as stored*. |

**Review state machine (`workflow/next_status`):**
- `candidate → in_review` (submit; editor or above).
- `candidate|in_review → approved|rejected` (reviewer or above; reject requires a reason).
- `approved|rejected → candidate` (reopen; reviewer or above; requires a reason).

## 4. Security and authorization model
- **Authentication:**
  - Xano native auth on `user`, 8-hour tokens.
  - **Public signup is deleted.**
  - Registration is invite-only: an owner creates an invitation, and the token is shown once, stored only as sha256, single-use, valid 72 hours.
  - New accounts register through `auth/accept-invite` (password ≥ 12 characters). Existing accounts use `invitations/accept`, which requires the invitation email to match.
- **Owner bootstrap:**
  - `auth/bootstrap-admin` creates the first platform administrator. It works only while no platform administrator exists, and only with the secret held in the workspace environment variable `MKTENG_BOOTSTRAP_SECRET`.
  - Afterwards it is permanently inert.
  - Alternative: create the user in the Xano dashboard and set `is_platform_admin = true`.
- **Platform administrators** create organizations (becoming their owner) and manage methodology versions. Platform admin status gives **no** implicit access to organization data; membership is still required.
- **Organization isolation:**
  - Every protected endpoint resolves the caller's membership via `auth/org_context`.
  - Child records are loaded and then checked to belong to the caller's project or organization.
  - Cross-organization IDs return 404. Tested on 10 attack paths (§7).
- **Roles:** viewer (read), editor (create and edit candidates, submit), reviewer (approve, reject, reopen, verify; includes editor), owner (invitations, members, archive; includes reviewer).
- **Immutability:**
  - Approved items, verified excerpts, verbatim quote text and published methodology versions cannot be edited through any endpoint.
  - Corrections go through reopen (with a reason) or supersede.
  - Approved reports cannot be modified through the API. `reports/{id}/verify` detects out-of-band edits made in the Xano dashboard by recomputing hashes.
- **Rate limiting:** login is limited to 5 failed attempts per email and 30 attempts per IP per 15 minutes. accept-invite: 10 per IP per hour. bootstrap: 5 per IP per hour. invitations/accept: 10 per user per hour. Limit exceeded → 403 `RATE_LIMITED`.
- **Secrets:**
  - `MKTENG_BOOTSTRAP_SECRET` and `MKTENG_PSEUDONYM_KEY` live only in workspace 3's environment variables, plus private copies in `~/.config/marketing-engine/` (mode 600) on the founder's machine.
  - They are never in git. `xano/workspace/*.xs` is committed **without** `env`.
- **Cross-project safety:** `scripts/xano-ws3.sh` pins every CLI call to workspace 3 and verifies its immutable fingerprint (id 3, name, creation timestamp). `allow_push` is left **off** between deliberate pushes.

## 5. Verified Xano behaviour (answers to docs/10 §8)
| Question | Result (tested live) | Design consequence |
|---|---|---|
| V3: FK references enforced? | **No.** Orphan inserts succeed. | All references are checked in the API layer (as designed). |
| V4: does a precondition failure inside `db.transaction` roll back? | **Yes.** No rows remain. | Multi-row writes are wrapped in transactions. |
| V8: is a unique-index violation catchable? | **Yes.** | Unique indexes back every duplicate rule. |
| Stored JSON key order | **Reordered** by Postgres jsonb; repeated reads are stable. | Report hashes are computed from the stored value read back. |
| V13: Redis rate limit | **Not supported on this plan.** | Table-based limiter (ADR-019). |
| `isolation = "serializable"` in a transaction | **Rejected by the XanoScript parser.** | Row-lock serialization on the project row (ADR-020), tested with parallel requests. |
| Ternary inside an object literal with a path branch (`? $a.b : null`) | **Silently drops the following keys.** | Ternaries are never used inside object literals. |
| Backslashes in string literals (`"/\s+/"`) | **Treated as escapes.** | Regexes use `[[:space:]]` and alternative delimiters. |
| Dotted access to a missing or null key | **Runtime error.** | Null-safe `\|get:"key"` is used for optional objects. |
| V1: isolated sandbox | **Not used** (founder decision ADR-018). | Synthetic data with a guarded cleanup. |
| V11: task/runtime limits | Not tested (no background jobs in Phase 1A). | Must be answered before Phase 1B AI jobs. |

## 6. Deviations from docs/10
1. **`login_attempts` (deferred table promoted, ADR-019).** Redis rate limiting is unavailable on this plan, and rate limiting is part of the approved M0 baseline. Without this table, login would be open to brute force.
2. **Concurrency control (ADR-020).** Serializable isolation is not expressible, so report approval first updates the project row, taking its lock, and only then re-reads `content_revision`. Every evidence write bumps the same row, so approval and edits serialize.
3. **`review_events` moved to the first batch** (as planned in docs/10 §5), and `jobs` is used for report generation.
4. **Report generation is synchronous** (a `report_render` job row is recorded). There is no background worker in Phase 1A.
5. **Excerpt verification:**
   - If the source has stored content, the excerpt is checked against it automatically: found → `verified` (content_match), not found → `failed`. A mismatch cannot be overridden.
   - Without stored content, a reviewer must explicitly confirm (`human_review`).
6. **Quote policy in reports** (applies docs/10 §3 fail-closed rules):
   - Verbatim text is included only when usage rights are `internal_analysis_only` or `quote_*_permitted`.
   - Text is withheld for `special_category` personal data, and for identifiable/undetermined personal data whose processing basis is undetermined.
   - Redacted or prohibited text is always withheld.
   - Withheld entries keep every ID and carry `text_withheld_reason`.
   - **Legal meaning still requires counsel review.**

## 7. Test results (2026-10-29, live `v1`, synthetic data)
**`tests/e2e_research_engine.py`: 71/71 passed.**

| Area | Checks | Highlights |
|---|---|---|
| Authentication | 12 | signup removed (404); bootstrap disabled once an admin exists; reused or revoked invitations rejected; non-owner cannot invite; the 6th failed login is rate limited; last owner cannot be demoted |
| Organization isolation and roles | 14 | outsider gets 404 on org, members, audit, project, source, source create, segment patch, review and reports; cross-org product reference rejected; viewer read-only; editor cannot approve |
| Traceability | 21 | URL dedupe after normalization; excerpt verified against content; forged quote fails and cannot become a verbatim observation; cross-segment support needs a note; evidenced insight needs approved evidence; non-desire or other-segment benefit links rejected; ranking counts computed server-side; report keeps the observation → excerpt → source chain with excerpt hash; manifest; contradicting evidence kept; hypotheses separated |
| Review transitions | 6 | invalid transitions, reasons required, immutability of approved and verbatim items, reopen/re-approve, approved insight locked |
| Privacy | 1 | quote with undetermined rights withheld but traceable |
| Reports | 15 | idempotent generation; draft cannot be approved; editor cannot approve; idempotent re-approval; hash verification; source content locked; new version on new evidence; **stale approval rejected**; v1 superseded and v3 current; superseded content unchanged |
| Concurrency | 2 | 3 parallel approvals → exactly one approval event; approval racing an evidence edit → consistent outcome |

Additional live checks:
- 45/45 endpoint calls in an endpoint sweep, covering every remaining GET and PATCH, capability dispute, excerpt supersede, archive/restore, and writes to an archived project being blocked;
- the existing-account invitation flow (4 checks);
- a proof citing a failed excerpt is rejected;
- runtime probes for §5.

**Cleanup:**
- A guarded temporary endpoint removed all synthetic data (3 organizations, 5 users). It failed closed unless every organization was `SYNTHETIC …` and every user `@example.test`.
- All tables were then truncated, and a final pull confirmed **0 records in all 29 tables**.
- The temporary `zz_probe` API group was deleted.

**Other workspaces:** Goodz (ws 1, live `v59`, 319 documents) and PMF (ws 2, `v1`, 99 documents) were hashed before work began and again afterwards. **All documents, branches and metadata are byte-identical.** The global CLI default profile is unchanged.

## 8. Final `v1` state
- Workspace 3, branch `v1` (live), the only branch.
- **Contents:** 29 tables (0 records), 24 functions, 8 API groups, 80 endpoints.
- **Environment:** `MKTENG_BOOTSTRAP_SECRET` and `MKTENG_PSEUDONYM_KEY` are set; `allow_push` is off.
- **Bootstrap:** no platform administrator exists, so bootstrap is available to the founder.
- **Sync:** the repo's `xano/` matches `v1`. The CLI reports one persistent spurious "update" for `reports/evidence_item` (a comparison quirk after server reformatting); pushing the pulled file does not clear it.

## 9. Known limitations
1. No database-level FK, check or immutability constraints (Xano). Integrity relies on the API layer. Rows edited directly in the Xano dashboard bypass every rule; for reports this is *detected* by `verify`, not prevented.
2. `research/touch_project` is read-modify-write, so concurrent edits can increment by 1 instead of 2. Staleness detection only needs the revision to change, which it always does.
3. Rate limiting is by `$env.$remote_ip`. Whether this is the real client IP behind Xano's ingress is unverified. Limits return 403, not 429. Onboarding many users from one IP is capped at 10 invitation acceptances per hour.
4. Machine-readable error codes are message prefixes, because Xano's error types are limited.
5. `user.is_platform_admin` lost its schema default on the server. Users created outside the API have NULL, which counts as non-admin (fails safe).
6. Report generation is synchronous; failed generations roll back and leave no failed job row. `report_markdown` is a summary; `report_json` is canonical.
7. Expired invitations keep status `pending`; expiry is enforced by timestamp.
8. Excerpt matching is whitespace-insensitive but case-sensitive.
9. Pseudonym references depend on `MKTENG_PSEUDONYM_KEY`. Rotating it changes future references, which breaks speaker-independence counts across the rotation.
10. The CLI sync quirk described in §8.

## 10. Deferred (not built)
- **Deferred tables:** `research_report_excerpts` (report JSON embeds excerpt hashes), `research_questions`, `import_batches` (historical spreadsheet import), trigger-based `audit_log`.
- **Phase 1B:** AI-assisted extraction (proposals via `origin = ai_proposed` and acceptance), plus the background job worker and lease logic.
- **Account and admin gaps:**
  - password reset;
  - token refresh and revocation;
  - an account suspension endpoint (the `status` field exists);
  - organization rename/archive endpoints;
  - invitation email delivery (tokens are shared manually).
- **Not yet available:** file uploads and private storage for source documents; Modules 2 and 3 (Campaign Strategy, Creative Production).

## 11. Operations runbook
- **Push workflow:**
  1. Edit `xano/`.
  2. Validate (XanoScript validator).
  3. `scripts/xano-ws3.sh workspace edit --allow-push`.
  4. `scripts/xano-ws3.sh workspace push -b v1 -d xano --dry-run` and review the preview.
  5. Push with `--force`.
  6. `scripts/xano-ws3.sh workspace edit --no-allow-push`.
  7. Commit.

  Never use `--sync --delete` without a dry-run showing only the intended deletions.
- **First owner:** run `POST <instance>/api:Sbj3o3SC/auth/bootstrap-admin` with `{bootstrap_secret, name, email, password}`, where the secret is the content of `~/.config/marketing-engine/bootstrap_secret`. Alternatively, create the user in the dashboard and set `is_platform_admin`. Then:
  1. Create the organization (`POST organizations`).
  2. Register and publish the methodology version (`POST methodology-versions`, then `/transition`).
  3. Invite the team.
- **Running tests:** set `MKTENG_API_BASE`, `MKTENG_ADMIN_EMAIL` and `MKTENG_ADMIN_PASSWORD` to a **synthetic** platform admin, then run `python3 tests/e2e_research_engine.py`. The suite creates `SYNTHETIC …` organizations and `@example.test` users; remove them afterwards. Because the cleanup endpoint is temporary, re-create it only for test windows.
