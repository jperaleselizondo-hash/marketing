# Phase 2A implementation: WeWeb frontend foundation (Research Engine)
Date: 2026-10-29. Status: **BUILT in the WeWeb editor, NOT published. Browser QA (§7, A1–A10) and the catch-branch error handling (§6.1) are UNVERIFIED. The Xano metadata token's permissions are reported broad and need remediation (§6.6).**

- **WeWeb project:** Marketing Engine, `6b4943ea-eedb-4dc7-82bb-c3bbc9b690e2`. It is the only WeWeb project touched. Goodz V2 and KMUI were listed by `getMe` but never opened.
- **Backend:** Xano workspace 3, branch `v1`, through the existing API contracts. No Xano schema, endpoint or data change was made.
- **Scope:** login, session handling, protected routes, logout and expired session, responsive app shell, organization context and role-aware UI, research dashboard, project list and creation, project detail.
- **Contracts used:** [docs/12](12-WEWEB-FRONTEND-HANDOFF.md) and [docs/11 §2](11-PHASE-1-IMPLEMENTATION.md).

---

## 1. Access verification (Step 1)
| Check | Result |
|---|---|
| WeWeb MCP connection | `ping` → connected |
| Account projects (`getMe`) | KMUI, Goodz V2, **Marketing Engine `6b4943ea-…`** (never edited before this session) |
| Write targeting | Every WeWeb MCP tool takes an explicit `projectId`; every call in this session passed `6b4943ea-eedb-4dc7-82bb-c3bbc9b690e2` |
| Initial state | Pages: Home (empty) and 404. No WeWeb backend, auth or storage installed. Starter zinc color tokens only |
| Xano connection (created by the founder in the browser) | `66ed4281-af9d-41dc-ba76-ff5c8d1faf0f`. Its API groups are exactly the 8 workspace-3 groups on branch `v1`; no Goodz or PMF groups are visible |
| CORS | Preflight from the editor origin returns 200 with that origin allowed |

## 2. Architecture decisions (see ADR-022)
- **Xano is the backend and the auth provider** (`setProjectAuthProvider: xano`). There is no WeWeb backend, so every call goes from the browser straight to Xano, as docs/12 §2 requires for the per-IP rate limits.
- **Native Xano integration** (founder's choice). The connection holds a **Xano Metadata API token**. This is a conscious exception to docs/12's "no Xano metadata tokens in WeWeb", made because the integration form required one.
  - **Storage:** a WeWeb environment variable managed by the connection. The founder confirmed it is flagged **Secure**: encrypted, available only server-side, never shipped to browsers.
  - **Permissions:** reported **broad** by the founder. The exact scopes are **unverified** (§6.6).
- **Token storage:** the Xano auth plugin (`auth-set-session`, persisted) holds the token. It is never put in a variable, a URL or a log. "Sign out" is client-side, because Xano has no server-side logout.
- **Route protection:** a guard workflow (`requireSession`) runs on every private page. It always re-fetches `GET auth/me`, so role or membership changes apply on the next navigation. A 401 clears the session and sends the user to Login. The guard is client-side; the server enforces access on every request regardless.
- **Organization context:**
  - `selectedOrgId` is stored in localStorage and **re-validated against active memberships on every page load**. A tampered or stale id is replaced or cleared.
  - Exactly one membership is selected automatically. With zero memberships, or several and no valid selection, the user goes to Select Organization.
- **Roles are hints only.** Buttons are hidden or disabled with the `roleAtLeast` formula, or with the `role` returned by `GET projects/{id}`. The API remains the authority.
- **Data is loaded by workflows into variables, not WeWeb table views.** This allows uniform 401 handling and loading/error states through one central handler (`handleApiError`).

## 3. Screens
| Page | Path | Access | Content |
|---|---|---|---|
| Login | `/login` | public | Email/password form, "Session expired — sign in again" notice (`?reason=expired`), generic error wording, invite-only note |
| Select Organization | `/select-organization` | signed in | Active memberships with role badges; "No organization access" state; platform-admin note; sign out |
| Dashboard (home) | `/dashboard` | signed in + organization | Organization and role, 4 stat cards (active, draft/scoped, collecting, synthesizing), 5 most recent projects, "New project" for editors and above |
| Research projects | `/projects` | signed in + organization | Server-side status filter, project rows (title, objective, created, id, status badge), loading/empty/error states |
| New project | `/new-project` | signed in + organization (editor+ to submit) | Product, published methodology version, title, objective, optional scope/geography/locale. Explains a missing role or missing prerequisites |
| Project detail | `/project/{project_id}` | signed in (server authorizes the project) | Status, role and revision badges; lifecycle help and the transitions allowed for the role; evidence counts "in the collected sample"; overview fields; owner-only archive with a required reason; "not found or no access" state |
| 404 | `/404` | public | Pre-existing template page |

**App shell:**
- A reusable **App Sidebar** section (brand, organization switcher with role, Dashboard / Research projects navigation with active state, user identity, Sign out) appears on all four app pages.
- Desktop: fixed 240px. Tablet and mobile: a sticky top bar.

**Design system:**
- 33 new tokens extend the starter palette: colors with light and dark values, typography, spacing, radius, shadows and borders.
- 41 classes cover text, buttons with hover states, inputs, containers, navigation, badges and accents.
- The guidelines are written in the WeWeb design system (direction, mapping from status to badge, layout and implementation patterns).

## 4. API integrations
All calls use the `xano/request` action on connection `66ed4281…`. The token is added automatically by the plugin.

| Workflow | Endpoint | Notes |
|---|---|---|
| Sign in (Login form submit) | `POST Sbj3o3SC /auth/login` | → `auth-set-session` (persist) → Dashboard |
| On user load (app, `xano/auth-refresh`) | `GET Sbj3o3SC /auth/me` | → `currentAccount`, `auth-set-user`; an invalid token is cleared |
| `requireSession(requireOrg)` | `GET Sbj3o3SC /auth/me` | Route guard plus organization validation (§2) |
| `loadProjects(status)` | `GET mkteng-research /organizations/{org}/projects[?status=]` | `status` is sent only when set |
| New project load | `GET mkteng-catalog /organizations/{org}/products`, `GET mkteng-catalog /methodology-versions?status=published` | Options for the form |
| Create project (form submit) | `POST mkteng-research /organizations/{org}/projects` | Empty optional fields are omitted → opens `/project/{id}` |
| `loadProject(projectId)` | `GET mkteng-research /projects/{project_id}` | Also aligns `selectedOrgId` with the project's organization if the user is a member |
| `transitionProject(toStatus, reason)` | `POST mkteng-research /projects/{project_id}/transition` | Reloads the project afterwards |
| `endSession(expired)` | — | `auth-clear-session`, cached data reset → Login |
| `handleApiError(error, target)` | — | 401 → `endSession`; otherwise the message from `apiError` goes into `ui[target]` |

**State:**
- Variables: `currentAccount`, `selectedOrgId` (localStorage), `hadSession` (localStorage, boolean only), `projects`, `currentProject`, `products`, `methodologyVersions`, and `ui` (busy flags and error messages).
- Formulas: `currentMembership`, `roleAtLeast`, `apiError` (decodes `CODE: text` messages per docs/12 §6) and `formatTimestamp`.

**The lifecycle buttons mirror the server's allowed-transition map:**
- `draft→scoped`;
- `scoped→collecting|draft`;
- `collecting→synthesizing`;
- `synthesizing→collecting`;
- `archived→collecting` (owner only).

"Archive" is a separate owner-only card with a required reason.

## 5. Tests performed (2026-10-29)
| Test | Result |
|---|---|
| MCP access and project identity (§1) | Pass |
| The Xano connection exposes only workspace-3 API groups (8, branch `v1`) | Pass |
| Endpoint contract sweep: every path/method used by the workflows called without a token from the editor origin | 7 × 401 as expected. `POST organizations/1/projects` with an empty body returns **400 `Missing param`** before the auth check (see the next row) |
| Unauthenticated input validation (`POST organizations/{org}/projects`, `POST projects/{id}/transition`) | Xano checks declared inputs **before** `auth = "user"`. A missing, mistyped or out-of-enum input returns 400 `ERROR_CODE_INPUT_ERROR` naming the parameter (e.g. `Missing param: product_id`, `Value is not a valid integer.`, "not one of the allowable values"). A well-formed body returns 401 for both an existing (1) and a non-existent (999999) organization. No database lookup or write happens before auth, and there is no existence oracle. The disclosed information equals the public API spec (`/apispec:<group>`, HTTP 200 without auth). **Not sensitive; no fix needed.** Optional hardening: hide the public API spec per group in Xano |
| CORS preflight from the editor origin (GET and POST with `authorization`) | Pass |
| Unit check, in Node, of the JS bodies of `apiError`, `roleAtLeast`, `currentMembership`, organization validation and transition options, against the documented response shapes | **All assertions pass**. Covers: code prefix parsing, 401/403/404/rate-limit wording, single-membership auto-select, a tampered localStorage id, an inactive membership, multiple memberships → picker, role gates, transitions per status and role |
| Every workflow accepted by the WeWeb validator and registered | **20 workflows:** 6 function, 5 page, 1 app (`xano/auth-refresh`) and 8 element (Sign in, Sign out ×2, Choose organization, Status filter change, Create project, Transition click, Archive click) |

**Not tested by Claude:** anything that requires signing in. There are no test credentials, and the only account is the founder's. No synthetic users or data were created; Xano is unchanged.

## 6. Known issues and risks
1. **Unverified error path in catch branches.** The workflows read the caught error as `context.workflow['tc'].error`, falling back to `context.workflow.error`. WeWeb does not document this path. If it is wrong:
   - every API error shows the generic message;
   - a 401 inside a catch would not redirect.

   The guard's `filter` still stops the page. **Verify with the first failed sign-in (§7, A2)** using the workflow execution logs.
2. **Client-side route protection.** The shell of a private page can render for a moment before the guard redirects. No data is shown, since all data comes from authenticated calls. WeWeb's own "unauthenticated page" setting is still empty (`unauthenticatedPageId: null`); the founder can set it to Login in the editor if WeWeb offers it for Xano auth.
3. **Two `auth/me` calls per page load** (On user load plus the guard), traded for fresh roles. Acceptable for now.
4. **Project creation currently fails by design:**
   - workspace 3 has no product and no published methodology version (founder instruction, docs/12 §5);
   - the form explains which prerequisite is missing.
5. **Project detail shows product and methodology as `#id`.** There is no lookup by name yet.
6. **Xano Metadata API token stored in WeWeb — REMEDIATION REQUIRED** (ADR-022).
   - **Browser exposure:** none. The WeWeb variable is Secure (founder-confirmed), and the runtime never needs the token: login and data calls use only the instance domain plus the user's own auth token.
   - **Who can use it:** anyone with editor access to the WeWeb project (and its MCP), through the editor's server-side integration functions.
   - **Permissions:** reported **broad** by the founder; exact scopes **unverified**. Neither the Xano CLI nor the WeWeb MCP can list Metadata API token scopes without reading the token, which was not done.
   - **Why it matters:** if the token is not limited to workspace 3, it may reach Goodz (ws 1) and PMF (ws 2) on the same instance. With database, content or write scopes it could read or alter records, schemas or endpoints.
   - **What WeWeb needs:** the integration uses it only for editor discovery (listing API groups and endpoints). It therefore needs, at most, read access to workspace 3's API groups/endpoints.
   - **Plan:** least-privilege replacement, pending founder approval.
7. **Unauthenticated input validation precedes auth** (§5). Platform behavior; discloses only the public input schema. No fix needed.
8. **Production CORS** is not checked: the app is unpublished. Xano echoed the editor origin, and the published domain must be re-checked before go-live.
9. **Rate limits use `$env.$remote_ip`** (docs/11 §9.3). It is still unverified whether this sees the real browser IP.
10. **Not built in Phase 2A** (out of scope):
   - Accept-invitation page;
   - organization creation;
   - members and invitations management;
   - brands and products management;
   - methodology admin;
   - the evidence workspaces (segments, sources, observations, product, competitors, synthesis, review queue, reports, activity).
11. **Visual QA pending:** tablet/mobile top bar, select trigger styling, dark theme.

## 7. Browser QA for the founder (A1–A10) — UNVERIFIED
Run in the WeWeb editor **Preview** with your own account, and note the clock time of each step.
- **Synthetic titles only.**
- **No more than 4 wrong passwords** per 15 minutes: the 5th failure locks the email.
- **For A2, type an obviously fake password** (e.g. `wrong-on-purpose-1`), never a variant of your real one. Execution logs may record the request a workflow sent.

**Runnable now:**

| # | Steps | Expected |
|---|---|---|
| A1 | Signed out (fresh preview), open `/dashboard` | Redirect to Login, without the "Session expired" notice |
| A2 | Your email plus the fake password → Sign in. Note the time | "Sign-in failed. Check your email and password." Then Claude reads the **Sign in** workflow trace (`c156a152-…`) to verify the catch-branch error path (§6.1) |
| A3 | Sign in with the correct password | Dashboard (one membership) or Select Organization (several). The sidebar shows organization, role, name and email |
| A4 | On `/projects`, reload the browser | Still signed in; empty state "No projects match" |
| A5 | Change the status filter; click both sidebar items; narrow the window to tablet/mobile | The list reloads without error; the active item highlights; the sidebar becomes a top bar |
| A6 | Open `/new-project` | Notice naming the missing product and published methodology version |
| A7 | Open `/project/999999` | "Project not available — Not found, or you do not have access." |
| A8 | Click the organization card in the sidebar | Select Organization lists your memberships with role badges |
| A9 | In devtools, Application tab: delete the stored Xano session entries for the preview origin, then navigate to another page | Login with "Session expired — sign in again" |
| A10 | Sign in, click Sign out, then press Back | Login, with no project data visible |

**Blocked until a product and a published methodology version exist:**
- B1: create a project; it opens as `draft`.
- B2: "Mark as scoped" without segments; refused with `GATE_R0_SCOPE`.
- B3: archive without a reason (refused), then with a reason; restore as owner.
- B4: dashboard counts and recent list with real rows.
- B5: viewer/editor role views. This also needs a second invited account.

## 8. Next steps (Phase 2B candidates)
- Accept-invitation page.
- Members and invitations management (owner).
- Brands and products management.
- Then the project workspace tabs from docs/12 §4, in gate order R0 → R5.
