# Output contracts — v0.1 (draft)

## Research Report (Module 1)
Canonical `research_report.schema_version = "1.0"`. Human-readable Markdown exported from immutable JSON + citations and review decisions.

```json
{
  "schema_version": "1.0",
  "research_project_id": "<id>",
  "version": 1,
  "objective": "market_awareness",
  "product_snapshot": {"facts": [], "benefits": [], "limitations": [], "proof_refs": []},
  "audience_segments": [{"id":"<id>","awareness":"problem_aware","sophistication_assessment":null,"rationale":"","confidence":"low"}],
  "competitive_landscape": [{"competitor_id":"<id>","observations":[],"source_refs":[]}],
  "ivoc_findings": [{"insight_id":"<id>","category":"desire","summary":"","verbatim_excerpt_ids":[],"contradicting_excerpt_ids":[],"counts":{"observations":0,"independent_sources":0},"scoring":{"intensity":null,"urgency":null,"staying_power":null,"scope":null},"confidence":"unverified"}],
  "desire_prioritization": [{"insight_id":"<id>","linked_benefit_ids":[],"rationale":""}],
  "research_gaps": [],
  "recommendations_for_campaign": [],
  "source_manifest": {"source_ids":[],"manifest_hash":""},
  "methodology_version_id": "<id>",
  "approved_by": null,
  "approved_at": null
}
```

No fabricated sentiment counts, unsupported percent-of-market, or inferred demographics presented as fact. A selected desire can be ranked provisionally, but reviewer must see alternatives and contradictions.

## Marketing Campaign Package (Module 2)
```json
{
  "schema_version":"1.0",
  "campaign_id":"<id>",
  "research_report_id":"<approved_version_id>",
  "audience_segment_id":"<id>",
  "objective":"market_awareness",
  "locale":"es-MX",
  "selected_dominant_desire_insight_id":"<id>",
  "big_marketing_idea":{"statement":"","rationale":"","innovation_or_mechanism":"","approval_id":"<id>"},
  "positioning":{"primary_message":"","differentiation":"","awareness_level":"","sophistication_stage":""},
  "creative_strategy":{"lead_family":"story","directness":"indirect","angle":"","copyboard":[]},
  "assets":[{"id":"<id>","channel":"linkedin","format":"post","headline":"","body":"","cta":"","revision":1,"claim_ids":[]}],
  "claim_review":{"unsubstantiated_claim_count":0},
  "approvals":[],
  "generated_at":"<ISO-8601>"
}
```

Campaign output is **not** equivalent to immediate publishing or paid ad deployment. A campaign can have an educational CTA and no purchase offer. Channel versions retain factual consistency and the one approved central idea.

## User-facing reporting format
Executive summary → Scope & methodology → Product truth table → Audience-by-segment → Competitor landscape → IVOC findings with quoted evidence → Ranked desires and benefit fit → Evidence limitations / unanswered questions → Campaign opportunities → Appendix (source URLs, capture timestamps, quote IDs).
