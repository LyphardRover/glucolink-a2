-- File:          04_cleansed_standardise.sql
-- Package/owner: D - Yutong Geng
-- Purpose:       Build cleansed.patient_record: one standardised row per
--                source patient record across GP, LAB and PHARM (48 rows
--                at full load; 4 rows for the Thursday C2 sample).
-- Reads:         src_gp.gp_patient, src_lab.lab_patient,
--                src_pharm.pharmacy_patient.
-- Writes:        cleansed.patient_record.
-- Design link:   A2 Build Plan v2, section 5.3 (CLEANSED, owner D) and
--                section 6 (data-quality / standardisation rules).
-- Run after:     00_setup.sql, 01_src_tables.sql, 02_src_data.sql.
-- Re-runnable:   Yes; removes its own objects first (DROP TABLE IF EXISTS).

BEGIN;

-- Guard: confirm schemas and source tables exist before rebuilding.
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
END
$$;

-- Removes its own objects first, per section 8 re-runnable pattern.
DROP TABLE IF EXISTS cleansed.patient_record CASCADE;

CREATE TABLE cleansed.patient_record (
    source_system     text NOT NULL,   -- 'GP' / 'LAB' / 'PHARM'
    source_patient_id text NOT NULL,
    given_name         text,            -- first word of the given name, upper case
    family_name        text,            -- upper case
    dob                 date,
    sex                  char(1),         -- NULL where the source has no sex field
    medicare10           text,            -- 10 digits, or NULL ("no Medicare" is SQL NULL, never text)
    postcode             text,            -- NULL where the source has no postcode field
    PRIMARY KEY (source_system, source_patient_id)
);

COMMENT ON TABLE cleansed.patient_record
IS 'One standardised row per source patient record (GP/LAB/PHARM), per Build Plan v2 section 5.3.';

-- ---------------------------------------------------------------------
-- GP: first_name/last_name already split; dob already a DATE; sex and
-- postcode already present. Medicare arrives with spaces, e.g.
-- '2123 45670 1' -> strip to digits only.
-- ---------------------------------------------------------------------
INSERT INTO cleansed.patient_record
    (source_system, source_patient_id, given_name, family_name,
     dob, sex, medicare10, postcode)
SELECT
    'GP',
    gp_patient_id,
    UPPER(TRIM(first_name)),
    UPPER(TRIM(last_name)),
    dob,
    UPPER(TRIM(sex)),
    NULLIF(REGEXP_REPLACE(medicare_number, '\D', '', 'g'), ''),
    TRIM(postcode)
FROM src_gp.gp_patient;

-- ---------------------------------------------------------------------
-- LAB: patient_name arrives combined, e.g. 'SMITH, Thomas J' -- split on
-- the comma first (family name before it, given name is the first word
-- after it). dob arrives as text in DD/MM/YYYY. Medicare carries an IRN
-- suffix after a slash, e.g. '2123456701/1' -- only the part before the
-- slash is the real Medicare number; the suffix must be dropped, not
-- concatenated in, or medicare10 would come out 11 digits.
-- No postcode field exists on this source table -> NULL.
-- ---------------------------------------------------------------------
INSERT INTO cleansed.patient_record
    (source_system, source_patient_id, given_name, family_name,
     dob, sex, medicare10, postcode)
SELECT
    'LAB',
    lab_patient_id,
    UPPER(TRIM(SPLIT_PART(TRIM(SPLIT_PART(patient_name, ',', 2)), ' ', 1))),
    UPPER(TRIM(SPLIT_PART(patient_name, ',', 1))),
    TO_DATE(dob, 'DD/MM/YYYY'),
    UPPER(TRIM(sex)),
    NULLIF(REGEXP_REPLACE(SPLIT_PART(medicare_number, '/', 1), '\D', '', 'g'), ''),
    NULL
FROM src_lab.lab_patient;

-- ---------------------------------------------------------------------
-- PHARM: given_name/surname already split, but given_name may be only an
-- initial (e.g. 'T' for Thomas) -- kept as-is; this is why identity
-- resolution (05) cannot rely on name alone. date_of_birth arrives as
-- text in DD-Mon-YY; PostgreSQL's own century pivot reads '62' as 2062,
-- which is wrong, so the 100-year rule from section 5.3/8 is applied
-- manually: yy >= 40 -> 19yy, else -> 20yy (14-May-62 -> 1962-05-14).
-- No sex or postcode fields exist on this source table -> NULL.
-- Medicare can be NULL in the source (e.g. Lewis) -- left NULL here,
-- stored as SQL NULL, never as text.
-- ---------------------------------------------------------------------
INSERT INTO cleansed.patient_record
    (source_system, source_patient_id, given_name, family_name,
     dob, sex, medicare10, postcode)
WITH parsed_dob AS (
    SELECT
        pharmacy_patient_id,
        given_name,
        surname,
        medicare_number,
        SPLIT_PART(date_of_birth, '-', 1)::int AS dob_day,
        SPLIT_PART(date_of_birth, '-', 2)       AS dob_mon_abbr,
        SPLIT_PART(date_of_birth, '-', 3)::int   AS dob_yy
    FROM src_pharm.pharmacy_patient
)
SELECT
    'PHARM',
    pharmacy_patient_id,
    UPPER(TRIM(given_name)),
    UPPER(TRIM(surname)),
    MAKE_DATE(
        CASE WHEN dob_yy >= 40 THEN 1900 + dob_yy ELSE 2000 + dob_yy END,
        EXTRACT(MONTH FROM TO_DATE(dob_mon_abbr, 'Mon'))::int,
        dob_day
    ),
    NULL,
    NULLIF(REGEXP_REPLACE(medicare_number, '\D', '', 'g'), ''),
    NULL
FROM parsed_dob;

COMMIT;

-- ===================== Acceptance check (Build Plan v2 "Done when") =====================
-- Expected, exactly:
-- GP    GP-0001  THOMAS SMITH  1962-05-14  2123456701
-- LAB   PATH0001 THOMAS SMITH  1962-05-14  2123456701
-- PHARM PH-1001  T      SMITH  1962-05-14  2123456701
-- PHARM PH-1014  E      LEWIS  1949-01-15  NULL
SELECT source_system, source_patient_id, given_name, family_name, dob, medicare10
FROM cleansed.patient_record
WHERE source_patient_id IN ('GP-0001', 'PATH0001', 'PH-1001', 'PH-1014')
ORDER BY source_patient_id;

-- Supporting check: row count should be 4 now (C2 sample); 48 once C's
-- full C3 load (02_src_data.sql remainder + 02b) lands by Thursday 15:00.
SELECT count(*) AS row_count FROM cleansed.patient_record;

-- Supporting check: no medicare10 value left with the wrong digit count
-- (10 expected, NULL allowed -- e.g. Lewis has no Medicare on file).
SELECT source_system, source_patient_id, medicare10, LENGTH(medicare10) AS len
FROM cleansed.patient_record
WHERE medicare10 IS NOT NULL AND LENGTH(medicare10) <> 10;
-- Expect 0 rows.
