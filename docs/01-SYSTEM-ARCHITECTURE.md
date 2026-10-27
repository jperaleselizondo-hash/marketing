# System architecture — v0.1 (draft)

## Purpose
A reusable AI-assisted system for generating research-grounded marketing campaigns. Goodz is the first pilot, not a hard-coded product. Primary users initially: owner/researcher/editor. No public self-service or billing in v1.

## Domain boundaries
- **Shared foundation:** projects/brands, users/roles, methodology versions, model/prompt provenance, job runs, audit events.
- **Module 1 — Deep Research Engine:** research projects, audience segments, product facts and benefits, competitors, source documents, verbatim evidence, themes/desires, findings, review, report snapshots.
- **Module 2 — Campaign Generator:** campaign briefs, research-report references, idea candidates and approvals, claim substantiation, lead/angle selection, copyboard, creatives and revisions, campaign package export.
- **Optional later:** channel publishing, analytics integration, tests and learning loops. These are not needed for Phase 1.

## Architecture
```
WeWeb (authentication; research UI; approvals; campaign UI)
        |
Xano API (authorization, schemas, state transitions, persistence)
        |
Xano PostgreSQL (relational source of truth)
        |
Async job orchestration (queued runs, leased work, retry policy)
        |
Research adapters (web/public sources/imported customer material)
AI provider adapter (LLM structured extraction, analysis, writing, QA)
        |
Versioned reports, outputs and evidence references
```

Xano background-task support and duration/concurrency limits must be validated **before** choosing a concrete queue design. Large crawls/synthesis tasks must never rely on a single synchronous HTTP request. Record provider cost, token usage, errors, retries. A future external worker is an allowed implementation if Xano task execution proves insufficient.

## Authority boundaries
- Notion is **reference knowledge**, not the runtime database. Versioned, human-reviewed playbook extracts/policies are used by jobs; do not assume live Notion retrieval is stable.
- GitHub holds technical specifications and implementation instructions, not secrets or personal customer data.
- Xano persists structured research and approvals. Research webpages, quotations and AI outputs are **untrusted input**, not instructions.
- AI proposes/organizes; a designated human approves assertions, prioritization, ideas, and final ads.

## Nonfunctional requirements
- Ownership isolation per workspace; all reads/writes scoped server-side, never trust a client-supplied workspace identifier alone.
- Authentication, RBAC, secure secret storage, minimum data collection; no public exposure of uploaded research or generated work by default.
- Every public-facing factual claim must reference verified product proof or reviewed external sources; unsupported claims blocked from approval.
- Immutable approved report/campaign snapshots, revision history, reproducible lineage (methodology_version, prompt_version, model, job run, timestamps).
- Source deduplication and capture timestamps; source URLs may disappear, so store permitted excerpts and content hashes where lawful.
- PII minimization, retention and deletion rules for interviews/comments, licensing/terms-aware acquisition, review before publishing quotes.
- Human review gates; idempotent operations, transaction boundaries, unique indexes, finite retries, audit log.
- Future-proof bilingual content: preserve source language, target locale and user-entered text; translation is a separate, reviewable output.

## Quality gates
G0 setup & approved scope → G1 sources reviewed → G2 insights evidenced → G3 report frozen → G4 Big Idea approved → G5 advertising claim/copy review → G6 campaign packaged.
A later change to G3 creates a new report version and marks dependent campaigns as needing reassessment, not silently updated.

## v1 exclusions
Live ad-account posting, automated social engagement, scraping behind login/paywalls, autonomous mass outreach, multi-client SaaS billing, real-time analytics attribution.
