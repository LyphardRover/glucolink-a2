\set ON_ERROR_STOP on
-- Package B: read-only reporting export for F. Requires completed 08 and accepted 09.
-- Run with psql from a new private output directory. No passwords belong in this file.
SELECT current_database(), current_user, CURRENT_TIMESTAMP AS export_started_at;
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='60s';
SET LOCAL lock_timeout='5s';
DO $check$
DECLARE actual_cols text[];
BEGIN
IF to_regclass('reporting.vw_uc1_care_gaps') IS NULL THEN RAISE EXCEPTION 'Reporting view is missing: reporting.vw_uc1_care_gaps. Finish and validate 08 first.'; END IF;
SELECT array_agg(column_name::text ORDER BY ordinal_position) INTO actual_cols FROM information_schema.columns WHERE table_schema='reporting' AND table_name='vw_uc1_care_gaps';
IF actual_cols IS DISTINCT FROM ARRAY['patient_id','display_name','home_clinic','last_test_date','last_hba1c_mmol_mol','first_review_date','care_gap_status','as_of_date']::text[] THEN RAISE EXCEPTION 'Column contract differs for vw_uc1_care_gaps'; END IF;
IF to_regclass('reporting.vw_uc2_pdc') IS NULL THEN RAISE EXCEPTION 'Reporting view is missing: reporting.vw_uc2_pdc. Finish and validate 08 first.'; END IF;
SELECT array_agg(column_name::text ORDER BY ordinal_position) INTO actual_cols FROM information_schema.columns WHERE table_schema='reporting' AND table_name='vw_uc2_pdc';
IF actual_cols IS DISTINCT FROM ARRAY['patient_id','display_name','drug_class','fills_counted','covered_days','window_days','pdc','adherence_status','window_start','window_end','as_of_date']::text[] THEN RAISE EXCEPTION 'Column contract differs for vw_uc2_pdc'; END IF;
IF to_regclass('reporting.vw_uc3_hba1c_trend') IS NULL THEN RAISE EXCEPTION 'Reporting view is missing: reporting.vw_uc3_hba1c_trend. Finish and validate 08 first.'; END IF;
SELECT array_agg(column_name::text ORDER BY ordinal_position) INTO actual_cols FROM information_schema.columns WHERE table_schema='reporting' AND table_name='vw_uc3_hba1c_trend';
IF actual_cols IS DISTINCT FROM ARRAY['patient_id','display_name','n_results','first_test_date','first_hba1c','last_test_date','last_hba1c','change_mmol_mol','trend_status','best_pdc','rising_despite_adherence','as_of_date']::text[] THEN RAISE EXCEPTION 'Column contract differs for vw_uc3_hba1c_trend'; END IF;
IF to_regclass('reporting.vw_uc4_care_path_breaks') IS NULL THEN RAISE EXCEPTION 'Reporting view is missing: reporting.vw_uc4_care_path_breaks. Finish and validate 08 first.'; END IF;
SELECT array_agg(column_name::text ORDER BY ordinal_position) INTO actual_cols FROM information_schema.columns WHERE table_schema='reporting' AND table_name='vw_uc4_care_path_breaks';
IF actual_cols IS DISTINCT FROM ARRAY['patient_id','display_name','break_type','detail','event_date']::text[] THEN RAISE EXCEPTION 'Column contract differs for vw_uc4_care_path_breaks'; END IF;
END $check$;
\copy (SELECT patient_id, display_name, home_clinic, last_test_date, last_hba1c_mmol_mol, first_review_date, care_gap_status, as_of_date FROM reporting.vw_uc1_care_gaps ORDER BY patient_id) TO 'uc1.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT patient_id, display_name, drug_class, fills_counted, covered_days, window_days, pdc, adherence_status, window_start, window_end, as_of_date FROM reporting.vw_uc2_pdc ORDER BY patient_id, drug_class) TO 'uc2.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT patient_id, display_name, n_results, first_test_date, first_hba1c, last_test_date, last_hba1c, change_mmol_mol, trend_status, best_pdc, rising_despite_adherence, as_of_date FROM reporting.vw_uc3_hba1c_trend ORDER BY patient_id) TO 'uc3.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT patient_id, display_name, break_type, detail, event_date FROM reporting.vw_uc4_care_path_breaks ORDER BY patient_id, break_type, event_date) TO 'uc4.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy (SELECT current_database() AS database_name, current_user AS export_role, transaction_timestamp() AS export_timestamp, param_name, param_value FROM reporting.rule_parameter ORDER BY param_name) TO 'export_metadata.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
COMMIT;
