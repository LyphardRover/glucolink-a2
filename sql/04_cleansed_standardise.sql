-- File:          04_cleansed_standardise.sql
-- Package/owner: D - Yutong Geng
-- Purpose:       Build cleansed.patient_record: one standardised row per
--                source patient record across GP, LAB and PHARM (48 rows).
-- Reads:         src_gp.gp_patient, src_lab.lab_patient,
--                src_pharm.pharmacy_patient, reporting.rule_parameter.
-- Writes:        cleansed.patient_record.
-- Design link:   A2 Build Plan v2, section 5.3 (CLEANSED, owner D) and
--                section 6 (data-quality / standardisation rules).
--                Remediation Plan v3, task card D-1.
-- Run after:      00_setup.sql, 01_src_tables.sql, 02_src_data.sql,
--                 02b_src_lab_messages.sql, 03_raw_extract.sql.
-- Re-runnable:    Yes; removes its own objects first (DROP TABLE IF EXISTS).

BEGIN;

-- Guard: confirm schemas, source tables and rule_parameter exist.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.schemata WHERE schema_name = 'cleansed'
    ) THEN
        RAISE EXCEPTION 'The cleansed schema is missing or not accessible.';
    END IF;

    IF to_regclass('src_gp.gp_patient') IS NULL
       OR to_regclass('src_lab.lab_patient') IS NULL
       OR to_regclass('src_pharm.pharmacy_patient') IS NULL THEN
        RAISE EXCEPTION 'One or more source patient tables are missing.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM reporting.rule_parameter WHERE param_name = 'as_of_date'
    ) THEN
        RAISE EXCEPTION 'reporting.rule_parameter has no as_of_date row.';
    END IF;
END
$$;

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
IS 'One standardised row per source patient record (GP/LAB/PHARM), per Build Plan v2 section 5.3 and Remediation Plan v3 card D-1.';

-- ---------------------------------------------------------------------
-- GP: first_name/last_name already split; dob already a DATE (no century
-- issue). given_name now also takes only the first word (D-1 fix #3), and
-- blank given_name/family_name/postcode become NULL, not empty text
-- (D-1 fix #4). Medicare: keep digits before '/', keep the result only
-- if it is exactly 10 digits, else NULL (D-1 fix #2) -- applied uniformly
-- even though GP's source format has no '/' suffix.
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
FROM src_gp.gp_patient;

-- ---------------------------------------------------------------------
-- LAB: patient_name arrives combined, e.g. 'SMITH, Thomas J' -- family
-- name before the comma, given name the first word after it (already
-- first-word-only, unchanged by D-1). dob arrives as text DD/MM/YYYY
-- (four-digit year, no century issue); a blank dob text becomes NULL
-- before parsing, per D-1 fix #1. Medicare keeps digits before '/',
-- only kept if exactly 10 digits (D-1 fix #2).
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
FROM src_lab.lab_patient;

-- ---------------------------------------------------------------------
-- PHARM: given_name/surname already split (given_name may be only an
-- initial, e.g. 'T' -- unchanged, still one word). date_of_birth arrives
-- as text DD-Mon-YY. D-1 fix #1 replaces the old fixed "yy >= 40 -> 19xx"
-- cutoff with the Build Plan v2 section 6 rule: parse assuming the
-- current century first (20yy), then if that date is AFTER the as_of_date
-- (read from reporting.rule_parameter, not hard-coded), subtract 100
-- years. A blank date_of_birth becomes NULL before parsing. Medicare:
-- same rule as GP/LAB -- split on '/' first (drop the IRN suffix), THEN
-- strip to digits, kept only if exactly 10 digits (10/8 correction: the
-- '/' split was missing here, so a PHARM number with a suffix was not
-- having it dropped before the digit count was checked).
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
    FROM src_pharm.pharmacy_patient
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

COMMIT;

-- ===================== Acceptance checks (card D-1) =====================

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

-- No medicare10 of the wrong length should survive (NULLs are excluded
-- automatically since length(NULL) <> 10 is NULL, not true).
SELECT count(*) AS wrong_length_count
FROM cleansed.patient_record
WHERE length(medicare10) <> 10;
-- Expect 0.

-- Spot checks named in the task card.
SELECT source_patient_id, medicare10 FROM cleansed.patient_record WHERE source_patient_id = 'PH-1006';
-- Expect 2567890145.
SELECT source_patient_id, medicare10 FROM cleansed.patient_record WHERE source_patient_id = 'PATH0004';
-- Expect 5456789034.
