# Historical Ad Creation System — integration specification (draft)
Date: 2026-10-27. Status: **documented for review; not authorization to implement**.

> **2026-10-29 founder decisions (ADR-014, ADR-015; see [10-PHASE-1-ARCHITECTURE-BASELINE.md](10-PHASE-1-ARCHITECTURE-BASELINE.md) §4.3):**
> - The Evaldo ten-question evaluation moves from M2 to **M3**, where it evaluates the persuasive narrative at `P1_NARRATIVE` before asset approval.
> - S1 desire-match and S2 Big Idea / one-belief are separate approvals.
> - M3 drafting requires an approved `S2_BIG_IDEA`.
> - Gate numbering below is replaced by R/S/P codes.
>
> The reconstruction of the screenshot flow in §B is unchanged: it records the historical diagram, not the platform's module assignment.

## Source and interpretation
Four owner-supplied screenshots of a flowchart titled **Ad creation system**. The screenshots overlap and show partial edges/labels; this transcription is a best-effort reconstruction, **not a claim to possess the complete original editable diagram**. Preserve screenshots as the reference in the conversation; do not upload screenshots into the public repo without explicit approval. If an editable flowchart is later supplied, reconcile it node by node.

## Reconstructed process from screenshots

### A. Research and audience analysis
The diagram starts with **Research and Audience Analysis** branching into:
- **Market** → IVOC.
- **Competitors** (downstream box content not legible in screenshots).
- **Product** → **Physical: what it is** → facts/features; **Functional: what it does** → new mechanism, benefits/performance.
- **Define Market Desires** → urgency, scope, staying power.
- **Define Prospects' State of Awareness**.
- **Identify the Market Stage of Sophistication**.

### B. Central idea and approval
- Choose **a single overwhelming desire** in the market that gives the campaign power in three dimensions (as written in diagram; other research page elaborates urgency, scope, staying power).
- Select a **product performance** that satisfies that desire.
- Establish the **Core Concept of Ad** (label partially obscured).
- Consider/draft ideas → **Idea: one belief, the message**.
- **Answer 10 questions (Evaldo, p. 101)** — precise questionnaire not provided; keep as an external reference and TODO, do not invent its content.
- **Submit for approval** (mandatory human gate).

### C. Creative structure and copy
- **Plug idea into lead type; choose a format**.
- **Write headline / write hook**.
- **Body copy**.
- Parallel post-draft branches: **List objections → remove negatives**; **Offer → product: list value, benefits, facts**; **Overcome perceived risks**; **Inducement for immediate action → scarcity, deadline, premium** (typically linked to the big promise); **CUBA filter**.
- **Scarcity/urgency/premiums must be genuine, evidenced and applicable.** Do not auto-invent deadlines, discounts, availability or social proof.

## Integration into agreed three-module architecture

| Existing diagram step | Target module | Persisted artifact |
|---|---|---|
| Market/IVOC, competitors, product physical/functional, desires, awareness, sophistication | **M1 Deep Research** | Research Report: source-linked product capability/benefit/desire matrix, market analysis, segment-level awareness/sophistication |
| Select one desire, match product performance (`S1_DESIRE_MATCH`), formulate core concept, one belief/message, approval (`S2_BIG_IDEA`) | **M2 Campaign Strategy** | Campaign Blueprint, Big Idea candidates, **Core Message / One Belief**, desire-performance match, idea approval |
| Lead type/format, hook/headline, body, objections, offer, risk reduction, inducement, **Evaldo ten-question narrative evaluation** (`P1_NARRATIVE`), CUBA (`P2_ASSET_REVIEW`) | **M3 Creative Production** | Master Persuasive Narrative and its evaluation, asset briefs, creative drafts/revisions, claim/risk/offer review, final Campaign Package (`P3_PACKAGE`) |

**Key distinction:** the historical diagram describes a **single-ad persuasive construction process**. The platform's campaign layer must support multiple assets/channels sharing one approved strategic idea. The same persuasion framework may generate a sales letter, landing page, LinkedIn ad, video script or email, with format-specific constraints.

## System contracts to add (proposal)

### Module 1 → Module 2: `approved_research_report`
Contains segment-scoped dominant desire *candidates*, their supporting/contradictory IVOC, urgency/scope/staying-power scores, product performance/benefit links, competitor positioning, awareness and sophistication assessments, limitations and source manifest. **Research does not select the final creative idea**.

### Module 2 → Module 3: `approved_campaign_blueprint`
Includes campaign objective, audience segment, selected dominant desire insight ID, verified product performance/benefit ID, central belief/one-message proposition, Big Idea, mechanism, awareness/sophistication, evidence references, approved channels, CTA/offer strategy, approver and immutable version. **Do not proceed to ad drafting without `S2_BIG_IDEA` approval.** (Evaldo evaluation moved to M3; ADR-015.)

### Module 3: `persuasive_narrative` and `creative_asset`
- Narrative: selected lead family/subtype, persuasion arc, ordered objections, benefit-driven subheads, proof and risk handling, approved offer/CTA, claims registry.
- Creative asset: channel, format, hook/headline, body, visuals brief (if relevant), CTA, variation, version, CUBA findings, claim links and reviewer decision.
- Asset generation is based on approved strategy, **not** an unreviewed AI interpretation of source material.

## Data model implications (for future Module 2/3 schema review)
1. Add `campaign_blueprints` (versioned, approved) linked to immutable `research_reports`.
2. Add `campaign_message_beliefs` or typed fields on blueprint for **one belief / one message**; retain alternatives and rationale.
3. Add `narrative_evaluations` (M3; narrative version, questionnaire_id, question_version, question_id, answer, reviewer) once the original Evaldo questionnaire is available. It was previously `idea_evaluations` in M2 (moved by ADR-015).
4. Add `persuasive_narratives` with structured objections/proof/benefit sequence, linked to blueprint version.
5. Keep `creative_assets` and `creative_revisions` with channel/format/lead/headline/hook/body/CTA; do not store only monolithic copy.
6. Add `offer_terms` and `risk_reduction_claims` with verification/validity windows; urgency/scarcity claims require real proof.
7. Keep `cuba_reviews` (or schema-versioned review JSON) per creative revision: confusing/unbelievable/boring/awkward, severity, corrective action, reviewer.
8. Avoid duplicate concept entities: reconcile existing `idea_candidates`, `campaign_structures`, `claim_registry`, `creative_assets` from docs/02-DATA-MODEL.md with the new blueprint/narrative model **before** physical schema implementation.

## Human gates
Superseded by stable codes (ADR-014): `R3_EVIDENCE`/`R4_INSIGHTS` research evidence reviewed → `R5_REPORT` Research Report approved → `S1_DESIRE_MATCH` central desire/product-performance match → `S2_BIG_IDEA` one-message/Big Idea approved → `P1_NARRATIVE` narrative/offer/claim review incl. Evaldo evaluation → `P2_ASSET_REVIEW` asset-level CUBA + factual review → `P3_PACKAGE` Campaign Package approved.
(Former numbering: G1 evidence → G2 report → G3 desire match + Big Idea → G4 narrative → G5 asset → G6 package.)

## Open questions / no assumptions
- Obtain original **Evaldo p.101 ten questions** (not legible/present here); do not synthesize a fake checklist.
- Confirm whether **Core Concept of Ad** is distinct from Big Marketing Idea or a naming variant.
- Verify the competitor subflow and any cropped nodes in the original editable chart.
- Define when an offer is optional: awareness campaigns may have a nontransactional CTA, not artificial scarcity.
- Define supported launch channels, formats, asset requirements and localization.
- Decide whether a reusable Master Persuasive Narrative is mandatory for short single-asset campaigns or can be a concise structured outline.

## Impact on Module 1 schema
No immediate new research tables required solely because of these screenshots. Ensure existing `research_assessments` capture awareness and sophistication **per segment**, `research_insights`/rankings represent desires with urgency/scope/staying-power, and `capability_benefit_links` + `benefit_desire_links` preserve product performance → benefit → desire. The final creative selection remains a Module 2 decision, not an M1 research fact.

## Implementation status
Documentation only. Continue with read-only Claude review of Module 1 logical schema. Treat Module 2/3 data model notes as pending architecture review, not instructions to create tables.
