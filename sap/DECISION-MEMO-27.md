# Decision memo — statistical items in #27 (D1–D17)

| | |
|---|---|
| **Status** | **Signed 2026-09-20.** Phase 3 is unblocked; no code changed by this memo |
| **Raised by** | Phase 1 of #27, against `c0fb169` (post re-baseline) |
| **Decides** | D13, D1, D3/D5, D4/D7, D11/G7 |
| **Blocks** | Phases 2–3 of #27 (document edits, then regeneration) |

## Why this memo exists

#27 settles that **the documents are corrected first and the programs follow them**. That rule is easy to apply to the mechanical items (a dead path, a stale version header, a missing country list). It is not applicable to five items, because the document and the code disagree about *what analysis to run*, and choosing between them is a statistical judgement rather than a programming task.

Each item below states what the SAP specifies, what the pipeline does, the evidence, and the consequence of each direction. **The recommendation is a starting point for the signatory, not a decision.**

Every figure quoted was recomputed from `datasets/` at `c0fb169`.

---

## D1 — Time-to-event origin: do E1 and E1b remain distinct estimands?

**SAP §13.5** — "Start: `RANDDT` (ADSL)", and `AVAL = DTHDT - RANDDT + 1` (days), converted to months as `AVAL / 30.4375` for reporting.

**`programs/adam/adtte.R:247–250`** — OS, OSWOT, PFS and PFS-INV all call `add_aval(..., "TRTSDT")`. `AVAL = ADT - STARTDT` with no `+ 1`, and `AVALU = "DAYS"` throughout.

So there are three separate divergences: the **origin**, the **`+1` day offset**, and the **reporting units**.

### The authority is the M11 protocol, not the SAP

This was first raised as "`RANDDT` vs `TRTSDT`", then argued from the SAP. Both framings
were wrong about *which document governs*. #27 aligns this trial to the USDM / ICH M11
protocol and the ACDC gap register; the SAP is downstream of those, not the reference.

Read against the right source, the answer is not a statistical convention at all — it is
the protocol's own endpoint definition, carrying a CDISC endpoint code and cited to
protocol §6:

> **M11 §3, Primary Endpoint `C25212`** — "**Time from randomisation** to death from any
> cause. Patients not known to have died at data cut-off will be censored at the date last
> known alive." *(protocol §6)*
>
> **M11 §3, Secondary Endpoint `C25212`** — "**Time from randomisation** to the first
> documented disease progression per RECIST 1.1 (BICR) or death from any cause…"
> *(protocol §6)*
>
> **M11 §3, DCR** — "…maintained ≥8 weeks **from randomisation**"

The ACDC gap register agrees, recording that *"the derived SAP excerpt keeps `RANDDT`"*.
So three independent documents — the M11 protocol, the derived SAP excerpt and this
trial's SAP — all specify randomisation. The pipeline is the outlier.

### The alignment check cannot see this

`check_alignment.py` reports D1 as:

> `WARN | D1 | data | ADTTE AVALU = ['DAYS']; SAP says months`

**Only the units.** The origin is not detectable from `AVAL` alone. #27's acceptance
criterion ("0 warn on D1") is therefore satisfied by the units change by itself — but
passing the machine check is not the same as meeting the requirement, and the origin is
the part that carries the ITT consequence below.

### It is also an estimand question

The SAP additionally fixes the origin as an **ICH E9(R1) *Variable* attribute**, not as a
derivation detail:

> **§13.4 — Primary estimand (E1)**
> **Population:** All randomised subjects (ITT; `ITTFL = "Y"`)
> **Variable:** Time (months) **from randomisation** to death from any cause

> **§13.5 — PFS estimand (E2)**
> **Variable:** Time (months) **from randomisation** to earliest of documented PD per
> RECIST 1.1 by BICR, or death from any cause

Changing the origin therefore changes *which estimand is being estimated*, and leaves the
*Variable* attribute inconsistent with the *Population* attribute directly above it.

**Treatment start is the correct origin in oncology for several purposes, and this
pipeline already uses it correctly for all of them:**

| Context | Correct origin | Status here |
|---|---|---|
| Single-arm trials (no randomisation date exists) | `TRTSDT` | n/a |
| Safety — TEAE window, exposure-adjusted rates | `TRTSDT` | correct |
| **While-on-treatment estimands** | `TRTSDT` | **correct — E1b / `OSWOT`** |
| Randomised ITT efficacy (OS, PFS) | `RANDDT` | **currently `TRTSDT`** |

The repository already defines the treatment-anchored estimand separately. **E1b**
(§13.8, `PARAMCD = "OSWOT"`) is *OS while-on-treatment*, censoring at subsequent therapy
or `TRTEDT + 30` days, and exists precisely to quantify the effect during the randomised
treatment period. Because E1 and E1b currently share the same origin, the distinction the
SAP draws between them is collapsed in the data.

So the decision is not which origin is right for oncology. It is: **do E1 and E1b remain
two different estimands, or one?**

### Why the origin matters beyond definitions

Anchoring a randomised ITT endpoint to treatment start breaks randomisation twice:

1. **Immortal time** — a subject must survive from randomisation to first dose to be
   analysable at all.
2. **It drops a randomised subject.** `SITE012-0277` has `ITTFL = 'Y'`, no `TRTSDT`, and
   therefore `AVAL = NA` with `CNSR = 0` — a death contributing nothing to the primary
   analysis.

The practical effect in this dataset is small: the gap is 0-2 days, median 0, against a
median OS of 497 days. But that is an argument about magnitude, not about which quantity
is being estimated.

### Evidence

The origin shift itself is immaterial: `TRTSDT - RANDDT` is 0–2 days (mean 0.76, median 0) across 449 treated subjects, against a median OS of 497 days (16.3 months).

The consequence that matters is different. **One subject was randomised and never treated** — `CTX-NSCLC-301-SITE012-0277`, `ITTFL = 'Y'`. In ADTTE its OS record has:

```
STARTDT = NA      AVAL = NA      CNSR = 0
```

`CNSR = 0` marks a death, but with `AVAL` missing the subject contributes nothing to a KM or Cox fit and is silently dropped. An ITT analysis that cannot analyse a randomised subject is not ITT. Under `RANDDT` this subject has a valid time and is included.

### Options

| | Effect |
|---|---|
| **Adopt the SAP** — origin `RANDDT`, add `+ 1`, report months | E1 and E1b become genuinely distinct, as §13.4/§13.8 intend; restores ITT integrity; OS/PFS shift by ≤2 days; every efficacy table, figure and KM regenerates |
| **Amend the SAP to `TRTSDT`** | No regeneration, but E1 and E1b collapse into the same estimand, a randomised subject stays unanalysable, and §13.4's *Variable*, §13.5's derivation, §13.8's summary table and the ITT *Population* attribute all need rewriting with a stated rationale for an ITT endpoint measured from treatment |

**Decision (2026-09-20): align to the M11 protocol.** Origin `RANDDT` with the `+ 1`
offset, `AVALU = "MONTHS"` (`AVAL / 30.4375`); E1b retains `TRTSDT` so it remains a
distinct estimand. Rationale of record is the M11 §3 endpoint definition, not the SAP.

The deciding factor is that E1 and E1b are currently the same estimand, not the 2-day
shift. Treat the `+1` and the months conversion as part
of the same change so the three stop drifting apart.

If the organisation's house standard genuinely is treatment-start for randomised oncology
efficacy, that is a legitimate convention — but it should be recorded as a deliberate,
reasoned deviation, with E1b redefined so it still asks a different question from E1.
What should not stand either way is an undocumented gap between the SAP and the code.

---

## D13 — ORR effect estimate: risk difference vs odds ratio, stratified vs not

**SAP §13.6** — "Stratified Mantel–Haenszel risk difference (torivumab − placebo) with 95% CI; strata = histology × region." Estimator named: `stats::mantelhaen.test()`.

**`programs/tfl/t_eff_05_orr.R:44–58`** — `mantelhaen.test()` is called, but **only its p-value is used**. The reported effect is computed separately:

```r
rd    <- 100 * (p_trt - p_pbo)                     # unstratified
se_rd <- sqrt(p_trt*(1-p_trt)/n + p_pbo*(1-p_pbo)/n) * 100
rd_lo <- rd - 1.96 * se_rd                         # Wald
```

### Evidence

The issue flags one discrepancy — that `mantelhaen.test()` returns an odds ratio, not a risk difference. There are **three**:

1. The SAP names a function that cannot produce the estimand it specifies.
2. The reported risk difference is **not stratified at all**. The SAP specifies Mantel–Haenszel weighting across histology × region; the code computes a crude difference of proportions. Stratification is applied only to the p-value.
3. The code comment says "Newcombe CI", but the interval computed is **Wald** (`rd ± 1.96·SE`). Comment and code disagree.

Point 2 is the substantive one: the headline ORR effect estimate does not match its own estimand definition.

### Options

| | Effect |
|---|---|
| **Implement a stratified MH risk difference** (e.g. Greenland–Robins variance), keep CMH for the test | Matches the SAP; ORR effect estimate and CI change; SAP estimator sentence needs rewording away from `mantelhaen.test()` |
| **Amend the SAP to an unstratified RD** | Matches current output, but discards the stratification the design was built on and weakens the estimand |
| **Switch the estimand to a common odds ratio** | Makes `mantelhaen.test()` correct as named, but changes the clinical interpretation of the primary response endpoint |

**Recommendation: implement the stratified MH risk difference and reword the SAP's estimator sentence.** Also fix the Newcombe/Wald comment either way — whichever interval is intended, the code and comment must agree.

---

## D3 / D5 — Response reader and confirmation rule

**SAP §4.3** — BICR reader; confirmation requires "a second CR/PR ≥ 28 days later, with no intervening PD".

**`programs/adam/adrs.R:41`** — `filter(RSEVAL == "INVESTIGATOR")`, with an equal-or-better confirmation rule and no intervening-PD clause. Lines 36–39 record this as **accepted limitation AL-04**, and state explicitly: *"a future SAP amendment can flip these to BICR."*

### Evidence

BICR data is present and complete — `SDTM.RS` holds **2,669 records for each reader**. Switching is feasible today.

Impact of the reader alone is small: subjects with ≥1 CR/PR are **172 (BICR)** vs **173 (Investigator)**. The confirmation-rule change is the larger unknown and has not been quantified, because it requires implementing the rule to measure.

This item is therefore **not a defect** — it is a recorded decision awaiting the amendment its own comment anticipates.

### Options

| | Effect |
|---|---|
| **Adopt the SAP** — BICR + the ≥28-day/no-intervening-PD rule | Closes AL-04; ORR, DoR and response-based outputs regenerate; magnitude of the confirmation-rule change unknown until implemented |
| **Keep Investigator and amend the SAP** | No regeneration; AL-04 becomes permanent and the SAP's BICR language must go |

**Recommendation: adopt the SAP**, but implement the confirmation rule and measure it *before* committing, so the change in ORR is a known quantity rather than a surprise in the regeneration diff.

---

## D4 / D7 — Response Evaluable population and `EFFFL`

**SAP §3, §13.6** — E3's population is Response Evaluable, identified by `EFFFL`.

**Reality** — `EFFFL` does not exist in ADRS. `programs/tfl/t_eff_05_orr.R:15–16` derives the population inline instead: subjects with at least one `PARAMCD == "OVR"` record.

So what is implemented is effectively the ITT sensitivity estimand **E3a**, not E3.

### Options

| | Effect |
|---|---|
| **Derive `EFFFL` in ADSL/ADRS** and point E3 at it | Makes the SAP satisfiable as written; the inline derivation becomes the flag's definition and must be specified |
| **Amend the SAP** to define E3 on the ITT denominator | Matches what is built, but then E3 and E3a are the same estimand and one should be retired |

**Recommendation: derive `EFFFL`.** A population flag that exists only as an inline filter inside one TFL program is not traceable, and cannot be referenced by define.xml or reused by another output.

---

## D11 / G7 — No SAP section for laboratory or vital-signs analysis

**SAP §4–5** — no laboratory or vital-signs analysis is specified. **Synopsis §8.4** likewise.

**Reality** — T-LB-01, T-LB-02, L-LB-01, T-VS-01 and T-VS-02 are all built and shipped.

Five outputs exist with no analysis definition behind them. Unlike the other four items this is not a disagreement — it is an absence.

#27 proposes the text: descriptive, safety population; values and change from baseline by visit; shift baseline → worst reference-range category; worst CTCAE v5.0 grade with a Grade ≥3 listing.

### Options

| | Effect |
|---|---|
| **Author the SAP section** as proposed | Existing outputs gain a definition; wording must match what the programs do, or it creates fresh discrepancies |
| **Author it from the shells instead** | Guarantees document/output agreement, but writes the SAP to match the code — the reverse of #27's rule |

**Recommendation: author the section, then verify each of the five outputs against it** and treat any gap as a new finding. Writing the text is quick; the verification is the real work and should not be skipped.

---

## Related decision, not part of D1–D17

**Rounding convention at exact ties.** `programs/tfl/_helpers.R:68` `fmt_mean_sd()` formats via `sprintf`, which resolves ties away from zero; R's `round()` uses half-even. T-VS-01 contains a real instance — temperature change at C1D1, placebo, mean **exactly 0.05 on n=58** — which prints as `0.1` under `sprintf` and `0.0` under `round()`.

**Decision (2026-09-20): write an explicit documented rounding rule.** The behaviour is
to be defined in a dedicated helper rather than inherited from the C library's `printf`,
and stated in the SAP, so the convention is auditable rather than incidental. This changes
every table using these formatters and must land *before* the Phase 3 regeneration.

The Phase 0 re-baseline (`c0fb169`) reset that cell to `0.1`; **it did not fix the tie**. This should be settled before Phase 3, or a flipped boundary cell will appear in #27's regeneration diff and be misattributed to an intended change. It affects every table using these formatters, not only T-VS-01.

---

## What this memo does not decide

- The mechanical document items (D2, D6, D10, D12, D14, G2, G5, G6) — no judgement needed; they proceed in Phase 2.
- The data items (D15 2:1 randomisation, D16 imaging schedule, D17 C1D15) — mechanical once the documents are amended.
- Whether the study's headline results may move. That is already settled: **they may.**

## Sign-off

| Item | Decision | Signatory | Date |
|---|---|---|---|
| D1 | **Align to the M11 protocol** — E1/E2 origin `RANDDT` with `+ 1`; E1b retains `TRTSDT`. *Units half superseded by #40 (2026-09-20): ADTTE stores days (`AVALU = "DAYS"`, per `ADTTE-spec.md` and SAP §13.5), months are a reporting-layer conversion; the #27 acceptance criterion was amended to accept days.* Rationale of record: M11 §3 endpoint definition (`C25212`, "time from randomisation", cited to protocol §6), not the SAP | Lovemore Gakava | 2026-09-20 |
| D13 | **Stratified Mantel–Haenszel risk difference** (Greenland–Robins variance), CMH retained for the p-value; SAP estimator sentence reworded away from `mantelhaen.test()`; Newcombe/Wald comment corrected | Lovemore Gakava | 2026-09-20 |
| D3, D5 | **Adopt BICR reader and the ≥28-day / no-intervening-PD confirmation rule**, closing AL-04. Confirmation rule to be implemented and its effect on ORR measured *before* commit | Lovemore Gakava | 2026-09-20 |
| D4, D7 | **Derive `EFFFL`** in ADSL/ADRS and point E3 at it. **Definition corrected 2026-09-20 after signing**: the row originally read "the current inline rule becomes the flag's specification", written before M11 §3.2.2 had been read. That section defines the population as "ITT with ≥1 post-baseline tumour assessment, **or clinical progression before first assessment**", citing protocol §8.2, so both arms are implemented. N=444 rather than 431; ORR risk difference moves from 20.9 to 21.2. The M11 protocol governs over the memo's wording, on the same basis as D1 | Lovemore Gakava | 2026-09-20 |
| D11, G7 | **Authored** — SAP §5.6 and §5.7, synopsis §8.4 (PR #34) | Lovemore Gakava | 2026-09-20 |
| Rounding at ties | **Explicit documented rule** — dedicated helper, behaviour defined in code and stated in the SAP, not inherited from C `printf`. Must land before the Phase 3 regeneration | Lovemore Gakava | 2026-09-20 |

### Consequences for Phase 3

All six are now settled, so Phase 3 is a single regeneration covering D1, D3/D5, D4/D7,
D8/D9, D13, D15–D17 and the rounding rule together. Two ordering constraints:

- The **rounding helper must land first**, otherwise a flipped boundary cell appears in
  the regeneration diff and is misattributed to a D-item.
- The **D3/D5 confirmation rule should be measured before commit**, so the change in ORR
  is a known quantity rather than something discovered in a 135-file diff.
