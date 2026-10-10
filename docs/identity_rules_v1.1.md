# Identity and Cleansing Rules v1.1

**Owner:** Yutong Geng (Package D)
**Date:** 7 October 2026
**Status:** v1.1 — supersedes v1 (1 October 2026). Updated per Remediation Plan v3, task card D-1, step 6: adds the GP-self-link rule, the GP-medicare-merge rule, and the lab-result data-quality rules; removes the "referring GP ID" example in section 5 (no such column exists in the source tables).

## 1. Purpose

Describes how patient records from the three source systems (GP, LAB/pathology, PHARM/pharmacy) are standardised into `cleansed.patient_record`, how a single golden patient (`cleansed.patient_master`) is built from them, and how each source record is linked to that golden patient in `cleansed.patient_source_link`. Matching is deterministic. A record is never merged on doubt — anything uncertain is routed to REVIEW, not forced into a match.

## 2. How each field is standardised (04_cleansed_standardise.sql)

All three sources are combined into one table, `cleansed.patient_record`, one row per source record, columns: `source_system` (GP/LAB/PHARM), `source_patient_id`, `given_name`, `family_name`, `dob`, `sex`, `medicare10`, `postcode`.

- **given_name / family_name**: upper-cased, trimmed, and reduced to the **first word only** for every source (GP and PHARM store these split already but can still contain a middle name; LAB stores a single combined `patient_name` field, e.g. `"SMITH, Thomas J"`, so the family name is the text before the comma and the given name the first word after it). PHARM sometimes stores only an initial (e.g. `"T"` for Thomas) — kept as-is, not expanded, which is exactly why matching cannot rely on name alone. A blank given_name, family_name or postcode is stored as SQL `NULL`, never as an empty string.
- **dob**: GP already stores a real DATE. LAB stores text in `DD/MM/YYYY` (four-digit year, no century ambiguity); a blank date text becomes `NULL` before any parsing is attempted. PHARM stores text in `DD-Mon-YY`, where the two-digit year needs the agreed rule applied: parse assuming the current century first (`20yy`), then if the resulting date is **after the as_of_date** (read from `reporting.rule_parameter`, currently 2026-09-01), subtract 100 years (so `14-May-62` parses to `2062-05-14` first, then becomes `1962-05-14`). A blank date_of_birth text also becomes `NULL` before parsing.
- **medicare10**: digits only, stripped of spaces and other characters. LAB's and PHARM's Medicare number can carry an IRN suffix after a slash (e.g. `2123456701/1`) — only the part before the slash is the real number. The result is kept **only if it is exactly 10 digits**; anything shorter, longer, or missing is stored as SQL `NULL`, never as text or a placeholder.
- **sex / postcode**: carried through where the source has them (GP has both; LAB has sex only; PHARM has neither) — left `NULL` where the source does not record that field, rather than guessed or omitted as a column.

## 3. Why masters come from GP records only

`cleansed.patient_master` (the golden patient index) is built **only from GP records**, because GP registration is what constitutes formal enrolment in GlucoLink — a person who only appears in LAB or PHARM has not necessarily enrolled, so they cannot be treated as the authoritative identity. LAB and PHARM records are only ever linked *to* an existing GP-derived master; they never create one.

- **Every GP record is LINKED to its own master directly**, `match_rule = 'GP'` — it is never put through R1/R2 (those rules exist only to decide which GP-built master a LAB or PHARM record should attach to).
- **GP records that share the same valid `medicare10` combine into a single master.** This is why 18 GP records produce only 17 masters (e.g. `GP-0008` and `GP-0009` share one master): the two GP records are both LINKED to that one master, each still with `match_rule = 'GP'`. A GP record with no valid Medicare number simply forms its own, single-member master.

## 4. Matching rules (R1 / R2 / REVIEW / UNMATCHED)

Applied to each non-GP record (LAB or PHARM) against the set of GP-derived masters, strongest evidence first:

- **R1**: the record's `medicare10` equals exactly one master's `medicare10` → **LINKED** to that master.
- **R2** (only evaluated if R1 finds zero candidates): the record has the same `dob`, the same `family_name`, and the same first letter of `given_name` as a master, **and** the two Medicare numbers do not conflict (one of them is `NULL`, or they are equal) → if this matches exactly one master, **LINKED** to it.
- If either rule matches **more than one** candidate master → **REVIEW** (ambiguous; a human must resolve it).
- If **no** candidate matches under R1 or R2 → **UNMATCHED**.
- **Never merge on doubt.** A record is only LINKED when exactly one candidate satisfies R1 or R2; anything else stays REVIEW or UNMATCHED rather than being forced.

Each row in `cleansed.patient_source_link` records: `(source_system, source_patient_id)` as its key, the `patient_id` it was linked to (`NULL` unless LINKED), `match_status` (LINKED / REVIEW / UNMATCHED), `match_rule` (GP / R1 / R2 / `NULL`), and `candidate_count` (how many masters satisfied the rule that was tried).

## 5. What must not be used as matching evidence

- `audit.identity_truth` — the evaluation answer key. It is never read by the matching script itself, only afterwards, to score the result.
- Row order or insertion order.

## 6. Lab result data-quality rules (for `cleansed.lab_result`, task card D-3)

These rules govern the lab results layer that sits alongside identity resolution and are recorded here so the whole data-quality picture for Package D is in one document (implementation lands in `04` part 2 / D-3, due 8 Oct):

- **`dq_status`** is decided in this order, first match wins:
  1. **DUPLICATE** — a repeated FHIR Observation `id` already seen.
  2. **REJECTED_UNIT** — the result's unit does not match the expected unit for its LOINC code; `hba1c_mmol_mol` is set to `NULL` for that row.
  3. **FUTURE_DATE** — the result's collection date is after the `as_of_date` (read from `reporting.rule_parameter`, not hard-coded).
  4. **VALID** — none of the above apply.
- **HbA1c unit conversion**: `mmol/mol = (% − 2.15) × 10.929`, rounded to 1 decimal place (e.g. 7.0% ≈ 53 mmol/mol).
- **Dates must use the Sydney calendar date**, not raw UTC, to avoid off-by-one-day errors: `((fhir_json ->> 'effectiveDateTime')::timestamptz AT TIME ZONE 'Australia/Sydney')::date`.
- Only rows with `dq_status = 'VALID'` count towards any downstream use-case view (UC1–UC4) per `business_rules_v1.docx`.

## 7. Evaluation (post-matching only)

Once matching is complete, the accepted LINKED rows are scored against `audit.identity_truth` (never read beforehand). The key figures are precision (of the accepted links, how many are correct) and recall (of the true matches, how many were found) — reported separately, since a high-coverage result is not automatically an accurate one.

## 8. Versioning

Rule changes are not silent edits: a change to this document or to the R1/R2 logic gets a new version number, and the team (particularly Minha for testing and Xiaolong for the expected-results sheet) is told, since the expected results in Appendix A/C depend on these exact rules.

| Version | Date | Change |
|---|---|---|
| v1 | 1 Oct 2026 | First version matching Build Plan v2 §5/§6 (R1/R2/REVIEW/UNMATCHED). |
| v1.1 | 7 Oct 2026 | Added GP-self-link rule and GP-medicare-merge rule (§3); added lab-result dq_status rules (§6); removed the "referring GP ID" example (no such column exists in the source tables). |
