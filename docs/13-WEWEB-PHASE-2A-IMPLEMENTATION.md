# Phase 2A implementation: WeWeb frontend foundation (Research Engine)
Date: 2026-10-29. Status: **BUILT in the WeWeb editor, NOT published. Browser validation by the founder is still pending (§7).**

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
- **Native Xano integration** (founder's choice). The connection holds a **Metadata API key restricted to workspace 3**. This is a conscious exception to docs/12's "no Xano metadata tokens in WeWeb", made because the integration form required one.
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
| Endpoint contract sweep: every path/method used by the workflows called without a token from the editor origin | 7 × 401 as expected. `POST organizations/1/projects` returns **400 `Missing param`** before the auth check (Xano validates inputs first; nothing is written, and parameter names are public in the swagger) |
| CORS preflight from the editor origin (GET and POST with `authorization`) | Pass |
| Unit check, in Node, of the JS bodies of `apiError`, `roleAtLeast`, `currentMembership`, organization validation and transition options, against the documented response shapes | **All assertions pass**. Covers: code prefix parsing, 401/403/404/rate-limit wording, single-membership auto-select, a tampered localStorage id, an inactive membership, multiple memberships → picker, role gates, transitions per status and role |
| Every workflow accepted by the WeWeb validator and registered | 6 function workflows, 5 page workflows, 1 app workflow and 7 element workflows |

**Not tested by Claude:** anything that requires signing in. There are no test credentials, and the only account is the founder's. No synthetic users or data were created; Xano is unchanged.

## 6. Known issues and risks
1. **Unverified error path in catch branches.** The workflows read the caught error as `context.workflow['tc'].error`, falling back to `context.workflow.error`. WeWeb does not document this path. If it is wrong:
   - every API error shows the generic message;
   - a 401 inside a catch would not redirect.

   The guard's `filter` still stops the page. **Verify with the first failed sign-in (§7, check 2)** using the workflow execution logs.
2. **Client-side route protection.** The shell of a private page can render for a moment before the guard redirects. No data is shown, since all data comes from authenticated calls. WeWeb's own "unauthenticated page" setting is still empty (`unauthenticatedPageId: null`); the founder can set it to Login in the editor if WeWeb offers it for Xano auth.
3. **Two `auth/me` calls per page load** (On user load plus the guard), traded for fresh roles. Acceptable for now.
4. **Project creation currently fails by design:**
   - workspace 3 has no product and no published methodology version (founder instruction, docs/12 §5);
   - the form explains which prerequisite is missing.
5. **Project detail shows product and methodology as `#id`.** There is no lookup by name yet.
6. **Metadata API key stored in WeWeb** (ADR-022):
   - confirm in Xano that the key is restricted to workspace 3, with the narrowest scope offered;
   - rotate it if the WeWeb project is ever shared outside the founder's account.
7. **Production CORS** is not checked: the app is unpublished. Xano echoed the editor origin, and the published domain must be re-checked before go-live.
8. **Rate limits use `$env.$remote_ip`** (docs/11 §9.3). It is still unverified whether this sees the real browser IP.
9. **Not built in Phase 2A** (out of scope):
   - Accept-invitation page;
   - organization creation;
   - members and invitations management;
   - brands and products management;
   - methodology admin;
   - the evidence workspaces (segments, sources, observations, product, competitors, synthesis, review queue, reports, activity).
10. **Visual QA pending:** tablet/mobile top bar, select trigger styling, dark theme.

## 7. Browser checks for the founder
Run them in the WeWeb editor **Preview**, signed in with your own account. Use synthetic project titles only, and archive or record them for clean-up afterwards.
1. **Signed-out redirect:** open `/dashboard` in a fresh preview → you should land on Login, without the expired notice.
2. **Failed sign-in:** use a wrong password once → "Sign-in failed. Check your email and password." Then ask Claude to read `getWorkflowExecutionLogs` for workflow "Sign in", to confirm the catch-branch error path (§6.1). Do not exceed 5 failures: the rate limit blocks the email for 15 minutes.
3. **Sign in** → Dashboard (with one membership) or Select Organization (with several). The sidebar shows the organization, your role, your name and your email.
4. **Reload the browser** on `/projects` → you stay signed in (the session is persisted).
5. **Navigation:** the active sidebar item highlights; on tablet and mobile widths the sidebar becomes a top bar.
6. **New project:**
   - without a product or a published methodology, the prerequisite notice appears;
   - once they exist, creating a project opens its detail page with status `draft`.
7. **Project detail:**
   - "Mark as scoped" without segments → the `GATE_R0_SCOPE` message;
   - an owner sees the Archive card, and archiving without a reason is refused.
8. **Expired session:** in the browser devtools, delete the stored Xano session (or wait 8 h), then navigate → Login with "Session expired — sign in again".
9. **Sign out** → Login. The back button must not show any data.
10. **Role view:** if a viewer or editor test account is invited later, check that "New project" and the lifecycle buttons hide or disable correctly.

## 8. Next steps (Phase 2B candidates)
- Accept-invitation page.
- Members and invitations management (owner).
- Brands and products management.
- Then the project workspace tabs from docs/12 §4, in gate order R0 → R5.
