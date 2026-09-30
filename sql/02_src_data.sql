-- File:          02_src_data.sql
-- Package/owner: C - Quang Tien Le
-- Purpose:       Load C2 early-release reference data and four patient records.
-- Reads:         A2 Build Plan v2 Appendix B (literal source values).
-- Writes:        src_gp.clinic, src_gp.gp_patient, src_lab.laboratory,
--                src_lab.lab_patient, src_pharm.pharmacy,
--                src_pharm.medication, src_pharm.pharmacy_patient.
-- Design link:   Three source systems; section 5.1, task C2 and Appendix B.
-- Run after:     01_src_tables.sql in the intended GlucoLink database.
-- Re-runnable:   Yes; TRUNCATE the seven target tables before loading.
-- Release:       C2 ONLY. C3 patients, encounters, dispenses and identity truth
--                are not included yet. Extend this same file for later tasks.
-- Assistance:    Assembled with AI assistance during the SQL walkthrough;
--                review and record that assistance in the contribution log.
--
-- WARNING: This is a reset/load script, not an additional-data-only script.
-- TRUNCATE CASCADE also empties referencing tables, including GP encounters,
-- pharmacy dispenses and B's lab observations/deliveries. It can empty other
-- tables if downstream foreign keys have been added. Coordinate shared resets
-- with the team; use a separate test database to check repeatability.
-- Do not run this C2 release over a later C3/full load: it restores only C2 data.
-- Where lab data is needed, rerun 02b_src_lab_messages.sql after the appropriate
-- complete version of 02_src_data.sql (full rebuild order: 01 -> 02 -> 02b).
-- Execute the complete script in order in one session. Never run TRUNCATE alone.
-- If any statement fails before COMMIT, stop and run ROLLBACK before retrying.

-- Keep reset and data loading atomic.
BEGIN;

-- Reset the tables populated by this release, as required by the build plan.
TRUNCATE TABLE
    src_gp.gp_patient,
    src_gp.clinic,
    src_lab.lab_patient,
    src_lab.laboratory,
    src_pharm.pharmacy_patient,
    src_pharm.medication,
    src_pharm.pharmacy
CASCADE;

-- Load three clinics before the GP patient that references clinic 1.
INSERT INTO src_gp.clinic
    (clinic_id, clinic_name, suburb, postcode)
VALUES
    (1, 'Parramatta Family Practice', 'Parramatta', '2150'),
    (2, 'Blacktown Medical Centre', 'Blacktown', '2148'),
    (3, 'Penrith GP Clinic', 'Penrith', '2750');

-- Preserve the reporting units of the two laboratories.
INSERT INTO src_lab.laboratory
    (lab_id, lab_name, reporting_unit)
VALUES
    (1, 'Western Sydney Pathology', 'mmol/mol'),
    (2, 'Parramatta Diagnostics', '%');

-- Load three pharmacies before their patient registrations.
INSERT INTO src_pharm.pharmacy
    (pharmacy_id, pharmacy_name, suburb)
VALUES
    (1, 'Parramatta Community Pharmacy', 'Parramatta'),
    (2, 'Westmead Chemist', 'Westmead'),
    (3, 'Blacktown Discount Pharmacy', 'Blacktown');

-- Use the medication codes, pack sizes and daily doses specified in Appendix B.
INSERT INTO src_pharm.medication
    (pbs_item_code, drug_name, strength,
     pack_size, typical_daily_dose, drug_class)
VALUES
    ('2430X', 'metformin', '500 mg', 100, 2, 'biguanide'),
    ('SYN002', 'gliclazide MR', '30 mg', 100, 2, 'sulfonylurea'),
    ('SYN003', 'sitagliptin', '100 mg', 28, 1, 'DPP-4 inhibitor');

-- GP uses DATE fields and a Medicare value with spaces.
INSERT INTO src_gp.gp_patient
    (gp_patient_id, first_name, last_name, dob, sex,
     postcode, medicare_number, clinic_id, enrolment_date)
VALUES
    ('GP-0001', 'Thomas', 'Smith', DATE '1962-05-14', 'M',
     '2150', '2123 45670 1', 1, DATE '2024-02-01');

-- LAB keeps its name, DD/MM/YYYY date text and Medicare /IRN suffix unchanged.
INSERT INTO src_lab.lab_patient
    (lab_patient_id, patient_name, dob, sex, medicare_number)
VALUES
    ('PATH0001', 'SMITH, Thomas J', '14/05/1962', 'M',
     '2123456701/1');

-- PHARM keeps initials and DD-Mon-YY text. Lewis has a missing Medicare value.
-- Three of the four source records represent Thomas Smith across systems.
-- Standardisation and identity resolution belong to later pipeline stages.
INSERT INTO src_pharm.pharmacy_patient
    (pharmacy_patient_id, given_name, surname,
     date_of_birth, medicare_number, pharmacy_id)
VALUES
    ('PH-1001', 'T', 'Smith', '14-May-62', '2123456701', 1),
    ('PH-1014', 'E', 'Lewis', '15-Jan-49', NULL, 3);

-- Commit the complete C2 load.
COMMIT;

-- C2 acceptance check: all seven rows should show PASS immediately after load.
-- Expected patient counts increase when the C3 release is loaded later.
SELECT table_name, row_count, expected_count,
       CASE WHEN row_count = expected_count THEN 'PASS' ELSE 'CHECK' END AS status
FROM (
    SELECT 1 AS sort_order, 'src_gp.clinic' AS table_name,
           COUNT(*) AS row_count, 3 AS expected_count FROM src_gp.clinic
    UNION ALL
    SELECT 2, 'src_lab.laboratory', COUNT(*), 2 FROM src_lab.laboratory
    UNION ALL
    SELECT 3, 'src_pharm.pharmacy', COUNT(*), 3 FROM src_pharm.pharmacy
    UNION ALL
    SELECT 4, 'src_pharm.medication', COUNT(*), 3 FROM src_pharm.medication
    UNION ALL
    SELECT 5, 'src_gp.gp_patient', COUNT(*), 1 FROM src_gp.gp_patient
    UNION ALL
    SELECT 6, 'src_lab.lab_patient', COUNT(*), 1 FROM src_lab.lab_patient
    UNION ALL
    SELECT 7, 'src_pharm.pharmacy_patient', COUNT(*), 2
    FROM src_pharm.pharmacy_patient
) AS counts
ORDER BY sort_order;

-- Inspect exact values of the four C2 source records without changing them.
SELECT * FROM src_gp.gp_patient WHERE gp_patient_id = 'GP-0001';
SELECT * FROM src_lab.lab_patient WHERE lab_patient_id = 'PATH0001';
SELECT * FROM src_pharm.pharmacy_patient
WHERE pharmacy_patient_id IN ('PH-1001', 'PH-1014')
ORDER BY pharmacy_patient_id;
