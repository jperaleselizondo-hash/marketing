# Historical Ad Creation System — integration specification (draft)
Date: 2026-10-27. Status: **documented for review; not authorization to implement**.

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
| Select one desire, match product performance, formulate core concept, one belief/message, Evaldo question review, approval | **M2 Campaign Strategy** | Campaign Blueprint, Big Idea candidates, **Core Message / One Belief**, desire-performance match, idea evaluation and approval |
| Lead type/format, hook/headline, body, objections, offer, risk reduction, inducement, CUBA | **M3 Creative Production** | Master Persuasive Narrative, asset briefs, creative drafts/revisions, claim/risk/offer review, final Campaign Package |

**Key distinction:** the historical diagram describes a **single-ad persuasive construction process**. The platform's campaign layer must support multiple assets/channels sharing one approved strategic idea. The same persuasion framework may generate a sales letter, landing page, LinkedIn ad, video script or email, with format-specific constraints.

## System contracts to add (proposal)

### Module 1 → Module 2: `approved_research_report`
Contains segment-scoped dominant desire *candidates*, their supporting/contradictory IVOC, urgency/scope/staying-power scores, product performance/benefit links, competitor positioning, awareness and sophistication assessments, limitations and source manifest. **Research does not select the final creative idea**.

### Module 2 → Module 3: `approved_campaign_blueprint`
Includes campaign objective, audience segment, selected dominant desire insight ID, verified product performance/benefit ID, central belief/one-message proposition, Big Idea, mechanism, awareness/sophistication, evidence references, approved channels, CTA/offer strategy, idea-evaluation answers (Evaldo questions only once verified), approver and immutable version. **Do not proceed to ad drafting without approval.**

### Module 3: `persuasive_narrative` and `creative_asset`
- Narrative: selected lead family/subtype, persuasion arc, ordered objections, benefit-driven subheads, proof and risk handling, approved offer/CTA, claims registry.
- Creative asset: channel, format, hook/headline, body, visuals brief (if relevant), CTA, variation, version, CUBA findings, claim links and reviewer decision.
- Asset generation is based on approved strategy, **not** an unreviewed AI interpretation of source material.

## Data model implications (for future Module 2/3 schema review)
1. Add `campaign_blueprints` (versioned, approved) linked to immutable `research_reports`.
2. Add `campaign_message_beliefs` or typed fields on blueprint for **one belief / one message**; retain alternatives and rationale.
3. Add `idea_evaluations` (questionnaire_id, question_version, question_id, answer, reviewer) once original Evaldo questionnaire is available.
4. Add `persuasive_narratives` with structured objections/proof/benefit sequence, linked to blueprint version.
5. Keep `creative_assets` and `creative_revisions` with channel/format/lead/headline/hook/body/CTA; do not store only monolithic copy.
6. Add `offer_terms` and `risk_reduction_claims` with verification/validity windows; urgency/scarcity claims require real proof.
7. Keep `cuba_reviews` (or schema-versioned review JSON) per creative revision: confusing/unbelievable/boring/awkward, severity, corrective action, reviewer.
8. Avoid duplicate concept entities: reconcile existing `idea_candidates`, `campaign_structures`, `claim_registry`, `creative_assets` from docs/02-DATA-MODEL.md with the new blueprint/narrative model **before** physical schema implementation.

## Human gates
G1 research evidence reviewed → G2 Research Report approved → G3 central desire/product-performance match and one-message/Big Idea approved → G4 narrative/offer/claim review → G5 asset-level CUBA + factual review → G6 Campaign Package approved.

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
