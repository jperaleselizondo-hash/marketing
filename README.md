# Marketing Engine

Research-first, evidence-grounded marketing campaign generation platform.

**Status:** Architecture draft v0.1 — no application code, Xano tables, APIs or WeWeb pages created.

## Two modules
1. **Deep Research Engine:** independently researches a product, its customers, competitors and market; stores source-linked evidence; produces an approved, versioned Research Report.
2. **Campaign Generator:** consumes an immutable approved Research Report version, develops and obtains approval for a Big Marketing Idea, then drafts advertising assets and a campaign package with claim-level provenance.

## Stack
WeWeb frontend; Xano API/workflows/PostgreSQL; model-provider-agnostic AI gateway with structured outputs; external research acquisition adapters; Notion reference playbooks; GitHub as source of truth for technical documents and implementation.

## Documentation
- [Product and system boundaries](docs/01-SYSTEM-ARCHITECTURE.md)
- [Relational data architecture](docs/02-DATA-MODEL.md)
- [Workflows, contracts and guardrails](docs/03-WORKFLOWS.md)
- [Research Report and campaign schemas](docs/04-OUTPUT-CONTRACTS.md)
- [Methodology mapping](docs/05-METHODOLOGY-MAPPING.md)
- [Decisions and open questions](docs/DECISIONS.md)
- [Claude implementation handoff](CLAUDE.md)

**Build order:** review and accept specifications → implement core tenancy/projects and research records → source ingestion and evidence extraction → insight review → frozen Research Report → campaign generation. Never skip evidence validation merely to produce copy quickly.
