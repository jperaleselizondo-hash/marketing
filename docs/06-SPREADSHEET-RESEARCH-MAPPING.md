# Historical research workbook mapping — 2026-10-27

Source: owner-uploaded `{SGL}-Research.xlsx`, reviewed locally. Workbook contains three sheets: **Product**, **Competitor**, **Market**. The workbook is private example material; **do not commit its contents** to this public repository.

## Product sheet
- Contains a market-awareness assessment (example: `Product Aware`).
- Service/product rows map to **Facts And Features**, **Benefits**, and **Deseos Humanos que satisface**.
- Preserve explicit product performance → benefit → human desire links, allowing multiple links and segment-specific interpretation.
- Current logical schema `product_facts` and `benefit_insight_links` captures some of this; proposed normalization: `product_capabilities`, `capability_benefits`, `benefit_desire_links` (or rigorously typed `product_facts` plus join tables). Validate before physical implementation.

## Competitor sheet
- Competitor-by-competitor blocks, with fields: Idea, USP, Pain Focus, Desire Focus, Social Media, Ads, Praise, Complaints; plus investigator annotations.
- Store dimensions as typed `competitor_observations`, each with source, observation, analyst interpretation, captured_at and review status. An investigator's subjective comment is **not** a competitor quotation or verified fact.
- Competitor alternatives should support direct/indirect/substitute classification.

## Market sheet
- Seven parallel IVOC columns: Pains and Fears, Desires, Objections, Firms Beliefs, Shakeable Beliefs, Common Words or Phrases, Other.
- Contains `Sumary Rankings` and mapping of IVOC Summary → Associated Benefit → Problem Solver.
- **Important:** values aligned on the same spreadsheet row do not necessarily originate from the same respondent or source. Import them as independent observations unless explicit relationship exists.
- Store each entry with category, original text, source/locator if known, language, observation_type (`verbatim_quote`, `paraphrase`, `analyst_hypothesis`, `synthesis`), review state. Historical rows lacking provenance must be flagged `source_unverified`; do not promote to verified IVOC.
- Add `insight_rankings` with research_project_id, audience_segment_id, insight_id, rank, scoring rubric/version, supporting count and rationale; and benefit/problem mappings. Separate research-summary selection from raw data.

## Proposed changes to the logical schema (pending approval)
1. Add `research_observations` for typed original observations and provenance status; preserve `source_excerpts` exclusively for faithful source excerpts.
2. Add normalized product performance → benefit → desire associations; one-to-many/many-to-many supported.
3. Add `insight_rankings` or `research_priorities` with explicit scoring and decision metadata.
4. Add `competitor_observation_notes` or distinct analyst_note field; never conflate marketing claims with independent proof.
5. Add import lineage fields (`import_batch_id`, `sheet_name`, `cell_ref`) for future spreadsheet migration, without assuming old spreadsheet entries are sourced customer quotes.
6. Extend report output with product-feature-benefit-desire matrix and ranked insight → benefit → problem-solver table.

## Confirmed architecture
Three stages: **Deep Research Engine → Campaign Strategy → Creative Production**. Two latter stages belong to the overall Campaign Generator domain but have independent approval artifacts: Campaign Blueprint, Master Persuasive Narrative, Advertising Asset Package.

## Acceptance criteria
- Every imported spreadsheet observation retains exact original text, source sheet/cell, and provenance classification.
- Unverified notes cannot masquerade as actual customer quotes.
- Product performance → benefit → desire can be queried and audited.
- Ranked desires trace to research observations and linked product benefits.
- Competitor comments retain clear analyst-vs-source separation.
- Goodz pilot segments buyer and supplier independently.
