# WeWeb frontend handoff — Research Engine (Phase 1A)
Date: 2026-10-29. Status: **brief. Phase 2A was implemented from it in the WeWeb project "Marketing Engine"; see [docs/13](13-WEWEB-PHASE-2A-IMPLEMENTATION.md), which records deviations (e.g. ADR-022).**
- Backend: Xano workspace 3, branch `v1` (live).
- Full API inventory: [docs/11 §2](11-PHASE-1-IMPLEMENTATION.md).
- Contracts below are taken from the deployed XanoScript in `xano/`.

**Current data:**
- one platform administrator (owner);
- organization **Marketing Engine** (`id 1`, slug `marketing-engine`);
- no brands, products, methodology versions or projects yet.

## 1. Environment and connection
| WeWeb variable | Value | Notes |
|---|---|---|
| `XANO_BASE_URL` | the Xano instance origin (see `xano profile list`) | Public; not a secret. Keep it out of the public git repo anyway. |
| `API_AUTH` | `{XANO_BASE_URL}/api:Sbj3o3SC` | Authentication |
| `API_ORG` | `{XANO_BASE_URL}/api:mkteng-org` | Organizations, members, invitations, audit |
| `API_CATALOG` | `{XANO_BASE_URL}/api:mkteng-catalog` | Brands, products, methodology versions |
| `API_RESEARCH` | `{XANO_BASE_URL}/api:mkteng-research` | Projects, segments, sources, excerpts, observations |
| `API_PRODUCT` | `{XANO_BASE_URL}/api:mkteng-product` | Capabilities, benefits, links, proofs |
| `API_COMPETITORS` | `{XANO_BASE_URL}/api:mkteng-competitors` | Competitors, competitor observations |
| `API_SYNTHESIS` | `{XANO_BASE_URL}/api:mkteng-synthesis` | Insights, support, rankings, benefit–desire links, assessments |
| `API_WORKFLOW` | `{XANO_BASE_URL}/api:mkteng-workflow` | Reviews, reports, jobs |

- **Branch:** the live branch is `v1`, so no branch suffix is needed. To pin it explicitly, use `api:<canonical>:v1`.
- **Never in WeWeb:** `MKTENG_BOOTSTRAP_SECRET`, `MKTENG_PSEUDONYM_KEY`, Xano metadata tokens.
- **Request headers:**
  - `Content-Type: application/json`;
  - `Authorization: Bearer <authToken>` on every call except `auth/login` and `auth/accept-invite`.
- **To verify before go-live:** CORS for the WeWeb domain. The default Xano CORS settings have not been tested from a browser.

## 2. Authentication
| Step | Request | Response |
|---|---|---|
| Login | `POST {API_AUTH}/auth/login` `{email, password}` | `{authToken}` (valid **8 h**) |
| Current user | `GET {API_AUTH}/auth/me` | `{user: {id, name, email, status, is_platform_admin, last_login_at}, memberships: [{id, organization_id, organization_name, organization_slug, role, status}]}` |
| New user from invitation | `POST {API_AUTH}/auth/accept-invite` `{token, name, password}` | `{authToken}`. Password: ≥ 12 characters, at least 1 letter and 1 digit. |
| Existing user joins another org | `POST {API_ORG}/invitations/accept` `{token}` (authenticated) | `{success, organization_id, role}` |

There is **no** public signup, password reset, refresh token or server-side logout.

**Session handling:**
- Store `authToken` through the WeWeb Xano Auth plugin, configured with custom login and me endpoints. Keep it in the plugin's storage, not in visible variables or URLs.
- Call `auth/me` on app load and after login.
- On any **401**, clear the token and redirect to Login.
- Logout means discarding the token on the client.
- **The 8-hour expiry is fixed.** Show "Session expired — sign in again", and don't try to refresh silently.

**Invitations:**
- When an owner creates one, the response contains the plaintext `token` **once**. The UI shows it as a copyable link `https://<app>/accept-invite?token=<token>`.
- The token is never retrievable again. A new invitation for the same email revokes the old one. Invitations expire after 72 h.
- The Accept-invite page reads `token` from the URL and asks for name and password.
- If the response is `ACCOUNT_EXISTS`, send the user to Login, then call `invitations/accept`.

**Rate limits (403 `RATE_LIMITED`):**
- login: 5 failed attempts per email, or 30 attempts per IP, per 15 minutes;
- accept-invite: 10 per IP per hour.

Calls must go **from the browser directly to Xano**, not through a WeWeb server proxy. Otherwise every user shares one IP and the per-IP limits would apply to everyone together.

## 3. Organization selection and roles
- After `auth/me`:
  - 0 memberships → "No organization access" page. A platform admin additionally gets "Create organization" (`POST {API_ORG}/organizations {name, slug}`).
  - 1 membership → auto-select.
  - More than 1 → organization picker. Persist the selected `organization_id` in local storage, and re-validate it against `memberships` on load.
- Every organization-scoped call carries the organization or project ID in the path. The server enforces membership on every call. **A 404 can mean "not a member"**, so treat it as "not found or no access".
- **Role permissions.** The UI should hide or disable actions accordingly; the server enforces them regardless.

| Role | Can do |
|---|---|
| viewer | read everything in the organization |
| editor | create and edit candidate items; submit for review; generate and submit reports |
| reviewer | editor rights plus approve/reject/reopen, verify excerpts and capabilities, approve and reject reports |
| owner | reviewer rights plus invitations, member roles, archive/restore projects |
| platform admin (flag on user) | create organizations; create and publish methodology versions. **No implicit access to organization data.** |

## 4. Navigation
```
Login · Accept invitation
└─ Organization picker
   ├─ Projects (list, create)
   │  └─ Project workspace (tabs)
   │     ├─ Overview      status + transition buttons, counts, current report, stale badge
   │     ├─ Segments      buyers / suppliers kept separate
   │     ├─ Sources       privacy/rights classification, excerpts per source, verification badges
   │     ├─ Observations  IVOC categories, type (verbatim vs analyst), provenance badge, filters
   │     ├─ Product       capabilities (live/beta/roadmap), benefits, capability→benefit links, proofs
   │     ├─ Competitors   competitor matrix by dimension; claim vs analyst note side by side
   │     ├─ Synthesis     insights with supporting/contradicting evidence, rankings, benefit→desire links
   │     ├─ Assessments   awareness, sophistication, ideal client, trust, market, competitive
   │     ├─ Review queue  candidate / in_review items across types → POST reviews
   │     ├─ Reports       versions, generate, submit, approve/reject, verify, report viewer
   │     └─ Activity      review-events feed for the project
   ├─ Brands & products
   ├─ Members & invitations (owner)
   └─ Methodology versions (platform admin)
```

## 5. Recommended first workflow (Goodz pilot, gates R0–R5)
**Prerequisites (outside the research flow):**
1. A platform admin registers and publishes the methodology version: `POST {API_CATALOG}/methodology-versions`, then `/transition {to_status: "published"}`. *Not done yet, by founder instruction.*
2. Create the brand **Goodz** and its product: `POST organizations/{org}/brands`, then `POST brands/{id}/products`.
3. Invite at least one reviewer, so the people who create items aren't the only ones reviewing them.

**Research flow:**
| # | Screen action | API |
|---|---|---|
| 1 | Create project | `POST {API_RESEARCH}/organizations/{org}/projects {product_id, methodology_version_id, title, objective, scope?, target_geography?, target_locale?}` |
| 2 | Add segments **Buyers** and **Suppliers** | `POST projects/{id}/segments {name, segment_type: buyer\|supplier}` |
| 3 | Scope, then start collecting (R0) | `POST projects/{id}/transition {to_status: "scoped"}` → `"collecting"` |
| 4 | Register a source with rights/privacy classification | `POST projects/{id}/sources` (`source_kind`, `title`, `language_code`, `acquisition_method`, `access_conditions`, optional `canonical_url`, `content_text`, `usage_rights`, `personal_data_class`, `processing_basis_status`, …). A duplicate URL returns `{duplicate: true}` with the existing source. |
| 5 | Add excerpts | `POST sources/{id}/excerpts {exact_text, speaker_handle?, speaker_role?}`. Auto-verified if the source has content. A reviewer confirms the rest via `POST excerpts/{id}/verify {human_confirmed: true}`. |
| 6 | Record observations with IVOC categories | `POST projects/{id}/observations {observation_type, research_segment_id, source_excerpt_id?, original_text?, ivoc_categories[]}` |
| 7 | Product facts (R1) | capabilities, benefits, links, proofs; then `POST capabilities/{id}/verify {decision: "verify"}` (needs an approved proof) |
| 8 | Competitors (R2) | `POST projects/{id}/competitors`, then `POST competitors/{id}/observations` |
| 9 | Review evidence (R3) | `POST {API_WORKFLOW}/reviews {entity_type, entity_id, decision, reason?}` for sources and observations |
| 10 | Synthesis (R4) | insights → `POST insights/{id}/support` → approve support and insights → `PUT projects/{id}/rankings` → benefit-desire links → assessments, each approved via `reviews` |
| 11 | Report (R5) | `POST projects/{id}/reports` → `POST reports/{id}/submit` → (reviewer) `POST reports/{id}/approve` → `GET reports/{id}/verify` |

**Required approval order:**
1. observation approved, before its support link;
2. support link approved, before an *evidenced* insight;
3. insight approved, before its ranking and benefit-desire link;
4. benefit approved, before capability-benefit and benefit-desire links.

Hypothesis insights need no evidence, but appear in the report only under "Hypotheses and gaps".

## 6. Error handling
- **Response shape:** errors come back as `{code, message}`. Take the machine code from `message` up to the first `:` (e.g. `STALE_REPORT: Evidence changed…`); the rest is human-readable.
- **Timestamps:** epoch milliseconds.
- **Paged lists:** sources, excerpts, observations and review events return `{items, itemsReceived, itemsTotal, curPage, nextPage, prevPage, perPage}`. Other lists return arrays.

| HTTP | Code(s) | UX |
|---|---|---|
| 401 | — | Session expired → Login |
| 403 | `FORBIDDEN` | "Your role can't do this." Hide the action. |
| 403 | `RATE_LIMITED` | "Too many attempts; try later." |
| 403 | `Invalid Credentials.` / `INVALID_INVITATION` / `ACCOUNT_INACTIVE` | Generic sign-in / invitation error; don't reveal which field was wrong |
| 404 | `NOT_FOUND` | "Not found or no access." Return to the list. |
| 400 | `VALIDATION`, `DUPLICATE`, `WEAK_PASSWORD`, `ACCOUNT_EXISTS`, `ALREADY_MEMBER` | Inline form errors |
| 400 | `INVALID_TRANSITION`, `REASON_REQUIRED`, `IMMUTABLE`, `INSIGHT_LOCKED`, `PROJECT_ARCHIVED` | Explain state; offer **Reopen** (with reason) where allowed |
| 400 | `EVIDENCE_REQUIRED`, `OBSERVATION_NOT_APPROVED`, `LINK_PREREQUISITES`, `PROOF_REQUIRED`, `EXCERPT_NOT_VERIFIED`, `RANKING_REQUIRES_APPROVED_INSIGHT`, `NOT_A_DESIRE`, `SEGMENT_MISMATCH`, `CROSS_SEGMENT_NOTE_REQUIRED`, `GATE_R0_SCOPE` | Show the missing prerequisite, with a link to it |
| 400 | `STALE_REPORT` | "Evidence changed since this version was generated." Offer **Generate new version**. |
| 400 | `BLOCKING_ISSUES`, `INTEGRITY_ERROR` | Block approval; show `report_json.blocking_issues`; escalate integrity errors |
| 500 | — | Generic error with retry; log the request |

## 7. Evidence-integrity UI rules (non-negotiable)
- **Verbatim quotes:** label them distinctly from paraphrases and analyst notes. Never let users type a "quote" that isn't backed by a verified excerpt; the API rejects it anyway.
- **Badges:** show `origin`, `provenance_status`, `verification_status` and `evidence_basis` as badges. AI-proposed content (Phase 1B) must remain visually distinct.
- **Withheld text:** in reports, entries with `text: null` show their `text_withheld_reason`; never hide that they exist.
- **Counts:** label them "in the collected sample", not market percentages.
- **Approved items** are read-only. Corrections use **Reopen** (with a reason) or **Supersede excerpt**.
- **Freshness badges:** show `is_stale` / `is_current` on report views (`GET reports/{id}` returns both).

## 8. Known backend gaps relevant to the frontend
- **Not available:** password reset, token refresh, organization rename/archive, user suspension UI, invitation emails (links are copied manually), file upload for source documents.
- **Rate limits** return 403, not 429.
- **Report generation** is synchronous. Expect a few seconds on large projects, and show a spinner. There is no job polling yet.
