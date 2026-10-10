-- File: tests/E4_acceptance_checks.sql
-- Read-only checks for the final team fixture, as_of_date = 2026-09-01.
-- Owner: Shuo Ding (E). Run AFTER the leader's full rebuild, not before it.
-- Business rules v1.2 / task card E-4. No writes or parameter changes.

-- 1. Record database, all parameters and view availability.
SELECT current_database() AS database_name, param_name, param_value
FROM reporting.rule_parameter ORDER BY param_name;

-- 2. Full UC1 listing: 8 rows; keep ALL columns in the evidence.
SELECT current_database() AS database_name, v.*
FROM reporting.vw_uc1_care_gaps v ORDER BY patient_id;

-- 3. Full UC1 patient/status comparison: 8 PASS rows, no extras.
WITH expected(patient_id, care_gap_status) AS (VALUES
        ('GL-0001', 'HIGH_NO_REVIEW'),
        ('GL-0002', 'HIGH_REVIEW_PENDING'),
        ('GL-0003', 'OVERDUE_TEST'),
        ('GL-0006', 'NO_TEST_ON_RECORD'),
        ('GL-0010', 'OVERDUE_TEST'),
        ('GL-0012', 'HIGH_NO_REVIEW'),
        ('GL-0014', 'HIGH_REVIEW_PENDING'),
        ('GL-0016', 'HIGH_REVIEW_PENDING')
), actual AS (
    SELECT patient_id, min(care_gap_status) AS care_gap_status, count(*) AS row_count
    FROM reporting.vw_uc1_care_gaps GROUP BY patient_id
)
SELECT current_database() AS database_name, coalesce(e.patient_id,a.patient_id) AS patient_id,
       a.care_gap_status AS actual_status, e.care_gap_status AS expected_status,
       CASE WHEN a.row_count = 1 AND a.care_gap_status = e.care_gap_status
            THEN 'PASS' ELSE 'FAIL' END AS status
FROM expected e FULL JOIN actual a USING (patient_id) ORDER BY patient_id;

-- 4. Full UC3 listing: 16 rows; keep ALL columns in the evidence.
SELECT current_database() AS database_name, v.*
FROM reporting.vw_uc3_hba1c_trend v ORDER BY patient_id;

-- 5. Full UC3 patient/status/change/flag comparison: 16 PASS rows, no extras.
WITH expected(patient_id, trend_status, change_mmol_mol, rising_despite_adherence) AS (VALUES
        ('GL-0001', 'RISING', 12::numeric, true),
        ('GL-0002', 'STABLE', 0::numeric, false),
        ('GL-0003', 'INSUFFICIENT_HISTORY', NULL::numeric, false),
        ('GL-0004', 'STABLE', 1::numeric, false),
        ('GL-0005', 'STABLE', 1.1::numeric, false),
        ('GL-0007', 'INSUFFICIENT_HISTORY', NULL::numeric, false),
        ('GL-0008', 'STABLE', -1::numeric, false),
        ('GL-0009', 'STABLE', -1::numeric, false),
        ('GL-0010', 'INSUFFICIENT_HISTORY', NULL::numeric, false),
        ('GL-0011', 'STABLE', -4::numeric, false),
        ('GL-0012', 'INSUFFICIENT_HISTORY', NULL::numeric, false),
        ('GL-0013', 'RISING', 5::numeric, false),
        ('GL-0014', 'RISING', 6::numeric, false),
        ('GL-0015', 'STABLE', -1::numeric, false),
        ('GL-0016', 'RISING', 12::numeric, true),
        ('GL-0017', 'INSUFFICIENT_HISTORY', NULL::numeric, false)
), actual AS (
    SELECT v.*, count(*) OVER (PARTITION BY patient_id) AS row_count
    FROM reporting.vw_uc3_hba1c_trend v
)
SELECT current_database() AS database_name, coalesce(e.patient_id,a.patient_id) AS patient_id,
       a.trend_status, a.change_mmol_mol, a.rising_despite_adherence,
       CASE WHEN e.patient_id IS NOT NULL AND a.row_count = 1
                 AND a.trend_status = e.trend_status
                 AND a.change_mmol_mol IS NOT DISTINCT FROM e.change_mmol_mol
                 AND a.rising_despite_adherence IS NOT DISTINCT FROM e.rising_despite_adherence
            THEN 'PASS' ELSE 'FAIL' END AS status
FROM expected e FULL JOIN actual a USING (patient_id) ORDER BY patient_id;

-- 6. Summary: 8 / 16 / 4 / 7 / 5 / 0 / 2, all PASS.
WITH checks(check_name, actual_count, expected_count) AS (
    SELECT 'UC1 rows', count(*), 8 FROM reporting.vw_uc1_care_gaps
    UNION ALL SELECT 'UC3 rows', count(*), 16 FROM reporting.vw_uc3_hba1c_trend
    UNION ALL SELECT 'RISING', count(*), 4 FROM reporting.vw_uc3_hba1c_trend WHERE trend_status='RISING'
    UNION ALL SELECT 'STABLE', count(*), 7 FROM reporting.vw_uc3_hba1c_trend WHERE trend_status='STABLE'
    UNION ALL SELECT 'INSUFFICIENT_HISTORY', count(*), 5 FROM reporting.vw_uc3_hba1c_trend WHERE trend_status='INSUFFICIENT_HISTORY'
    UNION ALL SELECT 'FALLING', count(*), 0 FROM reporting.vw_uc3_hba1c_trend WHERE trend_status='FALLING'
    UNION ALL SELECT 'Rising despite adherence', count(*), 2 FROM reporting.vw_uc3_hba1c_trend WHERE rising_despite_adherence
)
SELECT current_database() AS database_name, *,
       CASE WHEN actual_count=expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks ORDER BY check_name;

-- 7. Key examples: all PASS; single-result change must be NULL, not zero.
WITH checks(check_name, passed) AS (
    SELECT 'Thomas latest result / expired review', EXISTS (
        SELECT 1 FROM reporting.vw_uc1_care_gaps WHERE patient_id='GL-0001'
        AND last_test_date=DATE '2026-05-20' AND last_hba1c_mmol_mol=62
        AND first_review_date IS NULL AND care_gap_status='HIGH_NO_REVIEW')
    UNION ALL SELECT 'William rejected latest result ignored', EXISTS (
        SELECT 1 FROM reporting.vw_uc1_care_gaps WHERE patient_id='GL-0010'
        AND last_test_date=DATE '2026-02-01' AND care_gap_status='OVERDUE_TEST')
    UNION ALL SELECT 'Chloe and Grace not in UC1', NOT EXISTS (
        SELECT 1 FROM reporting.vw_uc1_care_gaps WHERE patient_id IN ('GL-0013','GL-0009'))
    UNION ALL SELECT 'Ava duplicate excluded upstream', EXISTS (
        SELECT 1 FROM reporting.vw_uc3_hba1c_trend WHERE patient_id='GL-0015' AND n_results=2)
    UNION ALL SELECT 'Zoe converted results preserved', EXISTS (
        SELECT 1 FROM reporting.vw_uc3_hba1c_trend WHERE patient_id='GL-0016'
        AND first_hba1c=53 AND last_hba1c=65 AND rising_despite_adherence)
    UNION ALL SELECT 'Single-result change is NULL', NOT EXISTS (
        SELECT 1 FROM reporting.vw_uc3_hba1c_trend WHERE n_results<2
        AND (change_mmol_mol IS NOT NULL OR trend_status<>'INSUFFICIENT_HISTORY'))
    UNION ALL SELECT 'Missing PDC gives false flag', NOT EXISTS (
        SELECT 1 FROM reporting.vw_uc3_hba1c_trend WHERE best_pdc IS NULL
        AND rising_despite_adherence IS DISTINCT FROM false)
)
SELECT current_database() AS database_name, check_name,
       CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks ORDER BY check_name;
