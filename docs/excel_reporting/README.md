# Excel reporting handoff

**Tool decision: Excel; Metabase not used.**

Prepared by Zhihao Zhang (Package B), 8 October 2026, for Minha (F).

## Files to review

- [B_Reporting_Export_20261007.xlsx](B_Reporting_Export_20261007.xlsx): Control, Checks, Queries and four UC result sheets. This is an empty import template, not an accepted dashboard.
- [export_reporting.sql](export_reporting.sql): optional read-only, single-snapshot CSV export for an existing authorised PostgreSQL connection. It changes no database objects, users or permissions.

The workbook filename records its original preparation date. This handoff replaces the earlier provisional tool choice. No sample patient results have been added.

## Before importing data

D/E must publish and validate all four reporting views through 08. F then checks the relevant 09 tests and prepares the final charts. At the reviewed source commit 3f7e03e3b9c225d1c71ad13f6c04db1db64b19d6, 07–10 are not yet in the repository, so a successful final export cannot yet be claimed.

Expected views: reporting.vw_uc1_care_gaps, reporting.vw_uc2_pdc, reporting.vw_uc3_hba1c_trend and reporting.vw_uc4_care_path_breaks. If the owners change their agreed columns, reconcile the workbook and export script first; do not silently discard columns.

## Browser workflow

1. Make a working copy of the workbook. In CloudBeaver, verify the target database with SELECT current_database(), current_user, CURRENT_TIMESTAMP.
2. Run each SELECT from the Queries sheet and export UTF-8 CSV with headers. Use a stable reporting period: separate browser exports may otherwise represent different snapshots.
3. Import each result into the corresponding UC1–UC4 sheet in the stated column order. Keep identifiers as text, dates as dates, and SQL NULL values empty. Do not replace missing values with zero.
4. Record the database, source commit, export times and all nine parameter values in Control. Complete Checks using the actual output and the agreed fixture expectations. Matching row counts alone is insufficient.
5. F builds the required report/dashboard outputs from these sheets. Use the statuses supplied by the views; do not implement a second set of business rules in Excel.
6. Refresh all four result sheets after a pipeline rerun, then repeat the checks. Excel is a saved snapshot; it does not automatically refresh when someone edits PostgreSQL.

## Optional consistent-snapshot export

Run export_reporting.sql with psql from a new private output directory using an existing authorised connection. It checks all four views and their columns before exporting, uses a read-only repeatable-read transaction, and produces uc1.csv through uc4.csv plus export_metadata.csv. Keep credentials out of the workbook and repository. If a run fails, do not use its partial outputs; start a fresh output directory after resolving the cause.

## Acceptance and boundaries

- Completed: template and explicit tool decision; missing-view preflight fails safely before export.
- Still required: successful export against final 08, nine-parameter comparison, business-rule/fixture checks, F's charts and final screenshots.
- UC1 uses the latest VALID result on or before as_of_date, without a six-month lower bound on that lookup.
- UC3 returns NULL change_mmol_mol when n_results < 2; unavailable PDC makes rising_despite_adherence false.
- UC4 uses fact_lab_result.result_returned_flag. These rules remain the SQL owners' responsibility.

B reviewed the workflow and its current limits. No changes to other packages' SQL or shared database data are included.
