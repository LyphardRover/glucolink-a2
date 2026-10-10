# Excel reporting handoff

**Tool decision: Excel; Metabase not used.**

Prepared by Zhihao Zhang (Package B) for Minha (F). Updated 9 October 2026.

## Files and responsibilities

- [B_Reporting_Export_20261007.xlsx](B_Reporting_Export_20261007.xlsx): an empty template with Control, Checks, Queries and UC1–UC4 sheets. **Make your own copy; do not edit the original.** It is not a completed dashboard.
- [export_reporting.sql](export_reporting.sql): B runs this complete file with **psql** using an existing authorised connection. It contains psql commands and must **not** be pasted into CloudBeaver. It changes no database objects or permissions.
- F can export an accepted view in CloudBeaver using the steps below. F builds and checks the charts in her workbook copy.

Metabase was not fully deployed and validated; completing another service, connection and permission checks would take time away from integration. Excel uses the same reporting SQL results.

## 1. Check that the view is ready

Export each view only after its owner and the group accept that version. You do not need to wait for all four views to start a **single-view browser export**. Record which views are still pending; do not present an incomplete workbook as the final dashboard.

| Workbook sheet | Accepted source view |
|---|---|
| UC1 | `reporting.vw_uc1_care_gaps` |
| UC2 | `reporting.vw_uc2_pdc` |
| UC3 | `reporting.vw_uc3_hba1c_trend` |
| UC4 | `reporting.vw_uc4_care_path_breaks` |

Use the SELECT for that view from the Queries sheet. If a view or column is missing, stop and contact its owner. If agreed columns change, B and F must reconcile the query, template and export script before import. Do not discard unexpected columns.

## 2. Record the database and all nine parameters

In the SQL editor for the project connection, run these read-only queries separately with **Ctrl+Enter**:

```sql
SELECT current_database() AS database_name,
       current_user AS database_role,
       CURRENT_TIMESTAMP AS checked_at;
```

```sql
SELECT current_database() AS database_name, param_name, param_value
FROM reporting.rule_parameter
ORDER BY param_name;
```

The database should be `glucolink_a2` for the shared reporting export. Compare **each name and value**, not just the row count, with the agreed D1 configuration:

| Parameter name | Expected value | Meaning |
|---|---|---|
| as_of_date | 2026-09-01 | Fixed observation date |
| hba1c_high_mmol | 53 | High HbA1c threshold, mmol/mol |
| pdc_threshold | 0.8 | Adherence threshold |
| pdc_window_days | 180 | Adherence observation window, days |
| return_grace_days | 7 | Result delivery grace period, days |
| review_window_days | 90 | Review window after a high result, days |
| test_overdue_months | 6 | Test overdue threshold, months |
| trend_min_change_mmol | 5 | Absolute HbA1c change threshold, mmol/mol |
| trend_window_months | 12 | Trend observation window, months |

B read these nine values from the shared database on 9 October 2026 and they matched. This is a configuration check, not acceptance of the final views. Repeat the query at export time and copy the **actual** values into Control. If they differ, ask for clarification before exporting; do not change the parameters yourself.

## 3. Export one accepted view in CloudBeaver

1. Open the project connection and a SQL editor. Check the database name as above.
2. Paste only the relevant SELECT from the workbook Queries sheet and press **Ctrl+Enter**. Check the result column names and the expected records.
3. At the bottom of the result grid click **EXPORT** (tooltip: **Export result set as a file**). In **Export data**, choose **CSV**.
4. In **Export configuration (CSV) → FORMAT**, keep delimiter `,`, **Header = top**, **Header case = as is**, and **NULL string** empty. Keep normal quoting enabled so commas inside values are handled correctly.
5. Select **OUTPUT** (or **NEXT**) and set **Encoding = UTF-8**. Leave Compression off. Click **EXPORT**.
6. When **File is ready to download** appears, click **DOWNLOAD**. Save with a clear view name and export date, for example `uc2_20261009.csv`.
7. Import into the matching sheet in your workbook copy, following its column order. Keep identifiers as text, dates as dates, and SQL NULL values empty. Do not replace missing values with zero.

These button names and the UTF-8 download flow were checked in CloudBeaver 26.1.3 using the nine-row parameter query. No final view export is claimed by that check.

## 4. Complete Control and Checks before charting

Record the source commit, database, view acceptance version, export time for each file and all nine actual parameters in Control. Complete Checks using the actual results and fixture expectations. Equal row counts alone do not prove equal contents.

Use the statuses supplied by the views; do not implement another set of business rules in Excel. F chooses the chart type and columns for each use case. Pending views remain marked pending.

Separate browser exports can reflect different database states. Agree a stable reporting period while exporting. After any pipeline rerun or parameter change, replace all affected CSVs, refresh the workbook and repeat Checks before publishing the final charts. Excel contains saved results; it does not refresh automatically when PostgreSQL changes.

## 5. Optional full export — B only, using psql

Once **all four** views have been accepted, B can run `export_reporting.sql` from a new private output directory. Unlike the individual browser steps, this script checks all four views and their required columns before exporting. It uses a read-only repeatable-read transaction to produce `uc1.csv`–`uc4.csv` and `export_metadata.csv` from one consistent database snapshot.

Keep credentials out of the repository, workbook and screenshots. If the export fails, discard the partial output set and start a fresh output directory after fixing the cause. Do not share partial files as a complete export.
