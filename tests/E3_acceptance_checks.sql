-- E-3 read-only evidence checks. Run one numbered query at a time.
-- Capture the complete SQL, database name and all result rows in each screenshot.

-- 1. Three PASS rows: encounter 28, lab_result 32, dispense 65.
SELECT current_database() AS database_name, table_name, row_count,
       unique_event_ids, expected_count,
       CASE WHEN row_count = expected_count AND unique_event_ids = row_count
            THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT 1 AS sort_order, 'fact_encounter' AS table_name,
           count(*) AS row_count,
           count(DISTINCT encounter_id) AS unique_event_ids,
           28 AS expected_count FROM curated.fact_encounter
    UNION ALL
    SELECT 2 AS sort_order, 'fact_lab_result' AS table_name,
           count(*) AS row_count,
           count(DISTINCT message_id) AS unique_event_ids,
           32 AS expected_count FROM curated.fact_lab_result
    UNION ALL
    SELECT 3 AS sort_order, 'fact_dispense' AS table_name,
           count(*) AS row_count,
           count(DISTINCT dispense_id) AS unique_event_ids,
           65 AS expected_count FROM curated.fact_dispense
) counts ORDER BY sort_order;

-- 2. Exclusions plus positive controls; all six rows should PASS.
WITH checks AS (
    SELECT 'PH-1012 excluded' AS check_name, count(*) AS actual_count, 0 AS expected_count
    FROM curated.fact_dispense f JOIN cleansed.dispense s USING (dispense_id)
    WHERE s.pharmacy_patient_id = 'PH-1012'
    UNION ALL
    SELECT 'PH-1001 retained (control)', count(*), 7
    FROM curated.fact_dispense f JOIN cleansed.dispense s USING (dispense_id)
    WHERE s.pharmacy_patient_id = 'PH-1001'
    UNION ALL
    SELECT 'PATH0006 excluded', count(*), 0
    FROM curated.fact_lab_result f JOIN cleansed.lab_result s USING (message_id)
    WHERE s.lab_patient_id = 'PATH0006'
    UNION ALL
    SELECT 'OBS-0013 excluded', count(*), 0
    FROM curated.fact_lab_result WHERE observation_id = 'OBS-0013'
    UNION ALL
    SELECT 'OBS-0001 retained (control)', count(*), 1
    FROM curated.fact_lab_result WHERE observation_id = 'OBS-0001'
    UNION ALL
    SELECT 'Non-VALID lab messages excluded', count(*), 0
    FROM curated.fact_lab_result f JOIN cleansed.lab_result s USING (message_id)
    WHERE s.dq_status IS DISTINCT FROM 'VALID'
)
SELECT current_database() AS database_name, check_name, actual_count, expected_count,
       CASE WHEN actual_count = expected_count THEN 'PASS' ELSE 'FAIL' END AS status
FROM checks ORDER BY check_name;

-- 3. Lab values, dates and delivery flags must be preserved from CLEANSED.
SELECT current_database() AS database_name, count(*) AS lab_rows_checked,
       count(*) FILTER (
           WHERE s.message_id IS NULL
              OR f.hba1c_mmol_mol IS DISTINCT FROM s.hba1c_mmol_mol
              OR cd.full_date IS DISTINCT FROM s.collected_date
              OR rd.full_date IS DISTINCT FROM s.reported_date
              OR f.result_returned_flag IS DISTINCT FROM (s.returned_at IS NOT NULL)
       ) AS mismatch_rows
FROM curated.fact_lab_result f
LEFT JOIN cleansed.lab_result s USING (message_id)
LEFT JOIN curated.dim_date cd ON cd.date_key = f.collected_date_key
LEFT JOIN curated.dim_date rd ON rd.date_key = f.reported_date_key;
-- Expected: 32 checked, 0 mismatches.

-- 4. Date and delivery spot checks, expected OBS-0001: 2025-10-10 / 2025-10-11;
-- OBS-0010: result_returned_flag = false.
SELECT current_database() AS database_name, f.message_id, f.observation_id,
       cd.full_date AS collected_date, rd.full_date AS reported_date,
       f.hba1c_mmol_mol, f.result_returned_flag
FROM curated.fact_lab_result f
JOIN curated.dim_date cd ON cd.date_key = f.collected_date_key
JOIN curated.dim_date rd ON rd.date_key = f.reported_date_key
WHERE f.observation_id IN ('OBS-0001', 'OBS-0010')
ORDER BY f.observation_id;

-- 5. Fact foreign keys recreated and validated: 3 / 5 / 4, all PASS.
WITH expected(table_name, expected_fk_count) AS (
    VALUES ('fact_encounter', 3), ('fact_lab_result', 5), ('fact_dispense', 4)
)
SELECT current_database() AS database_name, e.table_name,
       count(c.oid) AS fk_count, e.expected_fk_count,
       CASE WHEN count(c.oid) = e.expected_fk_count AND bool_and(c.convalidated)
            THEN 'PASS' ELSE 'FAIL' END AS status
FROM expected e
LEFT JOIN pg_constraint c
  ON c.conrelid = to_regclass('curated.' || e.table_name) AND c.contype = 'f'
GROUP BY e.table_name, e.expected_fk_count ORDER BY e.table_name;
