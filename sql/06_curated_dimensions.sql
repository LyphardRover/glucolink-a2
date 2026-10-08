-- File:          06_curated_dimensions.sql
-- Package/owner: E - Shuo Ding
-- Purpose:       Rebuild seven dimensions, including the golden patient dimension.
-- Reads:         raw.gp_clinic, raw.lab_laboratory, raw.pharm_pharmacy,
--                raw.pharm_medication, raw.gp_patient,
--                cleansed.patient_master, cleansed.patient_source_link.
-- Writes:        curated.dim_date, dim_clinic, dim_lab, dim_pharmacy,
--                dim_medication, dim_test, dim_patient.
-- Design link:   Build Plan v2 section 5.4; Task Cards v3 E-2; rules v1.2.
-- Run after:     03_raw_extract.sql, 04_cleansed_standardise.sql,
--                05_identity_resolution.sql, following the team's 00-05 run order.
-- Re-runnable:   Yes. Rebuild all seven dimensions in one transaction.
-- Release:       E-2, 8 October 2026; final shared-DB acceptance still required.
-- Assistance:    Prepared with AI assistance; review and record in contribution log.
--
-- After re-running 06, re-run 07 and 08.
-- CASCADE removes dependent views and foreign-key constraints; it does not
-- refresh existing fact rows. Coordinate in Teams and rebuild downstream outputs.
-- Reads teammate inputs without modifying them. No database-name restriction.
-- Run the complete script in one session. On error, stop and run ROLLBACK.

BEGIN;

-- Check the schema, reference tables and expected reference counts before
-- any dimension is dropped. No database-name restriction: supports test builds.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata
        WHERE schema_name = 'curated'
    ) THEN
        RAISE EXCEPTION 'The curated schema is missing or not accessible.';
    END IF;

    IF to_regclass('raw.gp_clinic') IS NULL
       OR to_regclass('raw.lab_laboratory') IS NULL
       OR to_regclass('raw.pharm_pharmacy') IS NULL
       OR to_regclass('raw.pharm_medication') IS NULL THEN
        RAISE EXCEPTION 'RAW reference tables are missing. Ask C to complete 03_raw_extract.sql.';
    END IF;

    IF (SELECT count(*) FROM raw.gp_clinic) <> 3
       OR (SELECT count(*) FROM raw.lab_laboratory) <> 2
       OR (SELECT count(*) FROM raw.pharm_pharmacy) <> 3
       OR (SELECT count(*) FROM raw.pharm_medication) <> 3 THEN
        RAISE EXCEPTION 'Expected reference counts: clinic 3, laboratory 2, pharmacy 3, medication 3.';
    END IF;

    -- Identity outputs and the GP input are required before rebuilding anything.
    IF to_regclass('raw.gp_patient') IS NULL
       OR to_regclass('cleansed.patient_master') IS NULL
       OR to_regclass('cleansed.patient_source_link') IS NULL THEN
        RAISE EXCEPTION 'Missing GP RAW or identity tables: complete 03 and 05 first.';
    END IF;
    IF (SELECT count(*) FROM cleansed.patient_master) <> 17 THEN
        RAISE EXCEPTION 'Expected 17 golden patients from 05 for the A2 fixture.';
    END IF;
    -- RAW has no source constraints: reject ambiguous GP identifiers.
    IF EXISTS (SELECT gp_patient_id FROM raw.gp_patient
               GROUP BY gp_patient_id HAVING count(*) > 1)
       OR EXISTS (SELECT 1 FROM raw.gp_patient WHERE gp_patient_id IS NULL) THEN
        RAISE EXCEPTION 'RAW GP identifiers must be unique and non-null.';
    END IF;
    -- Each master needs a linked GP anchor. Pick its ID BEFORE looking up RAW;
    -- a missing earlier record must not silently fall back to a later clinic.
    IF EXISTS (
        SELECT 1
        FROM cleansed.patient_master m
        LEFT JOIN (
            SELECT patient_id, min(source_patient_id) AS gp_patient_id
            FROM cleansed.patient_source_link
            WHERE source_system = 'GP' AND match_status = 'LINKED'
            GROUP BY patient_id
        ) anchor ON anchor.patient_id = m.patient_id
        LEFT JOIN raw.gp_patient gp ON gp.gp_patient_id = anchor.gp_patient_id
        LEFT JOIN raw.gp_clinic c ON c.clinic_id = gp.clinic_id
        WHERE anchor.gp_patient_id IS NULL OR gp.gp_patient_id IS NULL
           OR c.clinic_id IS NULL
    ) THEN
        RAISE EXCEPTION 'A master has no valid earliest GP/home-clinic mapping. Check 03 and 05.';
    END IF;
END
$$;

-- Reset only E's seven dimensions. No schemas are removed.
-- Remove dependent views / FKs as required by v3; follow with scripts 07 and 08.
DROP TABLE IF EXISTS
    curated.dim_patient,
    curated.dim_test,
    curated.dim_medication,
    curated.dim_pharmacy,
    curated.dim_lab,
    curated.dim_clinic,
    curated.dim_date
CASCADE;

-- Date dimension: one row per day; YYYYMMDD is the primary key.
CREATE TABLE curated.dim_date (
    date_key   integer PRIMARY KEY,
    full_date  date NOT NULL UNIQUE,
    day        integer NOT NULL,
    month      integer NOT NULL,
    month_name text NOT NULL,
    quarter    integer NOT NULL,
    year       integer NOT NULL
);
COMMENT ON TABLE curated.dim_date
IS 'One calendar day from 2025-01-01 through 2026-12-31; shared date dimension.';

-- Integer day offsets avoid timestamp and time-zone changes to the range.
WITH calendar AS (
    SELECT DATE '2025-01-01' + day_offset AS full_date
    FROM generate_series(
        0, DATE '2026-12-31' - DATE '2025-01-01'
    ) AS offsets(day_offset)
)
INSERT INTO curated.dim_date
    (date_key, full_date, day, month, month_name, quarter, year)
SELECT to_char(full_date, 'YYYYMMDD')::integer,
       full_date,
       extract(day FROM full_date)::integer,
       extract(month FROM full_date)::integer,
       to_char(full_date, 'FMMonth'),
       extract(quarter FROM full_date)::integer,
       extract(year FROM full_date)::integer
FROM calendar
ORDER BY full_date;

-- Clinic dimension: warehouse key plus C's source ID and descriptive columns.
CREATE TABLE curated.dim_clinic (
    clinic_key integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    clinic_id integer NOT NULL UNIQUE,
    clinic_name text,
    suburb text,
    postcode text
);
COMMENT ON TABLE curated.dim_clinic
IS 'One GP clinic; clinic_key is a warehouse key and clinic_id is the source ID.';

INSERT INTO curated.dim_clinic (clinic_id, clinic_name, suburb, postcode)
SELECT clinic_id, clinic_name, suburb, postcode
FROM raw.gp_clinic
ORDER BY clinic_id;

-- Laboratory dimension: retain the original laboratory reporting convention.
CREATE TABLE curated.dim_lab (
    lab_key integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    lab_id integer NOT NULL UNIQUE,
    lab_name text,
    reporting_unit text
);
COMMENT ON TABLE curated.dim_lab
IS 'One pathology laboratory, including its source reporting unit.';

INSERT INTO curated.dim_lab (lab_id, lab_name, reporting_unit)
SELECT lab_id, lab_name, reporting_unit
FROM raw.lab_laboratory
ORDER BY lab_id;

-- Pharmacy dimension: one pharmacy, independent of patient registrations.
CREATE TABLE curated.dim_pharmacy (
    pharmacy_key integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    pharmacy_id integer NOT NULL UNIQUE,
    pharmacy_name text,
    suburb text
);
COMMENT ON TABLE curated.dim_pharmacy
IS 'One pharmacy; source pharmacy_id is retained as a unique business ID.';

INSERT INTO curated.dim_pharmacy (pharmacy_id, pharmacy_name, suburb)
SELECT pharmacy_id, pharmacy_name, suburb
FROM raw.pharm_pharmacy
ORDER BY pharmacy_id;

-- Medication dimension: keep the full reference description and drug class.
-- The source code remains text; it is not reused as the warehouse key.
CREATE TABLE curated.dim_medication (
    medication_key integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    pbs_item_code text NOT NULL UNIQUE,
    drug_name text,
    strength text,
    pack_size integer,
    typical_daily_dose numeric,
    drug_class text
);
COMMENT ON TABLE curated.dim_medication
IS 'One medicine item, including source code, pack details, daily dose and drug class.';

INSERT INTO curated.dim_medication
    (pbs_item_code, drug_name, strength, pack_size, typical_daily_dose, drug_class)
SELECT pbs_item_code, drug_name, strength, pack_size, typical_daily_dose, drug_class
FROM raw.pharm_medication
ORDER BY pbs_item_code;

-- Test dimension: the two conventions specified in section 5.4.
-- These original units do not change the later fact's standard mmol/mol value.
CREATE TABLE curated.dim_test (
    test_key integer PRIMARY KEY,
    loinc_code text NOT NULL UNIQUE,
    test_name text NOT NULL,
    reported_unit text NOT NULL
);
COMMENT ON TABLE curated.dim_test
IS 'One HbA1c reporting convention; fact results will be standardised to mmol/mol.';

INSERT INTO curated.dim_test (test_key, loinc_code, test_name, reported_unit)
VALUES
    (1, '59261-8', 'HbA1c (IFCC)', 'mmol/mol'),
    (2, '4548-4', 'HbA1c (NGSP)', '%');

-- Patient dimension: one master, not one source registration.
-- Preserve every golden GP patient, even if a LAB/PHARM record is unresolved.
CREATE TABLE curated.dim_patient (
    patient_key integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    patient_id text NOT NULL UNIQUE,
    display_name text NOT NULL,
    date_of_birth date,
    sex char(1),
    home_clinic_key integer NOT NULL REFERENCES curated.dim_clinic(clinic_key)
);
COMMENT ON TABLE curated.dim_patient
IS 'One golden GP patient; home clinic comes from the lowest linked gp_patient_id.';

-- Normal-case names follow business rules v1.2; dob maps to date_of_birth.
-- Sorting by the stable GL id also keeps surrogate keys stable on full reruns
-- of the same fixture. Rebuild 07 and 08 whenever 06 is rebuilt.
WITH gp_anchor AS (
    SELECT patient_id, min(source_patient_id) AS gp_patient_id
    FROM cleansed.patient_source_link
    WHERE source_system = 'GP' AND match_status = 'LINKED'
    GROUP BY patient_id
)
INSERT INTO curated.dim_patient
    (patient_id, display_name, date_of_birth, sex, home_clinic_key)
SELECT m.patient_id,
       initcap(concat_ws(' ', nullif(btrim(m.given_name), ''),
                              nullif(btrim(m.family_name), ''))),
       m.dob, m.sex, c.clinic_key
FROM cleansed.patient_master m
JOIN gp_anchor a ON a.patient_id = m.patient_id
JOIN raw.gp_patient gp ON gp.gp_patient_id = a.gp_patient_id
JOIN curated.dim_clinic c ON c.clinic_id = gp.clinic_id
ORDER BY m.patient_id;

-- Abort the transaction if a join multiplied or omitted golden patients.
DO $$
BEGIN
    IF (SELECT count(*) FROM curated.dim_patient) <> 17 THEN
        RAISE EXCEPTION 'dim_patient must contain exactly 17 rows for the A2 fixture.';
    END IF;
END
$$;

-- Commit after all seven dimensions have been created and loaded successfully.
COMMIT;

-- Acceptance check 1: seven rows, all PASS; counts 730 / 3 / 2 / 3 / 3 / 2 / 17.
SELECT current_database() AS database_name, table_name, row_count, expected_count,
       CASE WHEN row_count = expected_count THEN 'PASS' ELSE 'CHECK' END AS status
FROM (
    SELECT 1 AS sort_order, 'dim_date' AS table_name,
           count(*) AS row_count, 730 AS expected_count FROM curated.dim_date
    UNION ALL
    SELECT 2, 'dim_clinic', count(*), 3 FROM curated.dim_clinic
    UNION ALL
    SELECT 3, 'dim_lab', count(*), 2 FROM curated.dim_lab
    UNION ALL
    SELECT 4, 'dim_pharmacy', count(*), 3 FROM curated.dim_pharmacy
    UNION ALL
    SELECT 5, 'dim_medication', count(*), 3 FROM curated.dim_medication
    UNION ALL
    SELECT 6, 'dim_test', count(*), 2 FROM curated.dim_test
    UNION ALL
    SELECT 7, 'dim_patient', count(*), 17 FROM curated.dim_patient
) AS counts
ORDER BY sort_order;

-- Acceptance check 2: expected 730 / 2025-01-01 / 2026-12-31.
SELECT count(*) AS row_count,
       min(full_date) AS first_date,
       max(full_date) AS last_date
FROM curated.dim_date;

-- Acceptance check 3: expected 0 inconsistent date rows.
SELECT count(*) AS incorrect_date_rows
FROM curated.dim_date
WHERE date_key IS DISTINCT FROM to_char(full_date, 'YYYYMMDD')::integer
   OR day IS DISTINCT FROM extract(day FROM full_date)::integer
   OR month IS DISTINCT FROM extract(month FROM full_date)::integer
   OR month_name IS DISTINCT FROM to_char(full_date, 'FMMonth')
   OR quarter IS DISTINCT FROM extract(quarter FROM full_date)::integer
   OR year IS DISTINCT FROM extract(year FROM full_date)::integer;

-- Acceptance check 4: the two LOINC conventions, with the existing keys 1 and 2.
SELECT test_key, loinc_code, test_name, reported_unit
FROM curated.dim_test
ORDER BY test_key;

-- Acceptance check 5: 17 patients, 17 distinct IDs, 0 missing home clinics.
SELECT current_database() AS database_name,
       count(*) AS patient_count, count(DISTINCT patient_id) AS unique_patient_ids,
       count(*) FILTER (WHERE home_clinic_key IS NULL) AS null_home_clinic_keys
FROM curated.dim_patient;

-- Acceptance check 6: exactly one row; GL-0008 / Sarah Lee / clinic 1 /
-- Parramatta Family Practice. Test by stable patient ID rather than name.
SELECT current_database() AS database_name, p.patient_id, p.display_name,
       c.clinic_id, c.clinic_name AS home_clinic
FROM curated.dim_patient p
JOIN curated.dim_clinic c ON c.clinic_key = p.home_clinic_key
WHERE p.patient_id = 'GL-0008';

-- Acceptance check 7: full patient listing for comparison with the masters.
SELECT p.patient_key, p.patient_id, p.display_name, p.date_of_birth, p.sex,
       c.clinic_id, c.clinic_name AS home_clinic
FROM curated.dim_patient p
JOIN curated.dim_clinic c ON c.clinic_key = p.home_clinic_key
ORDER BY p.patient_id;
