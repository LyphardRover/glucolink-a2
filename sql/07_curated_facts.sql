-- File:          07_curated_facts.sql
-- Package/owner: E - Shuo Ding
-- Purpose:       Rebuild three fact tables at source-event grain.
-- Reads:         cleansed.encounter, lab_result, dispense, patient_source_link;
--                curated.dim_patient, dim_date, dim_clinic, dim_lab, dim_test,
--                dim_pharmacy, dim_medication.
-- Writes:        curated.fact_encounter, fact_lab_result, fact_dispense.
-- Design link:   Task Cards v3 E-3; Business rules v1.2; logical model v1.
-- Run after:     Team run order 00 -> 01 -> 02 -> 02b -> 03 -> 04 -> 05 -> 06.
-- Re-runnable:   Yes; full rebuild in one transaction, DROP ... CASCADE.
-- Release:       9 October 2026; shared-DB acceptance is still required.
--
-- Wait for the coordinated 04 -> 05 -> 06 rerun to finish before running 07.
-- Re-run 08 after this rebuild: CASCADE removes dependent reporting views.
-- Run the WHOLE file in one session. On error, stop and run ROLLBACK.
-- Expected counts below are for the agreed A2 fixture, not arbitrary data.
-- Upstream data is read only. No database-name restriction or source resets.

BEGIN ISOLATION LEVEL REPEATABLE READ;

-- Validate dependencies before replacing existing facts.
DO $$
DECLARE required_table text;
BEGIN
    FOREACH required_table IN ARRAY ARRAY[
        'cleansed.encounter', 'cleansed.lab_result', 'cleansed.dispense',
        'cleansed.patient_source_link', 'curated.dim_patient',
        'curated.dim_date', 'curated.dim_clinic', 'curated.dim_lab',
        'curated.dim_test', 'curated.dim_pharmacy', 'curated.dim_medication'
    ] LOOP
        IF to_regclass(required_table) IS NULL THEN
            RAISE EXCEPTION 'Missing input %. Complete 04, 05 and 06 first.', required_table;
        END IF;
    END LOOP;
    IF EXISTS (
        SELECT source_system, source_patient_id
        FROM cleansed.patient_source_link
        GROUP BY source_system, source_patient_id HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'Duplicate source identity links: check 05.';
    END IF;
END $$;

-- encounter: REVIEW/UNMATCHED are intentionally excluded; a missing identity
-- row is an incomplete upstream load and must not be silently discarded.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM cleansed.encounter s
        LEFT JOIN cleansed.patient_source_link l
          ON l.source_system = 'GP' AND l.source_patient_id = s.gp_patient_id
        WHERE (l.source_patient_id IS NULL OR l.match_status IS NULL
               OR l.match_status NOT IN ('LINKED', 'REVIEW', 'UNMATCHED'))
    ) THEN
        RAISE EXCEPTION 'Missing/invalid identity status for encounter: check 04 and 05.';
    END IF;
END $$;

-- LEFT JOIN dimensions so missing keys cause an error rather than lost events.
CREATE TEMP TABLE e3_stage_encounter ON COMMIT DROP AS
SELECT s.encounter_id, p.patient_key, d.date_key, c.clinic_key, s.encounter_type, s.diagnosis_code, s.medication_review_flag, s.care_plan_flag
FROM cleansed.encounter s
JOIN cleansed.patient_source_link l
  ON l.source_system = 'GP' AND l.source_patient_id = s.gp_patient_id
LEFT JOIN curated.dim_patient p ON p.patient_id = l.patient_id
LEFT JOIN curated.dim_date d ON d.full_date = s.encounter_date
LEFT JOIN curated.dim_clinic c ON c.clinic_id = s.clinic_id
WHERE l.match_status = 'LINKED';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM e3_stage_encounter
               WHERE encounter_id IS NULL OR patient_key IS NULL OR date_key IS NULL OR clinic_key IS NULL) THEN
        RAISE EXCEPTION 'Missing required key/value in encounter; check 04/05/06 and dimension date coverage.';
    END IF;
    IF EXISTS (SELECT encounter_id FROM e3_stage_encounter
               GROUP BY encounter_id HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'Duplicate event or multiplied join in encounter.';
    END IF;
    IF (SELECT count(*) FROM e3_stage_encounter) <> 28 THEN
        RAISE EXCEPTION 'Expected 28 eligible encounter events for the A2 fixture; found %.',
            (SELECT count(*) FROM e3_stage_encounter);
    END IF;
END $$;

-- lab_result: REVIEW/UNMATCHED are intentionally excluded; a missing identity
-- row is an incomplete upstream load and must not be silently discarded.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM cleansed.lab_result s
        LEFT JOIN cleansed.patient_source_link l
          ON l.source_system = 'LAB' AND l.source_patient_id = s.lab_patient_id
        WHERE (l.source_patient_id IS NULL OR l.match_status IS NULL
               OR l.match_status NOT IN ('LINKED', 'REVIEW', 'UNMATCHED')) AND s.dq_status = 'VALID'
    ) THEN
        RAISE EXCEPTION 'Missing/invalid identity status for lab_result: check 04 and 05.';
    END IF;
END $$;

-- LEFT JOIN dimensions so missing keys cause an error rather than lost events.
CREATE TEMP TABLE e3_stage_lab_result ON COMMIT DROP AS
SELECT s.message_id, s.observation_id, p.patient_key, cd.date_key AS collected_date_key, rd.date_key AS reported_date_key, b.lab_key, t.test_key, s.hba1c_mmol_mol, (s.returned_at IS NOT NULL) AS result_returned_flag
FROM cleansed.lab_result s
JOIN cleansed.patient_source_link l
  ON l.source_system = 'LAB' AND l.source_patient_id = s.lab_patient_id
LEFT JOIN curated.dim_patient p ON p.patient_id = l.patient_id
LEFT JOIN curated.dim_date cd ON cd.full_date = s.collected_date
LEFT JOIN curated.dim_date rd ON rd.full_date = s.reported_date
LEFT JOIN curated.dim_lab b ON b.lab_id = s.lab_id
LEFT JOIN curated.dim_test t ON t.loinc_code = s.loinc_code
WHERE l.match_status = 'LINKED' AND s.dq_status = 'VALID';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM e3_stage_lab_result
               WHERE message_id IS NULL OR observation_id IS NULL OR patient_key IS NULL OR collected_date_key IS NULL OR reported_date_key IS NULL OR lab_key IS NULL OR test_key IS NULL OR hba1c_mmol_mol IS NULL) THEN
        RAISE EXCEPTION 'Missing required key/value in lab_result; check 04/05/06 and dimension date coverage.';
    END IF;
    IF EXISTS (SELECT message_id FROM e3_stage_lab_result
               GROUP BY message_id HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'Duplicate event or multiplied join in lab_result.';
    END IF;
    IF (SELECT count(*) FROM e3_stage_lab_result) <> 32 THEN
        RAISE EXCEPTION 'Expected 32 eligible lab_result events for the A2 fixture; found %.',
            (SELECT count(*) FROM e3_stage_lab_result);
    END IF;
END $$;

-- dispense: REVIEW/UNMATCHED are intentionally excluded; a missing identity
-- row is an incomplete upstream load and must not be silently discarded.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM cleansed.dispense s
        LEFT JOIN cleansed.patient_source_link l
          ON l.source_system = 'PHARM' AND l.source_patient_id = s.pharmacy_patient_id
        WHERE (l.source_patient_id IS NULL OR l.match_status IS NULL
               OR l.match_status NOT IN ('LINKED', 'REVIEW', 'UNMATCHED'))
    ) THEN
        RAISE EXCEPTION 'Missing/invalid identity status for dispense: check 04 and 05.';
    END IF;
END $$;

-- LEFT JOIN dimensions so missing keys cause an error rather than lost events.
CREATE TEMP TABLE e3_stage_dispense ON COMMIT DROP AS
SELECT s.dispense_id, p.patient_key, d.date_key, h.pharmacy_key, m.medication_key, s.quantity, s.days_supply
FROM cleansed.dispense s
JOIN cleansed.patient_source_link l
  ON l.source_system = 'PHARM' AND l.source_patient_id = s.pharmacy_patient_id
LEFT JOIN curated.dim_patient p ON p.patient_id = l.patient_id
LEFT JOIN curated.dim_date d ON d.full_date = s.dispensed_date
LEFT JOIN curated.dim_pharmacy h ON h.pharmacy_id = s.pharmacy_id
LEFT JOIN curated.dim_medication m ON m.pbs_item_code = s.pbs_item_code
WHERE l.match_status = 'LINKED';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM e3_stage_dispense
               WHERE dispense_id IS NULL OR patient_key IS NULL OR date_key IS NULL OR pharmacy_key IS NULL OR medication_key IS NULL) THEN
        RAISE EXCEPTION 'Missing required key/value in dispense; check 04/05/06 and dimension date coverage.';
    END IF;
    IF EXISTS (SELECT dispense_id FROM e3_stage_dispense
               GROUP BY dispense_id HAVING count(*) > 1) THEN
        RAISE EXCEPTION 'Duplicate event or multiplied join in dispense.';
    END IF;
    IF (SELECT count(*) FROM e3_stage_dispense) <> 65 THEN
        RAISE EXCEPTION 'Expected 65 eligible dispense events for the A2 fixture; found %.',
            (SELECT count(*) FROM e3_stage_dispense);
    END IF;
END $$;

-- All eligible inputs have now been mapped and checked.
DROP TABLE IF EXISTS curated.fact_encounter, curated.fact_lab_result,
                     curated.fact_dispense CASCADE;

CREATE TABLE curated.fact_encounter (
    encounter_key integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    encounter_id text NOT NULL UNIQUE,
    patient_key integer NOT NULL REFERENCES curated.dim_patient(patient_key),
    date_key integer NOT NULL REFERENCES curated.dim_date(date_key),
    clinic_key integer NOT NULL REFERENCES curated.dim_clinic(clinic_key),
    encounter_type text,
    diagnosis_code text,
    medication_review_flag boolean,
    care_plan_flag boolean
);
COMMENT ON TABLE curated.fact_encounter IS 'One GP encounter for a LINKED golden patient.';

INSERT INTO curated.fact_encounter (encounter_id, patient_key, date_key, clinic_key, encounter_type, diagnosis_code, medication_review_flag, care_plan_flag)
SELECT encounter_id, patient_key, date_key, clinic_key, encounter_type, diagnosis_code, medication_review_flag, care_plan_flag FROM e3_stage_encounter
ORDER BY encounter_id;

CREATE TABLE curated.fact_lab_result (
    lab_result_key integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    message_id text NOT NULL UNIQUE,
    observation_id text NOT NULL,
    patient_key integer NOT NULL REFERENCES curated.dim_patient(patient_key),
    collected_date_key integer NOT NULL REFERENCES curated.dim_date(date_key),
    reported_date_key integer NOT NULL REFERENCES curated.dim_date(date_key),
    lab_key integer NOT NULL REFERENCES curated.dim_lab(lab_key),
    test_key integer NOT NULL REFERENCES curated.dim_test(test_key),
    hba1c_mmol_mol numeric(6,1) NOT NULL,
    result_returned_flag boolean NOT NULL
);
COMMENT ON TABLE curated.fact_lab_result IS 'One VALID laboratory message for a LINKED golden patient; mmol/mol and Sydney dates are preserved from CLEANSED.';

INSERT INTO curated.fact_lab_result (message_id, observation_id, patient_key, collected_date_key, reported_date_key, lab_key, test_key, hba1c_mmol_mol, result_returned_flag)
SELECT message_id, observation_id, patient_key, collected_date_key, reported_date_key, lab_key, test_key, hba1c_mmol_mol, result_returned_flag FROM e3_stage_lab_result
ORDER BY message_id;

CREATE TABLE curated.fact_dispense (
    dispense_key integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    dispense_id text NOT NULL UNIQUE,
    patient_key integer NOT NULL REFERENCES curated.dim_patient(patient_key),
    date_key integer NOT NULL REFERENCES curated.dim_date(date_key),
    pharmacy_key integer NOT NULL REFERENCES curated.dim_pharmacy(pharmacy_key),
    medication_key integer NOT NULL REFERENCES curated.dim_medication(medication_key),
    quantity integer,
    days_supply integer
);
COMMENT ON TABLE curated.fact_dispense IS 'One dispensing event for a LINKED golden patient; quantity and days_supply are preserved.';

INSERT INTO curated.fact_dispense (dispense_id, patient_key, date_key, pharmacy_key, medication_key, quantity, days_supply)
SELECT dispense_id, patient_key, date_key, pharmacy_key, medication_key, quantity, days_supply FROM e3_stage_dispense
ORDER BY dispense_id;

COMMENT ON COLUMN curated.fact_lab_result.result_returned_flag
IS 'True exactly when cleansed.lab_result.returned_at is not null; the 7-day grace rule belongs in UC4.';

-- Ordered inserts keep keys stable when rebuilding the same fixture.
-- PK, UNIQUE, NOT NULL and all 12 fact-to-dimension FKs are enforced before commit.
COMMIT;

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
