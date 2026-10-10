-- File:          04_cleansed_standardise.sql
-- Package/owner: D - Yutong Geng
-- Purpose:       Part 1: build cleansed.patient_record, one standardised
--                row per source patient record across GP, LAB and PHARM
--                (48 rows). Part 2: build cleansed.lab_result (one row per
--                LAB message, with dq_status), cleansed.encounter,
--                cleansed.dispense (typed copies), and cleansed.dq_issue
--                (one row per data-quality problem found).
-- Reads:         raw.gp_patient, raw.lab_patient, raw.pharm_patient,
--                raw.lab_observation, raw.lab_delivery, raw.gp_encounter,
--                raw.pharm_dispense, reporting.rule_parameter.
-- Writes:        cleansed.patient_record, cleansed.lab_result,
--                cleansed.encounter, cleansed.dispense, cleansed.dq_issue.
-- Design link:   A2 Build Plan v2, section 5.3 (CLEANSED, owner D) and
--                section 6 (data-quality / standardisation rules).
--                Remediation Plan v3, task cards D-1 and D-3.
-- Run after:      00_setup.sql, 01_src_tables.sql, 02_src_data.sql,
--                 02b_src_lab_messages.sql, 03_raw_extract.sql.
-- Re-runnable:    Yes; removes its own objects first (DROP TABLE IF EXISTS
--                for patient_record/lab_result/encounter/dispense; DELETE
--                of its own rows for dq_issue, which other packages may
--                also write to).

BEGIN;

-- Guard: confirm schemas, raw tables and rule_parameter exist.
-- (D-3: switched from src_* to raw.* -- 04 and 05 no longer reference
-- any src_ table anywhere, per the task card's acceptance check.)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata WHERE schema_name = 'cleansed'
    ) THEN
        RAISE EXCEPTION 'The cleansed schema is missing or not accessible.';
    END IF;

    IF to_regclass('raw.gp_patient') IS NULL
       OR to_regclass('raw.lab_patient') IS NULL
       OR to_regclass('raw.pharm_patient') IS NULL
       OR to_regclass('raw.lab_observation') IS NULL
       OR to_regclass('raw.lab_delivery') IS NULL
       OR to_regclass('raw.gp_encounter') IS NULL
       OR to_regclass('raw.pharm_dispense') IS NULL THEN
        RAISE EXCEPTION 'One or more raw tables are missing -- run 03_raw_extract.sql (and 02b_src_lab_messages.sql) first.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reporting.rule_parameter WHERE param_name = 'as_of_date'
    ) THEN
        RAISE EXCEPTION 'reporting.rule_parameter has no as_of_date row.';
    END IF;
END
$$;

-- =======================================================================
-- PART 1: cleansed.patient_record (unchanged logic from D-1, now reading
-- from raw.* instead of src_*).
-- =======================================================================

DROP TABLE IF EXISTS cleansed.patient_record CASCADE;

CREATE TABLE cleansed.patient_record (
    source_system     text NOT NULL,   -- 'GP' / 'LAB' / 'PHARM'
    source_patient_id text NOT NULL,
    given_name         text,            -- first word only, upper case, blank -> NULL
    family_name        text,            -- upper case, blank -> NULL
    dob                 date,
    sex                  char(1),         -- NULL where the source has no sex field
    medicare10           text,            -- exactly 10 digits, or NULL otherwise
    postcode             text,            -- blank -> NULL; NULL where source has no field
    PRIMARY KEY (source_system, source_patient_id)
);

COMMENT ON TABLE cleansed.patient_record
IS 'One standardised row per source patient record (GP/LAB/PHARM), per Build Plan v2 section 5.3 and Remediation Plan v3 cards D-1/D-3.';

-- ---------------------------------------------------------------------
-- GP: first_name/last_name already split; dob already a DATE (no century
-- issue). given_name takes only the first word (D-1 fix #3), and blank
-- given_name/family_name/postcode become NULL, not empty text (D-1 fix
-- #4). Medicare: keep digits before '/', keep the result only if it is
-- exactly 10 digits, else NULL (D-1 fix #2) -- applied uniformly even
-- though GP's source format has no '/' suffix.
-- ---------------------------------------------------------------------
INSERT INTO cleansed.patient_record
    (source_system, source_patient_id, given_name, family_name,
     dob, sex, medicare10, postcode)
SELECT
    'GP',
    gp_patient_id,
    NULLIF(UPPER(TRIM(SPLIT_PART(TRIM(first_name), ' ', 1))), ''),
    NULLIF(UPPER(TRIM(last_name)), ''),
    dob,
    UPPER(TRIM(sex)),
    CASE
        WHEN LENGTH(REGEXP_REPLACE(SPLIT_PART(medicare_number, '/', 1), '\D', '', 'g')) = 10
        THEN REGEXP_REPLACE(SPLIT_PART(medicare_number, '/', 1), '\D', '', 'g')
        ELSE NULL
    END,
    NULLIF(TRIM(postcode), '')
FROM raw.gp_patient;

-- ---------------------------------------------------------------------
-- LAB: patient_name arrives combined, e.g. 'SMITH, Thomas J' -- family
-- name before the comma, given name the first word after it. dob arrives
-- as text DD/MM/YYYY (four-digit year, no century issue); a blank dob
-- text becomes NULL before parsing (D-1 fix #1). Medicare keeps digits
-- before '/', only kept if exactly 10 digits (D-1 fix #2).
-- ---------------------------------------------------------------------
INSERT INTO cleansed.patient_record
    (source_system, source_patient_id, given_name, family_name,
     dob, sex, medicare10, postcode)
SELECT
    'LAB',
    lab_patient_id,
    NULLIF(UPPER(TRIM(SPLIT_PART(TRIM(SPLIT_PART(patient_name, ',', 2)), ' ', 1))), ''),
    NULLIF(UPPER(TRIM(SPLIT_PART(patient_name, ',', 1))), ''),
    CASE
        WHEN NULLIF(TRIM(dob), '') IS NULL THEN NULL
        ELSE TO_DATE(TRIM(dob), 'DD/MM/YYYY')
    END,
    UPPER(TRIM(sex)),
    CASE
        WHEN LENGTH(REGEXP_REPLACE(SPLIT_PART(medicare_number, '/', 1), '\D', '', 'g')) = 10
        THEN REGEXP_REPLACE(SPLIT_PART(medicare_number, '/', 1), '\D', '', 'g')
        ELSE NULL
    END,
    NULL
FROM raw.lab_patient;

-- ---------------------------------------------------------------------
-- PHARM: given_name/surname already split (given_name may be only an
-- initial, e.g. 'T' -- unchanged, still one word). date_of_birth arrives
-- as text DD-Mon-YY. Century rule (D-1 fix #1): parse assuming the
-- current century first (20yy), then if that date is AFTER the
-- as_of_date (read from reporting.rule_parameter, not hard-coded),
-- subtract 100 years. A blank date_of_birth becomes NULL before parsing.
-- Medicare: same rule as GP/LAB -- split on '/' first, then strip to
-- digits, kept only if exactly 10 digits.
-- ---------------------------------------------------------------------
INSERT INTO cleansed.patient_record
    (source_system, source_patient_id, given_name, family_name,
     dob, sex, medicare10, postcode)
WITH as_of AS (
    SELECT param_value::date AS as_of_date
    FROM reporting.rule_parameter
    WHERE param_name = 'as_of_date'
),
parsed_dob AS (
    SELECT
        pharmacy_patient_id,
        given_name,
        surname,
        medicare_number,
        NULLIF(TRIM(date_of_birth), '') AS dob_text
    FROM raw.pharm_patient
),
dob_parts AS (
    SELECT
        pharmacy_patient_id, given_name, surname, medicare_number, dob_text,
        CASE WHEN dob_text IS NULL THEN NULL
             ELSE SPLIT_PART(dob_text, '-', 1)::int END AS dob_day,
        CASE WHEN dob_text IS NULL THEN NULL
             ELSE SPLIT_PART(dob_text, '-', 2) END AS dob_mon_abbr,
        CASE WHEN dob_text IS NULL THEN NULL
             ELSE SPLIT_PART(dob_text, '-', 3)::int END AS dob_yy
    FROM parsed_dob
),
dob_resolved AS (
    SELECT
        pharmacy_patient_id, given_name, surname, medicare_number,
        CASE
            WHEN dob_text IS NULL THEN NULL
            ELSE MAKE_DATE(
                2000 + dob_yy,
                EXTRACT(MONTH FROM TO_DATE(dob_mon_abbr, 'Mon'))::int,
                dob_day
            )
        END AS dob_in_2000s
    FROM dob_parts
)
SELECT
    'PHARM',
    r.pharmacy_patient_id,
    NULLIF(UPPER(TRIM(SPLIT_PART(TRIM(r.given_name), ' ', 1))), ''),
    NULLIF(UPPER(TRIM(r.surname)), ''),
    CASE
        WHEN r.dob_in_2000s IS NULL THEN NULL
        WHEN r.dob_in_2000s > a.as_of_date THEN r.dob_in_2000s - INTERVAL '100 years'
        ELSE r.dob_in_2000s
    END::date,
    NULL,
    CASE
        WHEN LENGTH(REGEXP_REPLACE(SPLIT_PART(r.medicare_number, '/', 1), '\D', '', 'g')) = 10
        THEN REGEXP_REPLACE(SPLIT_PART(r.medicare_number, '/', 1), '\D', '', 'g')
        ELSE NULL
    END,
    NULL
FROM dob_resolved r
CROSS JOIN as_of a;

-- =======================================================================
-- PART 2 (D-3): lab_result (with dq_status), encounter, dispense,
-- dq_issue.
-- =======================================================================

-- ---------------------------------------------------------------------
-- cleansed.lab_result: one row per LAB message (36 rows). Pulled out of
-- raw.lab_observation.fhir_json (a FHIR Observation resource, shape
-- confirmed against live data on 2026-10-08):
--   {"id": "OBS-...", "code": {"coding": [{"code": "<LOINC>", ...}]},
--    "issued": "...+10:00", "status": "final",
--    "subject": {"reference": "Patient/..."}, "resourceType": "Observation",
--    "valueQuantity": {"unit": "...", "value": <number>},
--    "effectiveDateTime": "...+10:00"}
-- Dates: ((fhir_json ->> 'effectiveDateTime')::timestamptz AT TIME ZONE
-- 'Australia/Sydney')::date (issued the same way) -- the server runs in
-- UTC, so casting straight to ::date without the AT TIME ZONE conversion
-- would read the Sydney morning as the previous UTC day and collected_date
-- would be one day early.
-- unit_as_received keeps the JSON value exactly as received, including an
-- empty string (confirmed on OBS-0022) -- the D-1 "blank -> NULL" rule is
-- only for names and postcode, never for this column.
-- % -> mmol/mol = (value - 2.15) * 10.929, rounded to 1 decimal.
-- dq_status, first match wins:
--   1. DUPLICATE: a later message (by message_id) reusing an Observation
--      id already seen (confirmed: MSG-0031/MSG-0032 both carry OBS-0031,
--      MSG-0032 is the duplicate).
--   2. REJECTED_UNIT: LOINC 59261-8 with a unit other than mmol/mol, or
--      LOINC 4548-4 with a unit other than % (including blank) --
--      hba1c_mmol_mol is NULL for these rows.
--   3. FUTURE_DATE: collected_date after as_of_date (from
--      reporting.rule_parameter, not hard-coded).
--   4. else VALID.
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS cleansed.lab_result CASCADE;

CREATE TABLE cleansed.lab_result (
    message_id            text PRIMARY KEY,
    lab_id                  integer,
    lab_patient_id           text,
    observation_id            text,
    status                      text,
    loinc_code                   text,
    value_as_received             text,    -- kept exactly as received, as text
    unit_as_received               text,    -- kept exactly as received, blanks stay blank
    hba1c_mmol_mol                  numeric(6,1),  -- NULL when dq_status = REJECTED_UNIT
    collected_date                    date,
    reported_date                      date,
    returned_to_clinic_id                integer,
    returned_at                           timestamptz,
    dq_status                              text NOT NULL  -- VALID / DUPLICATE / REJECTED_UNIT / FUTURE_DATE
);

COMMENT ON TABLE cleansed.lab_result
IS 'One row per LAB message with standardised fields and a dq_status, per Remediation Plan v3 card D-3.';

INSERT INTO cleansed.lab_result
    (message_id, lab_id, lab_patient_id, observation_id, status, loinc_code,
     value_as_received, unit_as_received, hba1c_mmol_mol,
     collected_date, reported_date, returned_to_clinic_id, returned_at, dq_status)
WITH as_of AS (
    SELECT param_value::date AS as_of_date
    FROM reporting.rule_parameter
    WHERE param_name = 'as_of_date'
),
parsed AS (
    SELECT
        lo.message_id,
        lo.lab_id,
        lo.lab_patient_id,
        lo.fhir_json ->> 'id' AS observation_id,
        lo.fhir_json ->> 'status' AS status,
        lo.fhir_json -> 'code' -> 'coding' -> 0 ->> 'code' AS loinc_code,
        lo.fhir_json -> 'valueQuantity' ->> 'value' AS value_as_received,
        COALESCE(lo.fhir_json -> 'valueQuantity' ->> 'unit', '') AS unit_as_received,
        ((lo.fhir_json ->> 'effectiveDateTime')::timestamptz AT TIME ZONE 'Australia/Sydney')::date AS collected_date,
        ((lo.fhir_json ->> 'issued')::timestamptz AT TIME ZONE 'Australia/Sydney')::date AS reported_date,
        ld.clinic_id AS returned_to_clinic_id,
        ld.delivered_at AS returned_at,
        ROW_NUMBER() OVER (
            PARTITION BY lo.fhir_json ->> 'id' ORDER BY lo.message_id
        ) AS dup_rank
    FROM raw.lab_observation lo
    LEFT JOIN raw.lab_delivery ld ON ld.message_id = lo.message_id
),
classified AS (
    SELECT
        p.*,
        CASE
            WHEN p.dup_rank > 1 THEN 'DUPLICATE'
            WHEN p.loinc_code = '59261-8' AND p.unit_as_received <> 'mmol/mol' THEN 'REJECTED_UNIT'
            WHEN p.loinc_code = '4548-4' AND p.unit_as_received <> '%' THEN 'REJECTED_UNIT'
            WHEN p.collected_date > a.as_of_date THEN 'FUTURE_DATE'
            ELSE 'VALID'
        END AS dq_status
    FROM parsed p
    CROSS JOIN as_of a
)
SELECT
    message_id, lab_id, lab_patient_id, observation_id, status, loinc_code,
    value_as_received, unit_as_received,
    CASE
        WHEN dq_status = 'REJECTED_UNIT' THEN NULL
        WHEN loinc_code = '59261-8' AND unit_as_received = 'mmol/mol'
            THEN ROUND(value_as_received::numeric, 1)
        WHEN loinc_code = '4548-4' AND unit_as_received = '%'
            THEN ROUND((value_as_received::numeric - 2.15) * 10.929, 1)
        ELSE NULL
    END AS hba1c_mmol_mol,
    collected_date, reported_date, returned_to_clinic_id, returned_at, dq_status
FROM classified;

-- ---------------------------------------------------------------------
-- cleansed.encounter / cleansed.dispense: typed copies of the raw tables
-- (already correctly typed by 03_raw_extract.sql), lineage columns
-- dropped.
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS cleansed.encounter CASCADE;

CREATE TABLE cleansed.encounter AS
SELECT
    encounter_id, gp_patient_id, clinic_id, encounter_date, encounter_type,
    diagnosis_code, medication_review_flag, care_plan_flag
FROM raw.gp_encounter;

ALTER TABLE cleansed.encounter ADD PRIMARY KEY (encounter_id);

COMMENT ON TABLE cleansed.encounter
IS 'Typed copy of raw.gp_encounter, lineage columns dropped. Per Remediation Plan v3 card D-3.';

DROP TABLE IF EXISTS cleansed.dispense CASCADE;

CREATE TABLE cleansed.dispense AS
SELECT
    dispense_id, pharmacy_patient_id, pharmacy_id, pbs_item_code,
    dispensed_date, quantity, days_supply
FROM raw.pharm_dispense;

ALTER TABLE cleansed.dispense ADD PRIMARY KEY (dispense_id);

COMMENT ON TABLE cleansed.dispense
IS 'Typed copy of raw.pharm_dispense, lineage columns dropped. Per Remediation Plan v3 card D-3.';

-- ---------------------------------------------------------------------
-- cleansed.dq_issue: one row per data-quality problem found, across any
-- package's cleansing script -- so this script only owns and refreshes
-- the rows it itself produced (table_name = 'lab_result'), and creates
-- the table only if another package hasn't already.
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS cleansed.dq_issue (
    issue_id    bigserial PRIMARY KEY,
    table_name   text NOT NULL,
    record_id     text NOT NULL,
    rule           text NOT NULL,
    detail          text
);

COMMENT ON TABLE cleansed.dq_issue
IS 'One row per data-quality problem found by any CLEANSED-layer script. Per Remediation Plan v3 card D-3.';

DELETE FROM cleansed.dq_issue WHERE table_name = 'lab_result';

INSERT INTO cleansed.dq_issue (table_name, record_id, rule, detail)
SELECT
    'lab_result',
    message_id,
    dq_status,
    CASE dq_status
        WHEN 'DUPLICATE' THEN 'duplicate Observation id ' || observation_id
        WHEN 'REJECTED_UNIT' THEN 'unit "' || unit_as_received || '" invalid for LOINC ' || loinc_code
        WHEN 'FUTURE_DATE' THEN 'collected_date ' || collected_date || ' is after as_of_date'
    END
FROM cleansed.lab_result
WHERE dq_status <> 'VALID';

COMMIT;

-- ===================== Acceptance checks (cards D-1 + D-3) =====================

-- --- D-1: cleansed.patient_record ---

-- 4-row spot check, unchanged:
-- GP-0001  THOMAS SMITH  1962-05-14  2123456701
-- PATH0001 THOMAS SMITH  1962-05-14  2123456701
-- PH-1001  T      SMITH  1962-05-14  2123456701
-- PH-1014  E      LEWIS  1949-01-15  NULL
SELECT source_system, source_patient_id, given_name, family_name, dob, medicare10
FROM cleansed.patient_record
WHERE source_patient_id IN ('GP-0001', 'PATH0001', 'PH-1001', 'PH-1014')
ORDER BY source_patient_id;

-- Total should be 48 (GP 18 / LAB 17 / PHARM 13).
SELECT source_system, count(*) AS row_count
FROM cleansed.patient_record
GROUP BY source_system
ORDER BY source_system;

-- No medicare10 of the wrong length should survive.
SELECT count(*) AS wrong_length_count
FROM cleansed.patient_record
WHERE length(medicare10) <> 10;
-- Expect 0.

SELECT source_patient_id, medicare10 FROM cleansed.patient_record WHERE source_patient_id = 'PH-1006';
-- Expect 2567890145.
SELECT source_patient_id, medicare10 FROM cleansed.patient_record WHERE source_patient_id = 'PATH0004';
-- Expect 5456789034.

-- --- D-3: cleansed.lab_result / encounter / dispense ---

-- Expect VALID 33, DUPLICATE 1 (MSG-0032), REJECTED_UNIT 1 (OBS-0022), FUTURE_DATE 1 (OBS-0025).
SELECT dq_status, count(*) AS n
FROM cleansed.lab_result
GROUP BY dq_status
ORDER BY dq_status;

SELECT message_id, observation_id, dq_status FROM cleansed.lab_result WHERE dq_status <> 'VALID' ORDER BY dq_status;

-- Expect collected 2025-10-10, reported 2025-10-11.
SELECT message_id, observation_id, collected_date, reported_date
FROM cleansed.lab_result WHERE observation_id = 'OBS-0001';

-- Expect 28.
SELECT count(*) AS encounter_count FROM cleansed.encounter;

-- Expect 68.
SELECT count(*) AS dispense_count FROM cleansed.dispense;

-- Should return 0 rows (no "src_" references anywhere in this script).
-- (Run this by eye against the script text, not as SQL -- a text check,
-- not a query.)
