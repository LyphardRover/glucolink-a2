-- =====================================================================
-- Package: F (Minha Kim) - task card F-4
-- Purpose: Automated acceptance tests for the GlucoLink A2 pipeline.
--          Every test writes one row to audit.test_result; the summary
--          query at the end must show failed = 0.
-- Source:  tests/test_plan_v1.xlsx (v1.1, L/Q/I/U/R rows) plus the five
--          E-3 fact checks from tests/E3_acceptance_checks.sql (Shuo Ding),
--          carried over here as L08, L12, L13, L14, L15 and I07, I08.
-- Rules:   business_rules_v1.2, decisions D1-D12.
-- Reads:   src_*, raw, cleansed, curated, reporting, audit
-- Writes:  audit.test_result ONLY. No source, pipeline or parameter rows
--          are changed. Safe to re-run: the table is truncated first.
-- Run:     after sql/08_reporting_views.sql, as one script (CloudBeaver
--          "Execute script" / Alt+X, or psql -f).
-- =====================================================================

CREATE TABLE IF NOT EXISTS audit.test_result (
    test_id     text PRIMARY KEY,
    description text NOT NULL,
    expected    text NOT NULL,
    actual      text,
    passed      boolean GENERATED ALWAYS AS (actual IS NOT DISTINCT FROM expected) STORED
);
COMMENT ON TABLE audit.test_result IS
    'Acceptance test results written by sql/09_tests.sql (package F). passed = (actual = expected).';

TRUNCATE audit.test_result;

-- ---------------------------------------------------------------------
-- L. Load and layer completeness
-- ---------------------------------------------------------------------

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L01', 'src_gp row counts after 02_src_data.sql',
       'clinic 3; gp_patient 18; encounter 28',
       'clinic ' || (SELECT count(*) FROM src_gp.clinic)
    || '; gp_patient ' || (SELECT count(*) FROM src_gp.gp_patient)
    || '; encounter ' || (SELECT count(*) FROM src_gp.encounter);

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L02', 'src_lab row counts after 02_src_data.sql and 02b_src_lab_messages.sql',
       'laboratory 2; lab_patient 17; observation_message 36; result_delivery 34',
       'laboratory ' || (SELECT count(*) FROM src_lab.laboratory)
    || '; lab_patient ' || (SELECT count(*) FROM src_lab.lab_patient)
    || '; observation_message ' || (SELECT count(*) FROM src_lab.observation_message)
    || '; result_delivery ' || (SELECT count(*) FROM src_lab.result_delivery);

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L03', 'src_pharm row counts after 02_src_data.sql',
       'pharmacy 3; medication 3; pharmacy_patient 13; dispense 68',
       'pharmacy ' || (SELECT count(*) FROM src_pharm.pharmacy)
    || '; medication ' || (SELECT count(*) FROM src_pharm.medication)
    || '; pharmacy_patient ' || (SELECT count(*) FROM src_pharm.pharmacy_patient)
    || '; dispense ' || (SELECT count(*) FROM src_pharm.dispense);

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L04', 'audit.identity_truth is a complete answer key: one row per source record, 18 persons',
       'n_rows 48; persons 18; known_system 48',
       'n_rows ' || count(*)
    || '; persons ' || count(DISTINCT true_person_id)
    || '; known_system ' || count(*) FILTER (WHERE source_system IN ('GP','LAB','PHARM'))
FROM audit.identity_truth;

INSERT INTO audit.test_result (test_id, description, expected, actual)
WITH pairs AS (
    SELECT 'raw.gp_clinic' AS raw_table, (SELECT count(*) FROM src_gp.clinic) AS src_rows, (SELECT count(*) FROM raw.gp_clinic) AS raw_rows
    UNION ALL SELECT 'raw.gp_patient',      (SELECT count(*) FROM src_gp.gp_patient),             (SELECT count(*) FROM raw.gp_patient)
    UNION ALL SELECT 'raw.gp_encounter',    (SELECT count(*) FROM src_gp.encounter),              (SELECT count(*) FROM raw.gp_encounter)
    UNION ALL SELECT 'raw.lab_laboratory',  (SELECT count(*) FROM src_lab.laboratory),            (SELECT count(*) FROM raw.lab_laboratory)
    UNION ALL SELECT 'raw.lab_patient',     (SELECT count(*) FROM src_lab.lab_patient),           (SELECT count(*) FROM raw.lab_patient)
    UNION ALL SELECT 'raw.lab_observation', (SELECT count(*) FROM src_lab.observation_message),   (SELECT count(*) FROM raw.lab_observation)
    UNION ALL SELECT 'raw.lab_delivery',    (SELECT count(*) FROM src_lab.result_delivery),       (SELECT count(*) FROM raw.lab_delivery)
    UNION ALL SELECT 'raw.pharm_pharmacy',  (SELECT count(*) FROM src_pharm.pharmacy),            (SELECT count(*) FROM raw.pharm_pharmacy)
    UNION ALL SELECT 'raw.pharm_medication',(SELECT count(*) FROM src_pharm.medication),          (SELECT count(*) FROM raw.pharm_medication)
    UNION ALL SELECT 'raw.pharm_patient',   (SELECT count(*) FROM src_pharm.pharmacy_patient),    (SELECT count(*) FROM raw.pharm_patient)
    UNION ALL SELECT 'raw.pharm_dispense',  (SELECT count(*) FROM src_pharm.dispense),            (SELECT count(*) FROM raw.pharm_dispense)
)
SELECT 'L05', '03_raw_extract.sql copies all 11 source tables unchanged (raw row count = source row count)',
       'tables 11; mismatches 0; raw_rows 225',
       'tables ' || count(*)
    || '; mismatches ' || count(*) FILTER (WHERE src_rows <> raw_rows)
    || '; raw_rows ' || sum(raw_rows)
FROM pairs;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L06', 'reporting.rule_parameter holds exactly the nine D1 parameters with the agreed values',
       'n 9; as_of_date=2026-09-01; hba1c_high_mmol=53; pdc_threshold=0.8; pdc_window_days=180; return_grace_days=7; review_window_days=90; test_overdue_months=6; trend_min_change_mmol=5; trend_window_months=12',
       'n ' || count(*) || '; ' || string_agg(param_name || '=' || param_value, '; ' ORDER BY param_name)
FROM reporting.rule_parameter;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L07', 'Latest 03_raw_extract run is logged in audit.pipeline_run as SUCCESS with 225 rows read and loaded',
       '03_raw_extract SUCCESS; rows_read 225; rows_loaded 225; rows_rejected 0; finished true',
       coalesce((SELECT pipeline_name || ' ' || status
                     || '; rows_read ' || rows_read
                     || '; rows_loaded ' || rows_loaded
                     || '; rows_rejected ' || rows_rejected
                     || '; finished ' || (finished_at IS NOT NULL)
                 FROM audit.pipeline_run
                 WHERE pipeline_name = '03_raw_extract'
                 ORDER BY run_id DESC LIMIT 1), 'no 03_raw_extract run logged');

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L08', 'Curated fact tables hold exactly the VALID events of LINKED patients (E-3 check 1)',
       'fact_encounter 28; fact_lab_result 32; fact_dispense 65',
       'fact_encounter ' || (SELECT count(*) FROM curated.fact_encounter)
    || '; fact_lab_result ' || (SELECT count(*) FROM curated.fact_lab_result)
    || '; fact_dispense ' || (SELECT count(*) FROM curated.fact_dispense);

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L09', 'curated.dim_date covers 2025-01-01 to 2026-12-31 with one row per day and unique keys',
       'n 730; first 2025-01-01; last 2026-12-31; distinct_keys 730',
       'n ' || count(*)
    || '; first ' || min(full_date)
    || '; last ' || max(full_date)
    || '; distinct_keys ' || count(DISTINCT date_key)
FROM curated.dim_date;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L10', 'curated.dim_patient: one row per golden patient, ids GL-0001..GL-0017 (D4), every patient has a home clinic (D3)',
       'n 17; first GL-0001; last GL-0017; well_formed 17; null_home_clinic 0',
       'n ' || count(*)
    || '; first ' || min(patient_id)
    || '; last ' || max(patient_id)
    || '; well_formed ' || count(*) FILTER (WHERE patient_id ~ '^GL-[0-9]{4}$')
    || '; null_home_clinic ' || count(*) FILTER (WHERE home_clinic_key IS NULL)
FROM curated.dim_patient;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L12', 'No duplicate events in the facts: distinct source event ids = row count in every fact table (re-sent MSG-0032 must not duplicate OBS-0031)',
       'dup_encounters 0; dup_messages 0; dup_observations 0; dup_dispenses 0',
       'dup_encounters ' || (SELECT count(*) - count(DISTINCT encounter_id)   FROM curated.fact_encounter)
    || '; dup_messages ' || (SELECT count(*) - count(DISTINCT message_id)     FROM curated.fact_lab_result)
    || '; dup_observations ' || (SELECT count(*) - count(DISTINCT observation_id) FROM curated.fact_lab_result)
    || '; dup_dispenses ' || (SELECT count(*) - count(DISTINCT dispense_id)    FROM curated.fact_dispense);

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L13', 'Lab values, dates and delivery flags in curated.fact_lab_result are preserved from cleansed.lab_result (E-3 check 3)',
       'lab_rows_checked 32; mismatch_rows 0',
       'lab_rows_checked ' || count(*)
    || '; mismatch_rows ' || count(*) FILTER (
           WHERE s.message_id IS NULL
              OR f.hba1c_mmol_mol IS DISTINCT FROM s.hba1c_mmol_mol
              OR cd.full_date IS DISTINCT FROM s.collected_date
              OR rd.full_date IS DISTINCT FROM s.reported_date
              OR f.result_returned_flag IS DISTINCT FROM (s.returned_at IS NOT NULL))
FROM curated.fact_lab_result f
LEFT JOIN cleansed.lab_result s USING (message_id)
LEFT JOIN curated.dim_date cd ON cd.date_key = f.collected_date_key
LEFT JOIN curated.dim_date rd ON rd.date_key = f.reported_date_key;

INSERT INTO audit.test_result (test_id, description, expected, actual)
WITH expected(table_name, expected_fk_count) AS (
    VALUES ('fact_encounter', 3), ('fact_lab_result', 5), ('fact_dispense', 4)
), fk AS (
    SELECT e.table_name, count(c.oid) AS fk_count, e.expected_fk_count,
           coalesce(bool_and(c.convalidated), false) AS all_validated
    FROM expected e
    LEFT JOIN pg_constraint c
      ON c.conrelid = to_regclass('curated.' || e.table_name) AND c.contype = 'f'
    GROUP BY e.table_name, e.expected_fk_count
)
SELECT 'L14', 'Fact table foreign keys are recreated and validated after 07 (E-3 check 5)',
       'fact_dispense 4 validated; fact_encounter 3 validated; fact_lab_result 5 validated',
       string_agg(table_name || ' ' || fk_count || CASE WHEN all_validated THEN ' validated' ELSE ' NOT validated' END,
                  '; ' ORDER BY table_name)
FROM fk;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'L15', 'Fact date keys resolve to the cleansed dates and OBS-0010 carries result_returned_flag = false (E-3 check 4)',
       'OBS-0001 collected 2025-10-10 reported 2025-10-11 returned true; OBS-0010 returned false',
       (SELECT 'OBS-0001 collected ' || cd.full_date || ' reported ' || rd.full_date || ' returned ' || f.result_returned_flag
          FROM curated.fact_lab_result f
          JOIN curated.dim_date cd ON cd.date_key = f.collected_date_key
          JOIN curated.dim_date rd ON rd.date_key = f.reported_date_key
         WHERE f.observation_id = 'OBS-0001')
    || '; ' ||
       (SELECT 'OBS-0010 returned ' || f.result_returned_flag
          FROM curated.fact_lab_result f WHERE f.observation_id = 'OBS-0010');

-- ---------------------------------------------------------------------
-- Q. Data quality and standardisation (04_cleansed_standardise.sql)
-- ---------------------------------------------------------------------

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'Q01', 'cleansed.patient_record: one standardised row per source patient record, split by source system (Appendix C)',
       'GP 18; LAB 17; PHARM 13; total 48',
       string_agg(source_system || ' ' || n, '; ' ORDER BY source_system) || '; total ' || sum(n)
FROM (SELECT source_system, count(*) AS n FROM cleansed.patient_record GROUP BY source_system) s;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'Q02', 'cleansed.lab_result assigns every one of the 36 messages exactly one dq_status (Appendix C distribution)',
       'DUPLICATE 1; FUTURE_DATE 1; REJECTED_UNIT 1; VALID 33; total 36',
       string_agg(dq_status || ' ' || n, '; ' ORDER BY dq_status) || '; total ' || sum(n)
FROM (SELECT dq_status, count(*) AS n FROM cleansed.lab_result GROUP BY dq_status) s;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'Q03', 'The three excluded messages are the intended ones: MSG-0022 REJECTED_UNIT (unit kept as empty string, hba1c NULL), MSG-0025 FUTURE_DATE, MSG-0032 DUPLICATE of OBS-0031 while MSG-0031 stays VALID',
       'MSG-0022 OBS-0022 REJECTED_UNIT; MSG-0025 OBS-0025 FUTURE_DATE; MSG-0031 OBS-0031 VALID; MSG-0032 OBS-0031 DUPLICATE; MSG-0022 unit_empty true hba1c_null true',
       (SELECT string_agg(message_id || ' ' || observation_id || ' ' || dq_status, '; ' ORDER BY message_id)
          FROM cleansed.lab_result
         WHERE message_id IN ('MSG-0022','MSG-0025','MSG-0031','MSG-0032'))
    || (SELECT '; MSG-0022 unit_empty ' || (unit_as_received = '') || ' hba1c_null ' || (hba1c_mmol_mol IS NULL)
          FROM cleansed.lab_result WHERE message_id = 'MSG-0022');

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'Q04', 'Data trap - Sydney dates: JSON timestamps are converted in Australia/Sydney before taking the date; reported_date is always collected_date + 1',
       'MSG-0001 collected 2025-10-10 reported 2025-10-11; rows_with_wrong_gap 0',
       (SELECT 'MSG-0001 collected ' || collected_date || ' reported ' || reported_date
          FROM cleansed.lab_result WHERE message_id = 'MSG-0001')
    || '; rows_with_wrong_gap ' || (SELECT count(*) FROM cleansed.lab_result WHERE reported_date <> collected_date + 1);

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'Q05', 'Data trap - Medicare normalisation: digits before "/" kept only when exactly 10 digits remain, spaces removed, otherwise NULL',
       'GP-0009 3890123478; PATH0004 5456789034; PH-1006 2567890145; PH-1014 NULL; bad_length 0',
       (SELECT string_agg(source_patient_id || ' ' || coalesce(medicare10, 'NULL'), '; ' ORDER BY source_patient_id)
          FROM cleansed.patient_record
         WHERE source_patient_id IN ('GP-0009','PATH0004','PH-1006','PH-1014'))
    || '; bad_length ' || (SELECT count(*) FROM cleansed.patient_record WHERE length(medicare10) <> 10);

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'Q06', 'Percent HbA1c results (LOINC 4548-4) are converted to mmol/mol with (% - 2.15) x 10.929, rounded to 1 decimal (P17 Zoe Clark)',
       'OBS-0033 53.0; OBS-0034 65.0',
       string_agg(observation_id || ' ' || to_char(hba1c_mmol_mol, 'FM990.0'), '; ' ORDER BY observation_id)
FROM cleansed.lab_result WHERE observation_id IN ('OBS-0033','OBS-0034');

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'Q07', 'Card D four-row check: names upper-cased, given_name = first word, ISO dates, 15-Jan-49 -> 1949-01-15, Medicare normalised identically in all three sources',
       'GP-0001 THOMAS SMITH 1962-05-14 2123456701; PATH0001 THOMAS SMITH 1962-05-14 2123456701; PH-1001 T SMITH 1962-05-14 2123456701; PH-1014 E LEWIS 1949-01-15 NULL',
       string_agg(source_patient_id || ' ' || given_name || ' ' || family_name || ' ' || dob || ' ' || coalesce(medicare10, 'NULL'),
                  '; ' ORDER BY source_patient_id)
FROM cleansed.patient_record
WHERE source_patient_id IN ('GP-0001','PATH0001','PH-1001','PH-1014');

-- ---------------------------------------------------------------------
-- I. Identity resolution (05_identity_resolution.sql)
-- ---------------------------------------------------------------------

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'I01', 'cleansed.patient_master is built from GP records only; Sarah Lee''s duplicate GP registration (GP-0008/GP-0009) collapses into one golden patient',
       'patient_master 17',
       'patient_master ' || count(*)
FROM cleansed.patient_master;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'I02', 'cleansed.patient_source_link classifies all 48 source records with the Appendix C status distribution',
       'LINKED 46; REVIEW 1; UNMATCHED 1; total 48',
       string_agg(match_status || ' ' || n, '; ' ORDER BY match_status) || '; total ' || sum(n)
FROM (SELECT match_status, count(*) AS n FROM cleansed.patient_source_link GROUP BY match_status) s;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'I03', 'Rule R1 links the same Medicare number written three ways to one golden patient; the GP record carries match_rule GP (P01 Thomas Smith)',
       'GP-0001 GL-0001 LINKED GP; PATH0001 GL-0001 LINKED R1; PH-1001 GL-0001 LINKED R1',
       string_agg(source_patient_id || ' ' || coalesce(patient_id, 'NULL') || ' ' || match_status || ' ' || coalesce(match_rule, 'NULL'),
                  '; ' ORDER BY source_patient_id)
FROM cleansed.patient_source_link
WHERE source_patient_id IN ('GP-0001','PATH0001','PH-1001');

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'I04', 'Rule R2 links pharmacy records without Medicare by dob + family name + first initial when there is exactly one candidate (P02 Mei Chen, P18 Ethan Lewis)',
       'PH-1002 GL-0002 LINKED R2 candidates 1; PH-1014 GL-0017 LINKED R2 candidates 1',
       string_agg(source_patient_id || ' ' || coalesce(patient_id, 'NULL') || ' ' || match_status || ' ' || coalesce(match_rule, 'NULL') || ' candidates ' || candidate_count,
                  '; ' ORDER BY source_patient_id)
FROM cleansed.patient_source_link
WHERE source_patient_id IN ('PH-1002','PH-1014');

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'I05', 'A record with two candidate masters (PATH0006: no Medicare, same name and dob as P06 and P07) goes to REVIEW and is never merged (D7)',
       'PATH0006 NULL REVIEW NULL candidates 2',
       source_patient_id || ' ' || coalesce(patient_id, 'NULL') || ' ' || match_status || ' ' || coalesce(match_rule, 'NULL') || ' candidates ' || candidate_count
FROM cleansed.patient_source_link
WHERE source_patient_id = 'PATH0006';

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'I06', 'A pharmacy-only person with no GP registration stays UNMATCHED with no candidate (P16 Jack Thompson)',
       'PH-1012 NULL UNMATCHED NULL candidates 0',
       source_patient_id || ' ' || coalesce(patient_id, 'NULL') || ' ' || match_status || ' ' || coalesce(match_rule, 'NULL') || ' candidates ' || candidate_count
FROM cleansed.patient_source_link
WHERE source_patient_id = 'PH-1012';

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'I07', 'UNMATCHED and REVIEW records are excluded from the facts, with positive controls (PH-1012 and PATH0006 absent; PH-1001 and OBS-0001 present)',
       'unmatched_dispenses 0; control_dispenses 7; review_results 0; control_results 1',
       'unmatched_dispenses ' || (SELECT count(*) FROM curated.fact_dispense   WHERE dispense_id LIKE 'D-PH-1012-%')
    || '; control_dispenses ' || (SELECT count(*) FROM curated.fact_dispense   WHERE dispense_id LIKE 'D-PH-1001-%')
    || '; review_results ' || (SELECT count(*) FROM curated.fact_lab_result WHERE observation_id = 'OBS-0013')
    || '; control_results ' || (SELECT count(*) FROM curated.fact_lab_result WHERE observation_id = 'OBS-0001');

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'I08', 'Fact exclusions checked through the cleansed source ids: no PH-1012 dispenses, no PATH0006 results, no non-VALID lab messages in the facts (E-3 check 2)',
       'ph1012_dispenses 0; path0006_results 0; non_valid_lab_rows 0',
       'ph1012_dispenses ' || (SELECT count(*) FROM curated.fact_dispense f JOIN cleansed.dispense s USING (dispense_id)
                                 WHERE s.pharmacy_patient_id = 'PH-1012')
    || '; path0006_results ' || (SELECT count(*) FROM curated.fact_lab_result f JOIN cleansed.lab_result s USING (message_id)
                                 WHERE s.lab_patient_id = 'PATH0006')
    || '; non_valid_lab_rows ' || (SELECT count(*) FROM curated.fact_lab_result f JOIN cleansed.lab_result s USING (message_id)
                                 WHERE s.dq_status IS DISTINCT FROM 'VALID');

INSERT INTO audit.test_result (test_id, description, expected, actual)
WITH gp_truth AS (
    SELECT l.patient_id, t.true_person_id
    FROM cleansed.patient_source_link l
    JOIN audit.identity_truth t USING (source_system, source_patient_id)
    WHERE l.source_system = 'GP' AND l.match_status = 'LINKED'
    GROUP BY l.patient_id, t.true_person_id
), lp AS (
    SELECT l.source_system, l.source_patient_id, l.match_status, l.patient_id, t.true_person_id,
           EXISTS (SELECT 1 FROM gp_truth g WHERE g.true_person_id = t.true_person_id) AS has_gp,
           EXISTS (SELECT 1 FROM gp_truth g WHERE g.patient_id = l.patient_id
                                              AND g.true_person_id = t.true_person_id) AS correct
    FROM cleansed.patient_source_link l
    JOIN audit.identity_truth t USING (source_system, source_patient_id)
    WHERE l.source_system IN ('LAB','PHARM')
)
SELECT 'I09', 'Matching quality against audit.identity_truth (read only after matching): precision 28/28, recall 28/29 (the one miss is PATH0006 in REVIEW)',
       'linked 28; correct_links 28; should_link 29; precision 1.000; recall 0.966',
       'linked ' || count(*) FILTER (WHERE match_status = 'LINKED')
    || '; correct_links ' || count(*) FILTER (WHERE match_status = 'LINKED' AND correct)
    || '; should_link ' || count(*) FILTER (WHERE has_gp)
    || '; precision ' || to_char(count(*) FILTER (WHERE match_status = 'LINKED' AND correct)::numeric
                                / NULLIF(count(*) FILTER (WHERE match_status = 'LINKED'), 0), 'FM0.000')
    || '; recall ' || to_char(count(*) FILTER (WHERE match_status = 'LINKED' AND correct)::numeric
                             / NULLIF(count(*) FILTER (WHERE has_gp), 0), 'FM0.000')
FROM lp;

-- ---------------------------------------------------------------------
-- U1. Use case 1 - care gaps (reporting.vw_uc1_care_gaps)
-- ---------------------------------------------------------------------

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U101', 'vw_uc1_care_gaps returns one row per flagged patient with the business_rules_v1.2 status distribution',
       'HIGH_NO_REVIEW 2; HIGH_REVIEW_PENDING 3; NO_TEST_ON_RECORD 1; OVERDUE_TEST 2; total 8',
       string_agg(care_gap_status || ' ' || n, '; ' ORDER BY care_gap_status) || '; total ' || sum(n)
FROM (SELECT care_gap_status, count(*) AS n FROM reporting.vw_uc1_care_gaps GROUP BY care_gap_status) s;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U102', 'Full listing of vw_uc1_care_gaps matches card E-4 row by row',
       'GL-0001 Thomas Smith HIGH_NO_REVIEW; GL-0002 Mei Chen HIGH_REVIEW_PENDING; GL-0003 Ahmed Khan OVERDUE_TEST; GL-0006 Daniel Nguyen NO_TEST_ON_RECORD; GL-0010 William Jones OVERDUE_TEST; GL-0012 Lucas Martin HIGH_NO_REVIEW; GL-0014 Noah Harris HIGH_REVIEW_PENDING; GL-0016 Zoe Clark HIGH_REVIEW_PENDING',
       string_agg(patient_id || ' ' || display_name || ' ' || care_gap_status, '; ' ORDER BY patient_id)
FROM reporting.vw_uc1_care_gaps;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U103', 'A result >= 53 mmol/mol with no review visit inside the completed 90-day window is HIGH_NO_REVIEW (P01: 62.0 on 2026-05-20, window ended 2026-08-18)',
       'GL-0001 last_test 2026-05-20 last_hba1c 62.0 first_review NULL HIGH_NO_REVIEW',
       patient_id || ' last_test ' || last_test_date || ' last_hba1c ' || to_char(last_hba1c_mmol_mol, 'FM990.0')
    || ' first_review ' || coalesce(first_review_date::text, 'NULL') || ' ' || care_gap_status
FROM reporting.vw_uc1_care_gaps
WHERE patient_id = 'GL-0001';

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U106', 'NEGATIVE - a high result followed by a review within 90 days (P13) and a patient whose latest result is below threshold (P09) are not listed',
       'n_rows 0',
       'n_rows ' || count(*)
FROM reporting.vw_uc1_care_gaps
WHERE patient_id IN ('GL-0013','GL-0009');

-- ---------------------------------------------------------------------
-- U2. Use case 2 - adherence / PDC (reporting.vw_uc2_pdc)
-- ---------------------------------------------------------------------

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U201', 'vw_uc2_pdc returns one row per eligible patient and drug class with the business_rules_v1.2 adherence distribution',
       'ADHERENT 9; NON_ADHERENT 2; total 11',
       string_agg(adherence_status || ' ' || n, '; ' ORDER BY adherence_status) || '; total ' || sum(n)
FROM (SELECT adherence_status, count(*) AS n FROM reporting.vw_uc2_pdc GROUP BY adherence_status) s;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U202', 'Full listing of vw_uc2_pdc matches card D-4 row by row (PDC to 3 decimals)',
       'GL-0001 biguanide 0.989 ADHERENT; GL-0002 biguanide 0.333 NON_ADHERENT; GL-0003 biguanide 0.978 ADHERENT; GL-0005 biguanide 0.972 ADHERENT; GL-0007 sulfonylurea 1.000 ADHERENT; GL-0008 biguanide 0.978 ADHERENT; GL-0009 biguanide 1.000 ADHERENT; GL-0010 biguanide 0.500 NON_ADHERENT; GL-0012 biguanide 0.972 ADHERENT; GL-0016 DPP-4 inhibitor 1.000 ADHERENT; GL-0017 biguanide 0.917 ADHERENT',
       string_agg(patient_id || ' ' || drug_class || ' ' || to_char(pdc, 'FM0.000') || ' ' || adherence_status, '; ' ORDER BY patient_id, drug_class)
FROM reporting.vw_uc2_pdc;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U203', 'Fills whose supply ends before the 180-day window contribute no covered days (P02 Mei Chen: only the 2026-03-20 and 2026-06-15 fills count)',
       'GL-0002 covered_days 60 pdc 0.333 NON_ADHERENT',
       patient_id || ' covered_days ' || covered_days || ' pdc ' || to_char(pdc, 'FM0.000') || ' ' || adherence_status
FROM reporting.vw_uc2_pdc
WHERE patient_id = 'GL-0002';

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U204', 'Overlapping supply days from two pharmacies are counted once, so PDC never exceeds 1.000 (P05 James Wilson)',
       'GL-0005 covered_days 175 pdc 0.972 ADHERENT; rows_over_one 0',
       (SELECT patient_id || ' covered_days ' || covered_days || ' pdc ' || to_char(pdc, 'FM0.000') || ' ' || adherence_status
          FROM reporting.vw_uc2_pdc WHERE patient_id = 'GL-0005')
    || '; rows_over_one ' || (SELECT count(*) FROM reporting.vw_uc2_pdc WHERE pdc > 1 OR covered_days > window_days);

-- ---------------------------------------------------------------------
-- U3. Use case 3 - HbA1c trend (reporting.vw_uc3_hba1c_trend)
-- ---------------------------------------------------------------------

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U301', 'vw_uc3_hba1c_trend returns one row per golden patient with >= 1 valid result in the 12-month window, with the business_rules_v1.2 distribution',
       'INSUFFICIENT_HISTORY 5; RISING 4; STABLE 7; total 16; falling_rows 0',
       string_agg(trend_status || ' ' || n, '; ' ORDER BY trend_status) || '; total ' || sum(n)
    || '; falling_rows ' || coalesce(sum(n) FILTER (WHERE trend_status = 'FALLING'), 0)
FROM (SELECT trend_status, count(*) AS n FROM reporting.vw_uc3_hba1c_trend GROUP BY trend_status) s;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U302', 'Full listing of vw_uc3_hba1c_trend matches card E-4 row by row (n_results, change, status, rising_despite_adherence)',
       'GL-0001 3 +12.0 RISING true; GL-0002 3 +0.0 STABLE false; GL-0003 1 NULL INSUFFICIENT_HISTORY false; GL-0004 2 +1.0 STABLE false; GL-0005 2 +1.1 STABLE false; GL-0007 1 NULL INSUFFICIENT_HISTORY false; GL-0008 2 -1.0 STABLE false; GL-0009 4 -1.0 STABLE false; GL-0010 1 NULL INSUFFICIENT_HISTORY false; GL-0011 2 -4.0 STABLE false; GL-0012 1 NULL INSUFFICIENT_HISTORY false; GL-0013 2 +5.0 RISING false; GL-0014 2 +6.0 RISING false; GL-0015 2 -1.0 STABLE false; GL-0016 2 +12.0 RISING true; GL-0017 1 NULL INSUFFICIENT_HISTORY false',
       string_agg(patient_id || ' ' || n_results || ' ' || coalesce(to_char(change_mmol_mol, 'FMS990.0'), 'NULL') || ' ' || trend_status || ' ' || rising_despite_adherence,
                  '; ' ORDER BY patient_id)
FROM reporting.vw_uc3_hba1c_trend;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U303', 'A change of at least +5 mmol/mol is RISING, and rising_despite_adherence is true when best PDC across drug classes >= 0.8 (P01 Thomas Smith)',
       'GL-0001 first 50.0 last 62.0 change +12.0 RISING best_pdc 0.989 rising_despite_adherence true',
       patient_id || ' first ' || to_char(first_hba1c, 'FM990.0') || ' last ' || to_char(last_hba1c, 'FM990.0')
    || ' change ' || to_char(change_mmol_mol, 'FMS990.0') || ' ' || trend_status
    || ' best_pdc ' || to_char(best_pdc, 'FM0.000') || ' rising_despite_adherence ' || rising_despite_adherence
FROM reporting.vw_uc3_hba1c_trend
WHERE patient_id = 'GL-0001';

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U306', 'NEGATIVE - results outside the window are excluded: P11''s FUTURE_DATE result is ignored (54.0 -> 50.0 STABLE); P03''s 2025-06-10 result is before the window (INSUFFICIENT_HISTORY)',
       'GL-0003 n 1 change NULL INSUFFICIENT_HISTORY; GL-0011 n 2 54.0 -> 50.0 change -4.0 STABLE',
       string_agg(patient_id || ' n ' || n_results
                  || CASE WHEN n_results >= 2 THEN ' ' || to_char(first_hba1c, 'FM990.0') || ' -> ' || to_char(last_hba1c, 'FM990.0') ELSE '' END
                  || ' change ' || coalesce(to_char(change_mmol_mol, 'FMS990.0'), 'NULL') || ' ' || trend_status,
                  '; ' ORDER BY patient_id)
FROM reporting.vw_uc3_hba1c_trend
WHERE patient_id IN ('GL-0003','GL-0011');

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U307', 'A result sent twice counts once: DUPLICATE MSG-0032 is excluded so P15 Ava Robinson has n_results 2 (51.0 -> 50.0, STABLE), not 3',
       'GL-0015 n 2 51.0 -> 50.0 change -1.0 STABLE',
       patient_id || ' n ' || n_results || ' ' || to_char(first_hba1c, 'FM990.0') || ' -> ' || to_char(last_hba1c, 'FM990.0')
    || ' change ' || to_char(change_mmol_mol, 'FMS990.0') || ' ' || trend_status
FROM reporting.vw_uc3_hba1c_trend
WHERE patient_id = 'GL-0015';

-- ---------------------------------------------------------------------
-- U4. Use case 4 - care-path breaks (reporting.vw_uc4_care_path_breaks)
-- ---------------------------------------------------------------------

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U401', 'vw_uc4_care_path_breaks returns exactly the two expected breaks (card D-4): Olivia Brown RESULT_NOT_RETURNED for OBS-0010, James Wilson MULTI_PHARMACY_OVERLAP on biguanide',
       'rows 2; GL-0004 Olivia Brown RESULT_NOT_RETURNED detail_mentions_OBS-0010 true; GL-0005 James Wilson MULTI_PHARMACY_OVERLAP detail_mentions_biguanide true',
       'rows ' || count(*) || '; '
    || string_agg(patient_id || ' ' || display_name || ' ' || break_type
                  || CASE break_type
                         WHEN 'RESULT_NOT_RETURNED'     THEN ' detail_mentions_OBS-0010 ' || (detail LIKE '%OBS-0010%')
                         WHEN 'MULTI_PHARMACY_OVERLAP'  THEN ' detail_mentions_biguanide ' || (detail ILIKE '%biguanide%')
                         ELSE '' END,
                  '; ' ORDER BY patient_id, break_type)
FROM reporting.vw_uc4_care_path_breaks;

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'U404', 'NEGATIVE - a DUPLICATE message''s missing delivery is not a break, and a patient with all results delivered and one pharmacy is not listed (P15, P09)',
       'n_rows 0',
       'n_rows ' || count(*)
FROM reporting.vw_uc4_care_path_breaks
WHERE detail LIKE '%OBS-0031%' OR detail LIKE '%MSG-0032%' OR patient_id IN ('GL-0009','GL-0015');

-- ---------------------------------------------------------------------
-- R. Re-run stability (01 -> 02 -> 02b idempotent; full 00 -> 10 rerun)
-- R02 (second full run: all tests still pass, raw_runs 2) is evidenced by
-- the summary query below after run 2 on glucolink_a2_test (card F-5).
-- ---------------------------------------------------------------------

INSERT INTO audit.test_result (test_id, description, expected, actual)
SELECT 'R01', 'Re-running 01 -> 02 -> 02b leaves every source row count unchanged (no doubled rows, no leftovers)',
       'gp_patient 18; encounter 28; observation_message 36; result_delivery 34; dispense 68',
       'gp_patient ' || (SELECT count(*) FROM src_gp.gp_patient)
    || '; encounter ' || (SELECT count(*) FROM src_gp.encounter)
    || '; observation_message ' || (SELECT count(*) FROM src_lab.observation_message)
    || '; result_delivery ' || (SELECT count(*) FROM src_lab.result_delivery)
    || '; dispense ' || (SELECT count(*) FROM src_pharm.dispense);

-- ---------------------------------------------------------------------
-- Summary (screenshot this for evidence: 2026-10-11_F_test_results.png)
-- Expected: tests 46, passed 46, failed 0, all_passed true.
-- ---------------------------------------------------------------------

SELECT current_database()                                   AS database_name,
       count(*)                                             AS tests,
       count(*) FILTER (WHERE passed)                       AS passed,
       count(*) FILTER (WHERE NOT passed OR passed IS NULL) AS failed,
       (count(*) = count(*) FILTER (WHERE passed))          AS all_passed,
       now()                                                AS checked_at
FROM audit.test_result;

-- Failures only (should return 0 rows)
SELECT test_id, description, expected, actual
FROM audit.test_result
WHERE NOT passed OR passed IS NULL
ORDER BY test_id;

-- Full register
SELECT test_id, passed, expected, actual, description
FROM audit.test_result
ORDER BY test_id;
