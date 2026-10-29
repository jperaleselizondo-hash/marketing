"""End-to-end tests for the Marketing Engine Research Engine API (Xano workspace 3).

Uses synthetic data only (organizations named "SYNTHETIC ...", users @example.test).
Required env: MKTENG_API_BASE, MKTENG_ADMIN_EMAIL, MKTENG_ADMIN_PASSWORD (a platform administrator).
Writes created organization ids to MKTENG_TEST_STATE (default ./e2e_state.json) for cleanup.
Note: auth/accept-invite is limited to 10 calls per IP per hour; this suite uses 6.
"""
import hashlib, json, os, sys, threading, time, urllib.error, urllib.parse, urllib.request

BASE = os.environ["MKTENG_API_BASE"].rstrip("/")
GROUPS = {"auth": "Sbj3o3SC", "org": "mkteng-org", "catalog": "mkteng-catalog", "research": "mkteng-research", "product": "mkteng-product",
          "competitors": "mkteng-competitors", "synthesis": "mkteng-synthesis", "workflow": "mkteng-workflow"}
RESULTS = []

def call(group, method, path, body=None, token=None, query=None):
    url = f"{BASE}/api:{GROUPS[group]}/{path}" + ("?" + urllib.parse.urlencode(query) if query else "")
    data = json.dumps(body).encode() if body is not None and method != "GET" else None
    headers = {"Content-Type": "application/json", **({"Authorization": f"Bearer {token}"} if token else {})}
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read().decode(); return r.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: return e.code, json.loads(raw)
        except Exception: return e.code, raw

def msg(b): return b.get("message", "") if isinstance(b, dict) else str(b)[:120]

def check(section, name, cond, detail=""):
    RESULTS.append({"section": section, "test": name, "pass": bool(cond), "detail": detail})
    print(("PASS " if cond else "FAIL ") + f"[{section}] {name}" + (f" -- {detail}" if detail and not cond else ""))
    return cond

def expect(section, name, resp, status, code=None):
    s, b = resp
    ok = s == status and (code is None or msg(b).startswith(code))
    check(section, name, ok, f"got {s} {msg(b)}")
    return b

def main():
    run = str(int(time.time()))
    state_path = os.environ.get("MKTENG_TEST_STATE", "e2e_state.json")
    pw = "Synthetic-Pass-" + run
    s, b = call("auth", "POST", "auth/login", {"email": os.environ["MKTENG_ADMIN_EMAIL"], "password": os.environ["MKTENG_ADMIN_PASSWORD"]})
    assert s == 200, f"admin login failed: {s} {msg(b)}"
    admin = b["authToken"]

    # ---------- setup ----------
    m = call("catalog", "POST", "methodology-versions", {"key": f"synthetic-e2e-{run}", "version": "1.0", "title": "SYNTHETIC methodology"}, token=admin)[1]
    call("catalog", "POST", f"methodology-versions/{m['id']}/transition", {"to_status": "published"}, token=admin)
    org_a = call("org", "POST", "organizations", {"name": f"SYNTHETIC A {run}", "slug": f"synthetic-a-{run}"}, token=admin)[1]["organization"]["id"]
    org_b = call("org", "POST", "organizations", {"name": f"SYNTHETIC B {run}", "slug": f"synthetic-b-{run}"}, token=admin)[1]["organization"]["id"]
    json.dump({"run": run, "org_ids": [org_a, org_b]}, open(state_path, "w"))
    users = {}
    for org, role, key in [(org_a, "editor", "editor"), (org_a, "reviewer", "reviewer"), (org_a, "viewer", "viewer"), (org_b, "editor", "outsider")]:
        email = f"synthetic.{key}.{run}@example.test"
        inv = call("org", "POST", f"organizations/{org}/invitations", {"email": email, "role": role}, token=admin)[1]
        s, b = call("auth", "POST", "auth/accept-invite", {"token": inv["token"], "name": f"SYNTHETIC {key}", "password": pw})
        check("auth", f"accept invite as {key}", s == 200, msg(b))
        users[key] = b.get("authToken")
        users[key + "_token"] = inv["token"]
    E, R, V, O = users["editor"], users["reviewer"], users["viewer"], users["outsider"]

    # ---------- A. authentication ----------
    S = "auth"
    expect(S, "public signup removed", call("auth", "POST", "auth/signup", {"email": "x@example.test", "password": pw, "name": "x"}), 404)
    expect(S, "bootstrap disabled once an admin exists", call("auth", "POST", "auth/bootstrap-admin", {"bootstrap_secret": "x" * 40, "name": "x", "email": f"b.{run}@example.test", "password": pw}), 403, "BOOTSTRAP_DISABLED")
    expect(S, "reusing an accepted invitation is rejected", call("auth", "POST", "auth/accept-invite", {"token": users["editor_token"], "name": "x", "password": pw}), 403, "INVALID_INVITATION")
    inv = call("org", "POST", f"organizations/{org_a}/invitations", {"email": f"synthetic.revoked.{run}@example.test", "role": "viewer"}, token=admin)[1]
    call("org", "POST", f"invitations/{inv['invitation']['id']}/revoke", {}, token=admin)
    expect(S, "revoked invitation is rejected", call("auth", "POST", "auth/accept-invite", {"token": inv["token"], "name": "x", "password": pw}), 403, "INVALID_INVITATION")
    expect(S, "non-owner cannot invite", call("org", "POST", f"organizations/{org_a}/invitations", {"email": f"n.{run}@example.test", "role": "viewer"}, token=R), 403, "FORBIDDEN")
    rl_email = f"synthetic.ratelimit.{run}@example.test"
    codes = [call("auth", "POST", "auth/login", {"email": rl_email, "password": "wrong-password-1"}) for _ in range(6)]
    check(S, "5 failed logins allowed, 6th rate limited", all(c[0] == 403 and msg(c[1]) == "Invalid Credentials." for c in codes[:5]) and msg(codes[5][1]).startswith("RATE_LIMITED"), str([msg(c[1])[:14] for c in codes]))
    me = call("auth", "GET", "auth/me", token=E)[1]
    check(S, "auth/me lists membership", any(x["organization_id"] == org_a and x["role"] == "editor" for x in me["memberships"]))
    expect(S, "last owner cannot be demoted", call("org", "PATCH", f"members/{[x for x in call('org','GET',f'organizations/{org_a}/members', token=admin)[1] if x['role']=='owner'][0]['id']}", {"role": "editor"}, token=admin), 400, "LAST_OWNER")

    # ---------- project setup in org A ----------
    brand = call("catalog", "POST", f"organizations/{org_a}/brands", {"name": "SYNTHETIC Brand"}, token=E)[1]
    product = call("catalog", "POST", f"brands/{brand['id']}/products", {"name": "SYNTHETIC Product", "lifecycle_status": "beta"}, token=E)[1]
    pj = call("research", "POST", f"organizations/{org_a}/projects", {"product_id": product["id"], "methodology_version_id": m["id"], "title": "SYNTHETIC Goodz-like pilot", "objective": "market_awareness"}, token=E)[1]["id"]
    buyers = call("research", "POST", f"projects/{pj}/segments", {"name": "Buyers", "segment_type": "buyer"}, token=E)[1]
    suppliers = call("research", "POST", f"projects/{pj}/segments", {"name": "Suppliers", "segment_type": "supplier"}, token=E)[1]
    for st in ["scoped", "collecting"]:
        call("research", "POST", f"projects/{pj}/transition", {"to_status": st}, token=E)

    # ---------- B. organization isolation and roles ----------
    S = "isolation"
    src_a = call("research", "POST", f"projects/{pj}/sources", {"source_kind": "interview", "title": "SYNTHETIC interview A", "language_code": "en", "content_text": "We pick suppliers through friends. It is slow and risky.", "acquisition_method": "interview_record", "access_conditions": "privately_shared", "usage_rights": "quote_anonymized_permitted", "personal_data_class": "pseudonymized", "processing_basis_status": "proposed", "author_handle": "@buyer_one"}, token=E)[1]["source"]
    for name, resp in [
        ("org A detail", call("org", "GET", f"organizations/{org_a}", token=O)),
        ("org A members", call("org", "GET", f"organizations/{org_a}/members", token=O)),
        ("org A audit trail", call("org", "GET", f"organizations/{org_a}/review-events", token=O)),
        ("project A detail", call("research", "GET", f"projects/{pj}", token=O)),
        ("source A detail", call("research", "GET", f"sources/{src_a['id']}", token=O)),
        ("create source in project A", call("research", "POST", f"projects/{pj}/sources", {"source_kind": "public_web", "title": "x", "language_code": "en", "acquisition_method": "manual_capture", "access_conditions": "public_no_login"}, token=O)),
        ("patch segment A", call("research", "PATCH", f"segments/{buyers['id']}", {"description": "x"}, token=O)),
        ("review entity in A", call("workflow", "POST", "reviews", {"entity_type": "research_sources", "entity_id": src_a["id"], "decision": "approve"}, token=O)),
        ("list reports of A", call("workflow", "GET", f"projects/{pj}/reports", token=O)),
    ]:
        expect(S, f"outsider blocked: {name}", resp, 404, "NOT_FOUND")
    pb = call("research", "POST", f"organizations/{org_b}/projects", {"product_id": product["id"], "methodology_version_id": m["id"], "title": "x", "objective": "x"}, token=O)
    expect(S, "cross-org product reference rejected", pb, 404, "NOT_FOUND")
    expect(S, "viewer can read", call("research", "GET", f"projects/{pj}", token=V), 200)
    expect(S, "viewer cannot write", call("research", "POST", f"projects/{pj}/segments", {"name": "x", "segment_type": "other"}, token=V), 403, "FORBIDDEN")
    expect(S, "editor cannot approve", call("workflow", "POST", "reviews", {"entity_type": "research_sources", "entity_id": src_a["id"], "decision": "approve"}, token=E), 403, "FORBIDDEN")
    expect(S, "reviewer can approve", call("workflow", "POST", "reviews", {"entity_type": "research_sources", "entity_id": src_a["id"], "decision": "approve"}, token=R), 200)

    # ---------- C. evidence traceability ----------
    S = "traceability"
    dup = call("research", "POST", f"projects/{pj}/sources", {"source_kind": "public_web", "title": "SYNTHETIC page", "language_code": "en", "canonical_url": "https://Example.test/Page/#top", "acquisition_method": "manual_capture", "access_conditions": "public_no_login"}, token=E)[1]
    dup2 = call("research", "POST", f"projects/{pj}/sources", {"source_kind": "public_web", "title": "again", "language_code": "en", "canonical_url": "https://example.test/page/", "acquisition_method": "manual_capture", "access_conditions": "public_no_login"}, token=E)[1]
    check(S, "same URL (normalized) deduplicates deterministically", dup2["duplicate"] is True and dup2["source"]["id"] == dup["source"]["id"], json.dumps(dup2)[:120])
    exc_text = "We pick suppliers through friends"
    exc = call("research", "POST", f"sources/{src_a['id']}/excerpts", {"exact_text": exc_text, "speaker_handle": "@buyer_one", "speaker_role": "buyer"}, token=E)[1]["excerpt"]
    check(S, "excerpt verified against stored source content", exc["verification_status"] == "verified" and exc["verification_method"] == "content_match")
    forged = call("research", "POST", f"sources/{src_a['id']}/excerpts", {"exact_text": "We never need friends to find suppliers"}, token=E)[1]["excerpt"]
    check(S, "forged quote fails verification", forged["verification_status"] == "failed")
    expect(S, "forged quote cannot become a verbatim observation", call("research", "POST", f"projects/{pj}/observations", {"observation_type": "verbatim_quote", "source_excerpt_id": forged["id"]}, token=E), 400, "EXCERPT_NOT_VERIFIED")
    expect(S, "unsupported spreadsheet-style note stays unverified", call("research", "POST", f"projects/{pj}/observations", {"observation_type": "analyst_hypothesis", "original_text": "Suppliers want visibility", "language_code": "en", "research_segment_id": suppliers["id"]}, token=E), 200)
    obs = call("research", "POST", f"projects/{pj}/observations", {"observation_type": "verbatim_quote", "source_excerpt_id": exc["id"], "research_segment_id": buyers["id"], "ivoc_categories": ["pain_fear", "desire"]}, token=E)[1]
    check(S, "verbatim observation copies excerpt text and is verified", obs["original_text"] == exc_text and obs["provenance_status"] == "verified")
    sup_obs = call("research", "POST", f"projects/{pj}/observations", {"observation_type": "paraphrase", "original_text": "Suppliers struggle to be found", "language_code": "en", "research_segment_id": suppliers["id"]}, token=E)[1]
    ins = call("synthesis", "POST", f"projects/{pj}/insights", {"research_segment_id": buyers["id"], "insight_kind": "ivoc_theme", "ivoc_category": "desire", "statement": "Buyers want supplier discovery that does not depend on who they know", "evidence_basis": "evidenced"}, token=E)[1]
    expect(S, "cross-segment support needs a note", call("synthesis", "POST", f"insights/{ins['id']}/support", {"observation_id": sup_obs["id"], "stance": "support"}, token=E), 400, "CROSS_SEGMENT_NOTE_REQUIRED")
    link = call("synthesis", "POST", f"insights/{ins['id']}/support", {"observation_id": obs["id"], "stance": "support"}, token=E)[1]
    contra = call("synthesis", "POST", f"insights/{ins['id']}/support", {"observation_id": sup_obs["id"], "stance": "contradict", "cross_segment_note": "SYNTHETIC: supplier view contrasts"}, token=E)[1]
    expect(S, "evidenced insight without approved evidence cannot be approved", call("workflow", "POST", "reviews", {"entity_type": "research_insights", "entity_id": ins["id"], "decision": "approve"}, token=R), 400, "EVIDENCE_REQUIRED")
    for et, eid in [("research_observations", obs["id"]), ("research_observations", sup_obs["id"]), ("insight_support", link["id"]), ("insight_support", contra["id"]), ("research_insights", ins["id"])]:
        expect(S, f"approve {et}#{eid}", call("workflow", "POST", "reviews", {"entity_type": et, "entity_id": eid, "decision": "approve"}, token=R), 200)
    cap = call("product", "POST", f"projects/{pj}/capabilities", {"capability_type": "feature", "description": "Search suppliers by capability", "availability_status": "beta"}, token=E)[1]
    ben = call("product", "POST", f"projects/{pj}/benefits", {"benefit_text": "Find capable suppliers without personal contacts", "benefit_type": "functional"}, token=E)[1]
    call("workflow", "POST", "reviews", {"entity_type": "product_benefits", "entity_id": ben["id"], "decision": "approve"}, token=R)
    expect(S, "benefit linked to a non-desire is rejected", call("synthesis", "POST", f"projects/{pj}/benefit-desire-links", {"research_segment_id": buyers["id"], "benefit_id": ben["id"], "insight_id": call("synthesis", "POST", f"projects/{pj}/insights", {"research_segment_id": buyers["id"], "insight_kind": "ivoc_theme", "ivoc_category": "objection", "statement": "x", "evidence_basis": "hypothesis"}, token=E)[1]["id"], "rationale": "x"}, token=E), 400, "NOT_A_DESIRE")
    bdl = call("synthesis", "POST", f"projects/{pj}/benefit-desire-links", {"research_segment_id": buyers["id"], "benefit_id": ben["id"], "insight_id": ins["id"], "rationale": "SYNTHETIC fit"}, token=E)[1]
    expect(S, "benefit linked to a desire of another segment is rejected", call("synthesis", "POST", f"projects/{pj}/benefit-desire-links", {"research_segment_id": suppliers["id"], "benefit_id": ben["id"], "insight_id": ins["id"], "rationale": "x"}, token=E), 400, "SEGMENT_MISMATCH")
    call("workflow", "POST", "reviews", {"entity_type": "benefit_desire_links", "entity_id": bdl["id"], "decision": "approve"}, token=R)
    rank = call("synthesis", "PUT", f"projects/{pj}/rankings", {"research_segment_id": buyers["id"], "insight_id": ins["id"], "priority_rank": 1, "urgency_score": 4, "scoring_rubric_version": "synthetic-1", "rationale": "SYNTHETIC"}, token=E)[1]
    check(S, "ranking counts computed server-side", rank.get("evidence_count") == 1 and rank.get("independent_source_count") == 1 and rank.get("independent_speaker_count") == 1, json.dumps(rank)[:160])
    hyp = call("synthesis", "POST", f"projects/{pj}/insights", {"research_segment_id": suppliers["id"], "insight_kind": "ivoc_theme", "ivoc_category": "desire", "statement": "Suppliers may want merit-based visibility", "evidence_basis": "hypothesis"}, token=E)[1]
    expect(S, "hypothesis insight can be approved without evidence", call("workflow", "POST", "reviews", {"entity_type": "research_insights", "entity_id": hyp["id"], "decision": "approve"}, token=R), 200)

    # ---------- D. review transitions ----------
    S = "transitions"
    expect(S, "approving an approved item is invalid", call("workflow", "POST", "reviews", {"entity_type": "research_observations", "entity_id": obs["id"], "decision": "approve"}, token=R), 400, "INVALID_TRANSITION")
    expect(S, "reopen requires a reason", call("workflow", "POST", "reviews", {"entity_type": "research_observations", "entity_id": sup_obs["id"], "decision": "reopen"}, token=R), 400, "REASON_REQUIRED")
    expect(S, "approved observation cannot be edited", call("research", "PATCH", f"observations/{obs['id']}", {"language_code": "es"}, token=E), 400, "IMMUTABLE")
    expect(S, "verbatim text cannot be edited", call("research", "PATCH", f"observations/{sup_obs['id']}", {"original_text": "x"}, token=E), 400, "IMMUTABLE")
    expect(S, "reopen with reason", call("workflow", "POST", "reviews", {"entity_type": "research_observations", "entity_id": sup_obs["id"], "decision": "reopen", "reason": "SYNTHETIC correction"}, token=R), 200)
    expect(S, "re-approve after reopen", call("workflow", "POST", "reviews", {"entity_type": "research_observations", "entity_id": sup_obs["id"], "decision": "approve"}, token=R), 200)

    # ---------- privacy: quote withheld when rights are undetermined ----------
    src_p = call("research", "POST", f"projects/{pj}/sources", {"source_kind": "public_web", "title": "SYNTHETIC forum", "language_code": "en", "content_text": "Finding vendors here takes months.", "acquisition_method": "manual_capture", "access_conditions": "public_no_login"}, token=E)[1]["source"]
    exc_p = call("research", "POST", f"sources/{src_p['id']}/excerpts", {"exact_text": "Finding vendors here takes months."}, token=E)[1]["excerpt"]
    obs_p = call("research", "POST", f"projects/{pj}/observations", {"observation_type": "verbatim_quote", "source_excerpt_id": exc_p["id"], "research_segment_id": buyers["id"]}, token=E)[1]
    sp = call("synthesis", "POST", f"insights/{ins['id']}/support", {"observation_id": obs_p["id"], "stance": "support"}, token=E)
    # insight is approved -> new support is locked; that is itself a rule worth checking
    check("transitions", "approved insight is locked against new evidence", sp[0] == 400 and msg(sp[1]).startswith("INSIGHT_LOCKED"), msg(sp[1]))
    call("workflow", "POST", "reviews", {"entity_type": "research_insights", "entity_id": ins["id"], "decision": "reopen", "reason": "SYNTHETIC add evidence"}, token=R)
    sp = call("synthesis", "POST", f"insights/{ins['id']}/support", {"observation_id": obs_p["id"], "stance": "support"}, token=E)[1]
    for et, eid in [("research_observations", obs_p["id"]), ("insight_support", sp["id"]), ("research_insights", ins["id"])]:
        call("workflow", "POST", "reviews", {"entity_type": et, "entity_id": eid, "decision": "approve"}, token=R)

    # ---------- E. reports: snapshot, versioning, staleness, immutability ----------
    S = "reports"
    r1 = call("workflow", "POST", f"projects/{pj}/reports", {}, token=E)[1]["report"]
    finding = [f for f in r1["report_json"]["ivoc_findings"] if f["insight_id"] == ins["id"]][0]
    ev = [e for e in finding["supporting"] if e["observation_id"] == obs["id"]][0]
    check("traceability", "report evidence keeps observation -> excerpt -> source chain", ev.get("source_excerpt_id") == exc["id"] and ev.get("source_id") == src_a["id"] and ev.get("excerpt_hash") == hashlib.sha256(exc_text.encode()).hexdigest() and ev.get("text") == exc_text, json.dumps(ev)[:200])
    check("traceability", "source manifest lists cited sources", {src_a["id"], src_p["id"]} <= {s["source_id"] for s in r1["report_json"]["source_manifest"]["sources"]})
    check("traceability", "contradicting evidence survives synthesis", any(e["observation_id"] == sup_obs["id"] for e in finding["contradicting"]))
    check("traceability", "hypotheses are reported separately from findings", any(h["insight_id"] == hyp["id"] for h in r1["report_json"]["hypotheses_and_gaps"]) and not any(f["insight_id"] == hyp["id"] for f in r1["report_json"]["ivoc_findings"]))
    evp = [e for e in finding["supporting"] if e["observation_id"] == obs_p["id"]][0]
    check("privacy", "quote with undetermined rights is withheld but traceable", evp.get("text") is None and evp.get("text_withheld_reason") == "quotation_not_permitted" and evp.get("source_excerpt_id") == exc_p["id"], json.dumps(evp)[:200])
    r1b = call("workflow", "POST", f"projects/{pj}/reports", {}, token=E)[1]
    check(S, "regenerating without changes is idempotent", r1b["duplicate"] is True and r1b["report"]["id"] == r1["id"])
    expect(S, "draft cannot be approved directly", call("workflow", "POST", f"reports/{r1['id']}/approve", {}, token=R), 400, "INVALID_TRANSITION")
    expect(S, "editor cannot approve a report", call("workflow", "POST", f"reports/{r1['id']}/approve", {}, token=E), 403, "FORBIDDEN")
    expect(S, "submit", call("workflow", "POST", f"reports/{r1['id']}/submit", {}, token=E), 200)
    a = call("workflow", "POST", f"reports/{r1['id']}/approve", {}, token=R)
    check(S, "reviewer approves report v1", a[0] == 200 and a[1]["report"]["status"] == "approved", msg(a[1]))
    check(S, "second approval is idempotent", call("workflow", "POST", f"reports/{r1['id']}/approve", {}, token=R)[1].get("idempotent") is True)
    v1 = call("workflow", "GET", f"reports/{r1['id']}/verify", token=V)[1]
    check(S, "approved report verifies (hash, sources, excerpts)", v1["json_hash_matches"] and v1["approved_hash_matches"] and v1["is_current"] and not v1["changed_sources"] and not v1["changed_excerpts"], json.dumps(v1))
    expect(S, "source content locked after excerpt verification", call("research", "PATCH", f"sources/{src_a['id']}", {"content_text": "changed"}, token=E), 400, "SOURCE_CONTENT_LOCKED")
    # stale report: generate v2, submit, then change evidence before approval
    call("research", "POST", f"sources/{src_a['id']}/excerpts", {"exact_text": "It is slow and risky"}, token=E)
    r2 = call("workflow", "POST", f"projects/{pj}/reports", {}, token=E)[1]["report"]
    check(S, "new evidence creates version 2", r2["version_no"] == 2)
    call("workflow", "POST", f"reports/{r2['id']}/submit", {}, token=E)
    call("research", "PATCH", f"segments/{buyers['id']}", {"description": "SYNTHETIC edit after submit"}, token=E)
    expect(S, "approval of a stale report is rejected", call("workflow", "POST", f"reports/{r2['id']}/approve", {}, token=R), 400, "STALE_REPORT")
    r3 = call("workflow", "POST", f"projects/{pj}/reports", {}, token=E)[1]["report"]
    call("workflow", "POST", f"reports/{r3['id']}/submit", {}, token=E)
    expect(S, "rejection needs a reason", call("workflow", "POST", f"reports/{r3['id']}/reject", {"reason": " "}, token=R), 400, "REASON_REQUIRED")
    expect(S, "approve version 3", call("workflow", "POST", f"reports/{r3['id']}/approve", {}, token=R), 200)
    lst = call("workflow", "GET", f"projects/{pj}/reports", token=V)[1]
    statuses = {r["version_no"]: r["status"] for r in lst["reports"]}
    check(S, "v1 superseded, v3 current", statuses.get(1) == "superseded" and statuses.get(3) == "approved" and lst["current_report_id"] == r3["id"], json.dumps(statuses))
    old = call("workflow", "GET", f"reports/{r1['id']}", token=V)[1]["report"]
    check(S, "superseded report content unchanged", old["report_json_hash"] == r1["report_json_hash"] and call("workflow", "GET", f"reports/{r1['id']}/verify", token=V)[1]["json_hash_matches"])

    # ---------- F. concurrency ----------
    S = "concurrency"
    call("research", "POST", f"sources/{src_a['id']}/excerpts", {"exact_text": "pick suppliers"}, token=E)
    r4 = call("workflow", "POST", f"projects/{pj}/reports", {}, token=E)[1]["report"]
    call("workflow", "POST", f"reports/{r4['id']}/submit", {}, token=E)
    out = []
    ts = [threading.Thread(target=lambda: out.append(call("workflow", "POST", f"reports/{r4['id']}/approve", {}, token=R))) for _ in range(3)]
    [t.start() for t in ts]; [t.join() for t in ts]
    ev4 = call("org", "GET", f"organizations/{org_a}/review-events", token=V, query={"entity_type": "research_reports", "entity_id": r4["id"]})[1]["items"]
    check(S, "parallel double-click approval records exactly one approval", sum(1 for e in ev4 if e["action"] == "approve") == 1, str([(s, msg(b)[:30]) for s, b in out]))
    call("research", "POST", f"sources/{src_a['id']}/excerpts", {"exact_text": "slow and risky"}, token=E)
    r5 = call("workflow", "POST", f"projects/{pj}/reports", {}, token=E)[1]["report"]
    call("workflow", "POST", f"reports/{r5['id']}/submit", {}, token=E)
    race = {}
    t1 = threading.Thread(target=lambda: race.__setitem__("approve", call("workflow", "POST", f"reports/{r5['id']}/approve", {}, token=R)))
    t2 = threading.Thread(target=lambda: race.__setitem__("edit", call("research", "PATCH", f"segments/{suppliers['id']}", {"description": "SYNTHETIC race " + run}, token=E)))
    t1.start(); t2.start(); t1.join(); t2.join()
    proj = call("research", "GET", f"projects/{pj}", token=V)[1]["project"]
    rep = call("workflow", "GET", f"reports/{r5['id']}", token=V)[1]["report"]
    consistent = (race["approve"][0] == 200 and rep["status"] == "approved") or (race["approve"][0] == 400 and msg(race["approve"][1]).startswith("STALE_REPORT") and rep["status"] == "in_review")
    check(S, "approval racing an evidence edit is consistent (approved-then-edited or rejected stale)", consistent and race["edit"][0] == 200, f"approve={race['approve'][0]} {msg(race['approve'][1])[:40]} report={rep['status']} rev={proj['content_revision']} based_on={rep['based_on_revision']}")

    passed = sum(r["pass"] for r in RESULTS)
    print(f"\n{passed}/{len(RESULTS)} passed")
    json.dump({"run": run, "org_ids": [org_a, org_b], "methodology_id": m["id"], "results": RESULTS}, open(state_path, "w"), indent=1)
    sys.exit(0 if passed == len(RESULTS) else 1)

if __name__ == "__main__":
    main()
