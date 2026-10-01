# Identity and Cleansing Rules v1

**Owner:** Yutong Geng (Package D)
**Date:** 1 October 2026
**Status:** v1 — revised to match A2 Build Plan v2, sections 5.3 and 6 (supersedes the first draft, which used a different tier scheme before the Build Plan v2 rules were confirmed)

## 1. Purpose

Describes how patient records from the three source systems (GP, LAB/pathology, PHARM/pharmacy) are standardised into `cleansed.patient_record`, how a single golden patient (`cleansed.patient_master`) is built from them, and how each source record is linked to that golden patient in `cleansed.patient_source_link`. Matching is deterministic. A record is never merged on doubt — anything uncertain is routed to REVIEW, not forced into a match.

## 2. How each field is standardised (04_cleansed_standardise.sql)

All three sources are combined into one table, `cleansed.patient_record`, one row per source record, columns: `source_system` (GP/LAB/PHARM), `source_patient_id`, `given_name`, `family_name`, `dob`, `sex`, `medicare10`, `postcode`.

- **given_name / family_name**: upper-cased and trimmed. GP and PHARM already store these split; LAB stores a single combined `patient_name` field (e.g. `"SMITH, Thomas J"`), so the family name is taken as the text before the comma and the given name as the first word after it. PHARM sometimes stores only an initial (e.g. `"T"` for Thomas) — this is kept as-is, not expanded, which is exactly why matching cannot rely on name alone.
- **dob**: GP already stores a real DATE. LAB stores text in `DD/MM/YYYY`. PHARM stores text in `DD-Mon-YY`, where the two-digit year needs the agreed 100-year rule applied manually (PostgreSQL's own century pivot reads `62` as `2062`, which is wrong): `yy >= 40 → 19yy`, else `→ 20yy` (so `14-May-62` → `1962-05-14`).
- **medicare10**: digits only, stripped of spaces and other characters. LAB's Medicare number carries an IRN suffix after a slash (e.g. `2123456701/1`) — only the part before the slash is the real number; the suffix is dropped, not appended, so the result is still exactly 10 digits. Missing Medicare is stored as SQL `NULL`, never as text or a placeholder.
- **sex / postcode**: carried through where the source has them (GP has both; LAB has sex only; PHARM has neither) — left `NULL` where the source does not record that field, rather than guessed or omitted as a column.

## 3. Why masters come from GP records only

`cleansed.patient_master` (the golden patient index) is built **only from GP records**, because GP registration is what constitutes formal enrolment in GlucoLink — a person who only appears in LAB or PHARM has not necessarily enrolled, so they cannot be treated as the authoritative identity. LAB and PHARM records are only ever linked *to* an existing GP-derived master; they never create one.

## 4. Matching rules (R1 / R2 / REVIEW / UNMATCHED)

Applied to each non-GP record (LAB or PHARM) against the set of GP-derived masters, strongest evidence first:

- **R1**: the record's `medicare10` equals exactly one master's `medicare10` → **LINKED** to that master.
- **R2** (only evaluated if R1 does not apply): the record has the same `dob`, the same `family_name`, and the same first letter of `given_name` as exactly one master, **and** the two Medicare numbers do not conflict (one of them is `NULL`, or they are equal) → **LINKED** to that master.
- If either rule matches **more than one** candidate master → **REVIEW** (ambiguous; a human must resolve it).
- If **no** candidate matches under R1 or R2 → **UNMATCHED**.
- **Never merge on doubt.** A record is only LINKED when exactly one candidate satisfies R1 or R2; anything else stays REVIEW or UNMATCHED rather than being forced.

Each row in `cleansed.patient_source_link` records: `(source_system, source_patient_id)` as its key, the `patient_id` it was linked to (`NULL` unless LINKED), `match_status` (LINKED / REVIEW / UNMATCHED), and `match_rule` (which rule produced the result, or the reason for REVIEW/UNMATCHED).

## 5. What must not be used as matching evidence

- `audit.identity_truth` — the evaluation answer key. It is never read by the matching script itself, only afterwards, to score the result.
- Row order or insertion order.
- Any clinician-side ID (e.g. a referring GP ID attached to a lab or pharmacy record) — these identify a clinician, not the patient, and using them would be a shortcut that does not reflect real-world identity resolution.

## 6. Evaluation (post-matching only)

Once matching is complete, the accepted LINKED rows are scored against `audit.identity_truth` (never read beforehand). The key figures are precision (of the accepted links, how many are correct) and recall (of the true matches, how many were found) — reported separately, since a high-coverage result is not automatically an accurate one.

## 7. Versioning

Rule changes are not silent edits: a change to this document or to the R1/R2 logic gets a new version number, and the team (particularly Minha for testing and Xiaolong for the expected-results sheet) is told, since the expected results in Appendix A/C depend on these exact rules.
