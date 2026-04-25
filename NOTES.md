# Project Notes — Torivumab NSCLC-301

## Future: Shell → Tweak Table → Derivation Spec

**Idea (noted 2026-04-25):** Once ADaMs are available, extend the current shell ecosystem into a full spec-driven pipeline:

- A statistician-editable **tweak table** (Excel/CSV) captures layout decisions — columns, footnotes, subgroups, spanning headers.
- A translation layer converts the tweak table into the machine-readable `sap/shells/shells.yaml`.
- `shells.yaml` then drives both the **shell document** (already implemented) and a **derivation spec** (dataset, variable, population flag, statistic, denominator) that programmers code against directly.

This removes PDF markup roundtrips and keeps the shell and the programming spec in sync from the same source of truth.

**Constraints / decisions:**
- ADaMs will be derived using open-source packages — **admiral** (and related admiral extension packages as appropriate).
- The existing ecosystem for shell → ARD → output is already implemented separately; this project will align to it once ADaMs are ready.
- No work on the derivation spec layer until ADaMs are in place.

**References worth knowing:**
- CDISC Analysis Results Standard (ARS) — formal machine-readable standard for defining analyses and outputs; `sap/shells/shells.yaml` is conceptually aligned with it.
- Shells canonical location: `sap/shells/` (moved from `tfl/` on 2026-04-25; shells are a SAP planning artefact, not production TFL output).
- admiral: https://pharmaverse.github.io/admiral/
