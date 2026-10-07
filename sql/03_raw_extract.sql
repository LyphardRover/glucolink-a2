-- File:          03_raw_extract.sql
-- Package/owner: C - Quang Tien Le
-- Purpose:       Copy all 11 sources unchanged to RAW with run-level lineage.
-- Reads:         The 11 src_gp/src_lab/src_pharm tables listed below.
-- Writes:        Only the 11 owned raw tables and one audit.pipeline_run row.
-- Design link:   Build Plan v2 sections 5.2/5.6; Task Cards v3 C-3.
-- Run after:     00 -> 01 -> 02 -> 02b; B must finish the 36 messages/34 deliveries.
-- Re-runnable:   Yes; full RAW rebuild/reload, one new run log per successful run.
-- Assistance:    Prepared with AI assistance; review and declare in the log.
--
-- Coordinate shared reruns: DROP CASCADE can remove dependent views/FKs.
-- Do not run source resets or 02b concurrently with this extract.
-- Run the entire file in one session. On any error, stop and ROLLBACK.
-- A failed transaction restores the prior RAW tables and rolls back its run row;
-- this script does not persist a FAILED row outside the transaction.

-- One consistent source snapshot; rebuild, copy and audit update commit together.
BEGIN ISOLATION LEVEL REPEATABLE READ;

-- Reset only C's 11 named RAW tables, as required by task card C-3.
DROP TABLE IF EXISTS raw.gp_clinic CASCADE;
DROP TABLE IF EXISTS raw.gp_patient CASCADE;
DROP TABLE IF EXISTS raw.gp_encounter CASCADE;
DROP TABLE IF EXISTS raw.lab_laboratory CASCADE;
DROP TABLE IF EXISTS raw.lab_patient CASCADE;
DROP TABLE IF EXISTS raw.lab_observation CASCADE;
DROP TABLE IF EXISTS raw.lab_delivery CASCADE;
DROP TABLE IF EXISTS raw.pharm_pharmacy CASCADE;
DROP TABLE IF EXISTS raw.pharm_medication CASCADE;
DROP TABLE IF EXISTS raw.pharm_patient CASCADE;
DROP TABLE IF EXISTS raw.pharm_dispense CASCADE;

-- raw.gp_clinic: same source columns/types, no keys, defaults or constraints.
CREATE TABLE raw.gp_clinic (
    clinic_id INTEGER,
    clinic_name TEXT,
    suburb TEXT,
    postcode TEXT,
    _source_system TEXT,
    _source_table TEXT,
    _pipeline_run_id BIGINT,
    _loaded_at TIMESTAMPTZ
);
COMMENT ON TABLE raw.gp_clinic IS 'Unmodified copy of src_gp.clinic with extraction lineage.';

-- raw.gp_patient: same source columns/types, no keys, defaults or constraints.
CREATE TABLE raw.gp_patient (
    gp_patient_id TEXT,
    first_name TEXT,
    last_name TEXT,
    dob DATE,
    sex CHAR(1),
    postcode TEXT,
    medicare_number TEXT,
    clinic_id INTEGER,
    enrolment_date DATE,
    _source_system TEXT,
    _source_table TEXT,
    _pipeline_run_id BIGINT,
    _loaded_at TIMESTAMPTZ
);
COMMENT ON TABLE raw.gp_patient IS 'Unmodified copy of src_gp.gp_patient with extraction lineage.';

-- raw.gp_encounter: same source columns/types, no keys, defaults or constraints.
CREATE TABLE raw.gp_encounter (
    encounter_id TEXT,
    gp_patient_id TEXT,
    clinic_id INTEGER,
    encounter_date DATE,
    encounter_type TEXT,
    diagnosis_code TEXT,
    medication_review_flag BOOLEAN,
    care_plan_flag BOOLEAN,
    _source_system TEXT,
    _source_table TEXT,
    _pipeline_run_id BIGINT,
    _loaded_at TIMESTAMPTZ
);
COMMENT ON TABLE raw.gp_encounter IS 'Unmodified copy of src_gp.encounter with extraction lineage.';

-- raw.lab_laboratory: same source columns/types, no keys, defaults or constraints.
CREATE TABLE raw.lab_laboratory (
    lab_id INTEGER,
    lab_name TEXT,
    reporting_unit TEXT,
    _source_system TEXT,
    _source_table TEXT,
    _pipeline_run_id BIGINT,
    _loaded_at TIMESTAMPTZ
);
COMMENT ON TABLE raw.lab_laboratory IS 'Unmodified copy of src_lab.laboratory with extraction lineage.';

-- raw.lab_patient: same source columns/types, no keys, defaults or constraints.
CREATE TABLE raw.lab_patient (
    lab_patient_id TEXT,
    patient_name TEXT,
    dob TEXT,
    sex CHAR(1),
    medicare_number TEXT,
    _source_system TEXT,
    _source_table TEXT,
    _pipeline_run_id BIGINT,
    _loaded_at TIMESTAMPTZ
);
COMMENT ON TABLE raw.lab_patient IS 'Unmodified copy of src_lab.lab_patient with extraction lineage.';

-- raw.lab_observation: same source columns/types, no keys, defaults or constraints.
CREATE TABLE raw.lab_observation (
    message_id TEXT,
    lab_id INTEGER,
    lab_patient_id TEXT,
    received_at TIMESTAMPTZ,
    fhir_json JSONB,
    _source_system TEXT,
    _source_table TEXT,
    _pipeline_run_id BIGINT,
    _loaded_at TIMESTAMPTZ
);
COMMENT ON TABLE raw.lab_observation IS 'Unmodified copy of src_lab.observation_message with extraction lineage.';

-- raw.lab_delivery: same source columns/types, no keys, defaults or constraints.
CREATE TABLE raw.lab_delivery (
    delivery_id TEXT,
    message_id TEXT,
    clinic_id INTEGER,
    delivered_at TIMESTAMPTZ,
    _source_system TEXT,
    _source_table TEXT,
    _pipeline_run_id BIGINT,
    _loaded_at TIMESTAMPTZ
);
COMMENT ON TABLE raw.lab_delivery IS 'Unmodified copy of src_lab.result_delivery with extraction lineage.';

-- raw.pharm_pharmacy: same source columns/types, no keys, defaults or constraints.
CREATE TABLE raw.pharm_pharmacy (
    pharmacy_id INTEGER,
    pharmacy_name TEXT,
    suburb TEXT,
    _source_system TEXT,
    _source_table TEXT,
    _pipeline_run_id BIGINT,
    _loaded_at TIMESTAMPTZ
);
COMMENT ON TABLE raw.pharm_pharmacy IS 'Unmodified copy of src_pharm.pharmacy with extraction lineage.';

-- raw.pharm_medication: same source columns/types, no keys, defaults or constraints.
CREATE TABLE raw.pharm_medication (
    pbs_item_code TEXT,
    drug_name TEXT,
    strength TEXT,
    pack_size INTEGER,
    typical_daily_dose NUMERIC,
    drug_class TEXT,
    _source_system TEXT,
    _source_table TEXT,
    _pipeline_run_id BIGINT,
    _loaded_at TIMESTAMPTZ
);
COMMENT ON TABLE raw.pharm_medication IS 'Unmodified copy of src_pharm.medication with extraction lineage.';

-- raw.pharm_patient: same source columns/types, no keys, defaults or constraints.
CREATE TABLE raw.pharm_patient (
    pharmacy_patient_id TEXT,
    given_name TEXT,
    surname TEXT,
    date_of_birth TEXT,
    medicare_number TEXT,
    pharmacy_id INTEGER,
    _source_system TEXT,
    _source_table TEXT,
    _pipeline_run_id BIGINT,
    _loaded_at TIMESTAMPTZ
);
COMMENT ON TABLE raw.pharm_patient IS 'Unmodified copy of src_pharm.pharmacy_patient with extraction lineage.';

-- raw.pharm_dispense: same source columns/types, no keys, defaults or constraints.
CREATE TABLE raw.pharm_dispense (
    dispense_id TEXT,
    pharmacy_patient_id TEXT,
    pharmacy_id INTEGER,
    pbs_item_code TEXT,
    dispensed_date DATE,
    quantity INTEGER,
    days_supply INTEGER,
    _source_system TEXT,
    _source_table TEXT,
    _pipeline_run_id BIGINT,
    _loaded_at TIMESTAMPTZ
);
COMMENT ON TABLE raw.pharm_dispense IS 'Unmodified copy of src_pharm.dispense with extraction lineage.';

-- Keep the run id in a local PL/pgSQL variable; no helper tables are needed.
DO $raw_extract$
DECLARE
    v_run_id audit.pipeline_run.run_id%TYPE;
    v_rows_read BIGINT;
    v_rows_loaded BIGINT := 0;
    v_batch_rows BIGINT;
BEGIN
    -- B's defaults supply run_id, started_at and RUNNING.
    INSERT INTO audit.pipeline_run (pipeline_name)
    VALUES ('03_raw_extract')
    RETURNING run_id INTO v_run_id;

    -- Count all source rows within the same repeatable-read snapshot.
    SELECT (SELECT COUNT(*) FROM src_gp.clinic) +
           (SELECT COUNT(*) FROM src_gp.gp_patient) +
           (SELECT COUNT(*) FROM src_gp.encounter) +
           (SELECT COUNT(*) FROM src_lab.laboratory) +
           (SELECT COUNT(*) FROM src_lab.lab_patient) +
           (SELECT COUNT(*) FROM src_lab.observation_message) +
           (SELECT COUNT(*) FROM src_lab.result_delivery) +
           (SELECT COUNT(*) FROM src_pharm.pharmacy) +
           (SELECT COUNT(*) FROM src_pharm.medication) +
           (SELECT COUNT(*) FROM src_pharm.pharmacy_patient) +
           (SELECT COUNT(*) FROM src_pharm.dispense) INTO v_rows_read;

    -- Explicit full reload, including when source tables happen to be empty.
    TRUNCATE TABLE raw.gp_clinic, raw.gp_patient, raw.gp_encounter, raw.lab_laboratory, raw.lab_patient, raw.lab_observation, raw.lab_delivery, raw.pharm_pharmacy, raw.pharm_medication, raw.pharm_patient, raw.pharm_dispense;

    -- Copy src_gp.clinic; no trimming, casting, deduplication or JSON changes.
    INSERT INTO raw.gp_clinic
        (clinic_id, clinic_name, suburb, postcode, _source_system, _source_table, _pipeline_run_id, _loaded_at)
    SELECT clinic_id, clinic_name, suburb, postcode, 'GP', 'src_gp.clinic', v_run_id, now()
    FROM src_gp.clinic;
    GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
    v_rows_loaded := v_rows_loaded + v_batch_rows;

    -- Copy src_gp.gp_patient; no trimming, casting, deduplication or JSON changes.
    INSERT INTO raw.gp_patient
        (gp_patient_id, first_name, last_name, dob, sex, postcode, medicare_number, clinic_id, enrolment_date, _source_system, _source_table, _pipeline_run_id, _loaded_at)
    SELECT gp_patient_id, first_name, last_name, dob, sex, postcode, medicare_number, clinic_id, enrolment_date, 'GP', 'src_gp.gp_patient', v_run_id, now()
    FROM src_gp.gp_patient;
    GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
    v_rows_loaded := v_rows_loaded + v_batch_rows;

    -- Copy src_gp.encounter; no trimming, casting, deduplication or JSON changes.
    INSERT INTO raw.gp_encounter
        (encounter_id, gp_patient_id, clinic_id, encounter_date, encounter_type, diagnosis_code, medication_review_flag, care_plan_flag, _source_system, _source_table, _pipeline_run_id, _loaded_at)
    SELECT encounter_id, gp_patient_id, clinic_id, encounter_date, encounter_type, diagnosis_code, medication_review_flag, care_plan_flag, 'GP', 'src_gp.encounter', v_run_id, now()
    FROM src_gp.encounter;
    GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
    v_rows_loaded := v_rows_loaded + v_batch_rows;

    -- Copy src_lab.laboratory; no trimming, casting, deduplication or JSON changes.
    INSERT INTO raw.lab_laboratory
        (lab_id, lab_name, reporting_unit, _source_system, _source_table, _pipeline_run_id, _loaded_at)
    SELECT lab_id, lab_name, reporting_unit, 'LAB', 'src_lab.laboratory', v_run_id, now()
    FROM src_lab.laboratory;
    GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
    v_rows_loaded := v_rows_loaded + v_batch_rows;

    -- Copy src_lab.lab_patient; no trimming, casting, deduplication or JSON changes.
    INSERT INTO raw.lab_patient
        (lab_patient_id, patient_name, dob, sex, medicare_number, _source_system, _source_table, _pipeline_run_id, _loaded_at)
    SELECT lab_patient_id, patient_name, dob, sex, medicare_number, 'LAB', 'src_lab.lab_patient', v_run_id, now()
    FROM src_lab.lab_patient;
    GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
    v_rows_loaded := v_rows_loaded + v_batch_rows;

    -- Copy src_lab.observation_message; no trimming, casting, deduplication or JSON changes.
    INSERT INTO raw.lab_observation
        (message_id, lab_id, lab_patient_id, received_at, fhir_json, _source_system, _source_table, _pipeline_run_id, _loaded_at)
    SELECT message_id, lab_id, lab_patient_id, received_at, fhir_json, 'LAB', 'src_lab.observation_message', v_run_id, now()
    FROM src_lab.observation_message;
    GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
    v_rows_loaded := v_rows_loaded + v_batch_rows;

    -- Copy src_lab.result_delivery; no trimming, casting, deduplication or JSON changes.
    INSERT INTO raw.lab_delivery
        (delivery_id, message_id, clinic_id, delivered_at, _source_system, _source_table, _pipeline_run_id, _loaded_at)
    SELECT delivery_id, message_id, clinic_id, delivered_at, 'LAB', 'src_lab.result_delivery', v_run_id, now()
    FROM src_lab.result_delivery;
    GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
    v_rows_loaded := v_rows_loaded + v_batch_rows;

    -- Copy src_pharm.pharmacy; no trimming, casting, deduplication or JSON changes.
    INSERT INTO raw.pharm_pharmacy
        (pharmacy_id, pharmacy_name, suburb, _source_system, _source_table, _pipeline_run_id, _loaded_at)
    SELECT pharmacy_id, pharmacy_name, suburb, 'PHARM', 'src_pharm.pharmacy', v_run_id, now()
    FROM src_pharm.pharmacy;
    GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
    v_rows_loaded := v_rows_loaded + v_batch_rows;

    -- Copy src_pharm.medication; no trimming, casting, deduplication or JSON changes.
    INSERT INTO raw.pharm_medication
        (pbs_item_code, drug_name, strength, pack_size, typical_daily_dose, drug_class, _source_system, _source_table, _pipeline_run_id, _loaded_at)
    SELECT pbs_item_code, drug_name, strength, pack_size, typical_daily_dose, drug_class, 'PHARM', 'src_pharm.medication', v_run_id, now()
    FROM src_pharm.medication;
    GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
    v_rows_loaded := v_rows_loaded + v_batch_rows;

    -- Copy src_pharm.pharmacy_patient; no trimming, casting, deduplication or JSON changes.
    INSERT INTO raw.pharm_patient
        (pharmacy_patient_id, given_name, surname, date_of_birth, medicare_number, pharmacy_id, _source_system, _source_table, _pipeline_run_id, _loaded_at)
    SELECT pharmacy_patient_id, given_name, surname, date_of_birth, medicare_number, pharmacy_id, 'PHARM', 'src_pharm.pharmacy_patient', v_run_id, now()
    FROM src_pharm.pharmacy_patient;
    GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
    v_rows_loaded := v_rows_loaded + v_batch_rows;

    -- Copy src_pharm.dispense; no trimming, casting, deduplication or JSON changes.
    INSERT INTO raw.pharm_dispense
        (dispense_id, pharmacy_patient_id, pharmacy_id, pbs_item_code, dispensed_date, quantity, days_supply, _source_system, _source_table, _pipeline_run_id, _loaded_at)
    SELECT dispense_id, pharmacy_patient_id, pharmacy_id, pbs_item_code, dispensed_date, quantity, days_supply, 'PHARM', 'src_pharm.dispense', v_run_id, now()
    FROM src_pharm.dispense;
    GET DIAGNOSTICS v_batch_rows = ROW_COUNT;
    v_rows_loaded := v_rows_loaded + v_batch_rows;

    -- Never label a partial copy as successful.
    IF v_rows_read <> v_rows_loaded THEN
        RAISE EXCEPTION 'RAW count mismatch: read %, loaded %', v_rows_read, v_rows_loaded;
    END IF;

    -- Preserve earlier run history and finish only this run.
    UPDATE audit.pipeline_run
    SET status = 'SUCCESS', finished_at = clock_timestamp(),
        rows_read = v_rows_read, rows_loaded = v_rows_loaded,
        rows_rejected = 0, error_message = NULL
    WHERE run_id = v_run_id;
END;
$raw_extract$;

-- Publish the new RAW snapshot and successful run record atomically.
COMMIT;

-- C-3 evidence: all 11 pairs equal; expected total 225 after 02b is loaded.
SELECT current_database() AS database_name, source_table, raw_table,
       source_rows, raw_rows, expected_rows,
       CASE WHEN source_rows = raw_rows AND raw_rows = expected_rows
            THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT 1 AS sort_order, 'src_gp.clinic' AS source_table, 'raw.gp_clinic' AS raw_table,
           (SELECT COUNT(*) FROM src_gp.clinic) AS source_rows,
           (SELECT COUNT(*) FROM raw.gp_clinic) AS raw_rows, 3 AS expected_rows
    UNION ALL
    SELECT 2 AS sort_order, 'src_gp.gp_patient' AS source_table, 'raw.gp_patient' AS raw_table,
           (SELECT COUNT(*) FROM src_gp.gp_patient) AS source_rows,
           (SELECT COUNT(*) FROM raw.gp_patient) AS raw_rows, 18 AS expected_rows
    UNION ALL
    SELECT 3 AS sort_order, 'src_gp.encounter' AS source_table, 'raw.gp_encounter' AS raw_table,
           (SELECT COUNT(*) FROM src_gp.encounter) AS source_rows,
           (SELECT COUNT(*) FROM raw.gp_encounter) AS raw_rows, 28 AS expected_rows
    UNION ALL
    SELECT 4 AS sort_order, 'src_lab.laboratory' AS source_table, 'raw.lab_laboratory' AS raw_table,
           (SELECT COUNT(*) FROM src_lab.laboratory) AS source_rows,
           (SELECT COUNT(*) FROM raw.lab_laboratory) AS raw_rows, 2 AS expected_rows
    UNION ALL
    SELECT 5 AS sort_order, 'src_lab.lab_patient' AS source_table, 'raw.lab_patient' AS raw_table,
           (SELECT COUNT(*) FROM src_lab.lab_patient) AS source_rows,
           (SELECT COUNT(*) FROM raw.lab_patient) AS raw_rows, 17 AS expected_rows
    UNION ALL
    SELECT 6 AS sort_order, 'src_lab.observation_message' AS source_table, 'raw.lab_observation' AS raw_table,
           (SELECT COUNT(*) FROM src_lab.observation_message) AS source_rows,
           (SELECT COUNT(*) FROM raw.lab_observation) AS raw_rows, 36 AS expected_rows
    UNION ALL
    SELECT 7 AS sort_order, 'src_lab.result_delivery' AS source_table, 'raw.lab_delivery' AS raw_table,
           (SELECT COUNT(*) FROM src_lab.result_delivery) AS source_rows,
           (SELECT COUNT(*) FROM raw.lab_delivery) AS raw_rows, 34 AS expected_rows
    UNION ALL
    SELECT 8 AS sort_order, 'src_pharm.pharmacy' AS source_table, 'raw.pharm_pharmacy' AS raw_table,
           (SELECT COUNT(*) FROM src_pharm.pharmacy) AS source_rows,
           (SELECT COUNT(*) FROM raw.pharm_pharmacy) AS raw_rows, 3 AS expected_rows
    UNION ALL
    SELECT 9 AS sort_order, 'src_pharm.medication' AS source_table, 'raw.pharm_medication' AS raw_table,
           (SELECT COUNT(*) FROM src_pharm.medication) AS source_rows,
           (SELECT COUNT(*) FROM raw.pharm_medication) AS raw_rows, 3 AS expected_rows
    UNION ALL
    SELECT 10 AS sort_order, 'src_pharm.pharmacy_patient' AS source_table, 'raw.pharm_patient' AS raw_table,
           (SELECT COUNT(*) FROM src_pharm.pharmacy_patient) AS source_rows,
           (SELECT COUNT(*) FROM raw.pharm_patient) AS raw_rows, 13 AS expected_rows
    UNION ALL
    SELECT 11 AS sort_order, 'src_pharm.dispense' AS source_table, 'raw.pharm_dispense' AS raw_table,
           (SELECT COUNT(*) FROM src_pharm.dispense) AS source_rows,
           (SELECT COUNT(*) FROM raw.pharm_dispense) AS raw_rows, 68 AS expected_rows
) AS counts
ORDER BY sort_order;

-- Latest RAW run: SUCCESS, 225 read/loaded, 0 rejected, finished_at populated.
SELECT run_id, pipeline_name, started_at, finished_at, status,
       rows_read, rows_loaded, rows_rejected, error_message
FROM audit.pipeline_run WHERE pipeline_name = '03_raw_extract'
ORDER BY run_id DESC LIMIT 1;

-- Every row must carry the latest RAW run id and correct source labels.
WITH latest AS (
    SELECT run_id FROM audit.pipeline_run WHERE pipeline_name = '03_raw_extract'
    ORDER BY run_id DESC LIMIT 1
), lineage AS (
    SELECT 'raw.gp_clinic' AS raw_table, _pipeline_run_id, _loaded_at,
           _source_system, _source_table, 'GP' AS expected_system, 'src_gp.clinic' AS expected_table FROM raw.gp_clinic
    UNION ALL
    SELECT 'raw.gp_patient' AS raw_table, _pipeline_run_id, _loaded_at,
           _source_system, _source_table, 'GP' AS expected_system, 'src_gp.gp_patient' AS expected_table FROM raw.gp_patient
    UNION ALL
    SELECT 'raw.gp_encounter' AS raw_table, _pipeline_run_id, _loaded_at,
           _source_system, _source_table, 'GP' AS expected_system, 'src_gp.encounter' AS expected_table FROM raw.gp_encounter
    UNION ALL
    SELECT 'raw.lab_laboratory' AS raw_table, _pipeline_run_id, _loaded_at,
           _source_system, _source_table, 'LAB' AS expected_system, 'src_lab.laboratory' AS expected_table FROM raw.lab_laboratory
    UNION ALL
    SELECT 'raw.lab_patient' AS raw_table, _pipeline_run_id, _loaded_at,
           _source_system, _source_table, 'LAB' AS expected_system, 'src_lab.lab_patient' AS expected_table FROM raw.lab_patient
    UNION ALL
    SELECT 'raw.lab_observation' AS raw_table, _pipeline_run_id, _loaded_at,
           _source_system, _source_table, 'LAB' AS expected_system, 'src_lab.observation_message' AS expected_table FROM raw.lab_observation
    UNION ALL
    SELECT 'raw.lab_delivery' AS raw_table, _pipeline_run_id, _loaded_at,
           _source_system, _source_table, 'LAB' AS expected_system, 'src_lab.result_delivery' AS expected_table FROM raw.lab_delivery
    UNION ALL
    SELECT 'raw.pharm_pharmacy' AS raw_table, _pipeline_run_id, _loaded_at,
           _source_system, _source_table, 'PHARM' AS expected_system, 'src_pharm.pharmacy' AS expected_table FROM raw.pharm_pharmacy
    UNION ALL
    SELECT 'raw.pharm_medication' AS raw_table, _pipeline_run_id, _loaded_at,
           _source_system, _source_table, 'PHARM' AS expected_system, 'src_pharm.medication' AS expected_table FROM raw.pharm_medication
    UNION ALL
    SELECT 'raw.pharm_patient' AS raw_table, _pipeline_run_id, _loaded_at,
           _source_system, _source_table, 'PHARM' AS expected_system, 'src_pharm.pharmacy_patient' AS expected_table FROM raw.pharm_patient
    UNION ALL
    SELECT 'raw.pharm_dispense' AS raw_table, _pipeline_run_id, _loaded_at,
           _source_system, _source_table, 'PHARM' AS expected_system, 'src_pharm.dispense' AS expected_table FROM raw.pharm_dispense
)
SELECT raw_table, COUNT(*) AS rows_checked,
       COUNT(*) FILTER (WHERE _pipeline_run_id IS DISTINCT FROM (SELECT run_id FROM latest)
                         OR _source_system IS DISTINCT FROM expected_system
                         OR _source_table IS DISTINCT FROM expected_table
                         OR _loaded_at IS NULL) AS invalid_lineage_rows
FROM lineage GROUP BY raw_table ORDER BY raw_table;
