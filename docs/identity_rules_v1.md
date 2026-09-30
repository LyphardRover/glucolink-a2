## 1. Purpose

Defines how records from the three source systems (GP, PATH/pathology, PHARM/pharmacy) are linked to a single `trusted_patient_id`. Rules are deterministic and applied from strongest to weakest evidence. Any conflict or ambiguity produces `unresolved` — never a forced merge.

## 2. Inputs (post-standardisation, output of 04_cleansed_standardise.sql)

Confirmed against C's `01_src_tables.sql` (30 Sept 2026). Source columns differ per system, so standardisation work differs too:

- **GP** (`src_gp.gp_patient`: `first_name`, `last_name`, `dob`, `sex`, `postcode`, `medicare_number`) → produces `norm_first`, `norm_last`, `norm_dob`, `norm_sex`, `norm_postcode`, `norm_medicare`. No `ihi` field exists in the source table — removed from this version; can be added back if the team decides to add it upstream.
- **PATH** (`src_lab.lab_patient`: `patient_name` [combined, e.g. "SURNAME, First M"], `dob` [text, DD/MM/YYYY], `sex`, `medicare_number`) → `patient_name` must be **split into `norm_first`/`norm_last` first**, before any other standardisation. No postcode field exists in the source table, so `norm_postcode` is **not available for PATH** — any rule referencing PATH postcode is dropped (see Tier 5 below).
- **PHARM** (`src_pharm.pharmacy_patient`: `given_name`, `surname`, `date_of_birth` [text, DD-Mon-YY], `medicare_number`) → produces `norm_first`, `norm_last`, `norm_dob`, `norm_medicare`. No sex or postcode fields exist in the source table.

## 3. Validity checks (a field only counts as evidence if it passes these)

- `norm_medicare`: exactly 10 digits after stripping non-digits. Reject obvious placeholders (e.g. `0000000000`, repeated digits). A Medicare number linked to 3+ clearly different (name, DOB) combinations is flagged as suspect and excluded from auto-matching in that run.
- `norm_dob`: must parse to a valid calendar date under that source's known format. Implied ages outside 0–110 are rejected as invalid, not used to match.
- `norm_first` / `norm_last`: an empty string is treated as missing, never as a match.

## 4. Match tiers (strongest → weakest)

| Tier | Rule | Action | `match_rule_id` |
|---|---|---|---|
| 1 | `norm_medicare` exact match **and** `norm_dob` exact match | Auto-match | `TIER1_MEDICARE_DOB_V1` |
| 2 | *(reserved — no `ihi` field exists in the current source tables; add back if the team introduces one)* | — | — |
| 3 | `norm_first` + `norm_last` + `norm_dob` all exact match, **and the combination is unique** on each side | Auto-match | `TIER3_NAME_DOB_V1` |
| 4 | Same as Tier 3, but the (name, DOB) key maps to **more than one** candidate on either side | **Unresolved** — ambiguous, do not merge | `TIER4_AMBIGUOUS` |
| 5 | Partial/fuzzy name or DOB match, with postcode agreement as a supporting signal (**GP↔PHARM only** — PATH has no postcode field) | Tie-breaker only this round, never sole basis for auto-accept | `TIER5_SUPPORTING_ONLY` |

## 5. Conflict handling

If a pair satisfies a tier's key fields but another available field actively disagrees (e.g. same name + DOB but opposite `norm_sex` on GP↔PATH, or postcodes differing with no plausible relocation on GP↔PHARM), do **not** auto-match. Route to `unresolved` with a `conflict_reason` (e.g. `sex_mismatch`, `postcode_conflict`). Note: `norm_sex` is only available on GP and PATH (not PHARM), and `norm_postcode` is only available on GP and PHARM (not PATH), so which conflict checks apply depends on which pair of systems is being compared.

## 6. What must NOT be used as matching evidence

- `identity_truth.csv` — evaluation-only. Read **after** matching is finalised, never as a matching input.
- Row order / insertion order.
- `referring_provider_id` (GP↔lab) and `prescriber_id` (GP↔pharmacy) — these hold a **clinician's** GP ID, not the patient's. Using them would be a hidden shortcut that doesn't reflect real-world identity resolution.
- Any pre-assigned cross-system ID from upstream generation or testing.

## 7. Output states

- **`matched`** — accepted link; tier and rule ID recorded.
- **`unresolved`** — ambiguous or conflicting; attempted tier and conflict reason recorded; no `trusted_patient_id` cross-link asserted.
- **`single_system`** — no candidate found in any other source at all. This is not a matching failure — the person simply has no record there.

## 8. Evaluation (post-matching only)

Once matching is complete, accepted links are scored against separately-held ground truth:
- **Recall** — % of true matches found
- **Precision** — % of accepted matches that are correct
- **False-merge rate** — % of accepted matches that are wrong

**Coverage** (% of records that received any decision) is reported separately from **accuracy** — the two are not interchangeable.

## 9. Versioning

Every row in `PATIENT_SOURCE_LINK` carries `match_rule_id` (per the tier table above) and `run_id` for traceability. Rule changes require a new version number, never a silent edit.
