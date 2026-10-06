-- File:          02_src_data.sql
-- Package/owner: C - Quang Tien Le
-- Purpose:       Load all reference/patient data, visits, dispenses and truth.
-- Reads:         Build Plan v2 Appendices A and B (exact literal values).
-- Writes:        Nine C-owned source tables and audit.identity_truth below.
-- Design link:   Build Plan v2 sections 5.1/5.6; Task Cards v3 C-1 and C-2.
-- Run after:     00_setup.sql and 01_src_tables.sql; B runs 02b after this.
-- Re-runnable:   Yes; resets the owned data before loading the full dataset.
-- Updated:       2026-10-06; complete parts 1 and 2 (48 / 28 / 68 / 48).
-- Assistance:    Prepared with AI assistance; review every statement and record
--                that assistance in the contribution log.
--
-- SHARED RESET: Post a warning in Teams before running 01 or 02 (v3 D9).
-- TRUNCATE CASCADE also clears B's lab observations/deliveries and any other
-- FK-dependent data. Coordinate with B to reload 02b immediately afterwards.
-- Complete rebuild order: 00 -> 01 -> 02 -> 02b -> 03 -> later layers.
-- Run the entire file in one session. On an error before COMMIT, stop and
-- ROLLBACK; correct the error before retrying. Never run TRUNCATE by itself.

-- Keep the reset and all inserts in a single transaction.
BEGIN;

-- Evaluation answer key only; identity matching must never read this table.
CREATE TABLE IF NOT EXISTS audit.identity_truth (
    true_person_id TEXT,
    source_system TEXT,
    source_patient_id TEXT,
    PRIMARY KEY (source_system, source_patient_id)
);
COMMENT ON TABLE audit.identity_truth
IS 'Evaluation-only true person mapping from Appendix A; never an input to matching.';

-- Reset owned data; dependent lab messages are reloaded by B using 02b.
TRUNCATE TABLE
    src_gp.encounter, src_pharm.dispense, audit.identity_truth,
    src_gp.gp_patient, src_lab.lab_patient, src_pharm.pharmacy_patient,
    src_gp.clinic, src_lab.laboratory, src_pharm.pharmacy, src_pharm.medication
CASCADE;

-- Three GP clinics; insert parents before dependent patient records.
INSERT INTO src_gp.clinic
    (clinic_id, clinic_name, suburb, postcode)
VALUES
    (1, 'Parramatta Family Practice', 'Parramatta', '2150'),
    (2, 'Blacktown Medical Centre', 'Blacktown', '2148'),
    (3, 'Penrith GP Clinic', 'Penrith', '2750');

-- Two laboratories, preserving their original reporting units.
INSERT INTO src_lab.laboratory
    (lab_id, lab_name, reporting_unit)
VALUES
    (1, 'Western Sydney Pathology', 'mmol/mol'),
    (2, 'Parramatta Diagnostics', '%');

-- Three pharmacies; retain the source identifiers.
INSERT INTO src_pharm.pharmacy
    (pharmacy_id, pharmacy_name, suburb)
VALUES
    (1, 'Parramatta Community Pharmacy', 'Parramatta'),
    (2, 'Westmead Chemist', 'Westmead'),
    (3, 'Blacktown Discount Pharmacy', 'Blacktown');

-- Three medicine items, including the agreed synthetic PBS codes.
INSERT INTO src_pharm.medication
    (pbs_item_code, drug_name, strength, pack_size, typical_daily_dose, drug_class)
VALUES
    ('2430X', 'metformin', '500 mg', 100, 2, 'biguanide'),
    ('SYN002', 'gliclazide MR', '30 mg', 100, 2, 'sulfonylurea'),
    ('SYN003', 'sitagliptin', '100 mg', 28, 1, 'DPP-4 inhibitor');

-- 18 GP registrations. Keep both Sarah Lee records and original Medicare spacing.
INSERT INTO src_gp.gp_patient
    (gp_patient_id, first_name, last_name, dob, sex, postcode, medicare_number, clinic_id, enrolment_date)
VALUES
    ('GP-0001', 'Thomas', 'Smith', '1962-05-14', 'M', '2150', '2123 45670 1', 1, '2024-02-01'),
    ('GP-0002', 'Mei', 'Chen', '1970-08-02', 'F', '2150', '3234 56781 2', 1, '2024-03-01'),
    ('GP-0003', 'Ahmed', 'Khan', '1955-11-23', 'M', '2148', '4345 67892 3', 2, '2024-03-15'),
    ('GP-0004', 'Olivia', 'Brown', '1980-01-30', 'F', '2148', '5456 78903 4', 2, '2024-04-01'),
    ('GP-0005', 'James', 'Wilson', '1958-07-07', 'M', '2750', '2567 89014 5', 3, '2024-04-10'),
    ('GP-0006', 'Daniel', 'Nguyen', '1968-03-12', 'M', '2150', '6678 90125 6', 1, '2024-05-01'),
    ('GP-0007', 'Daniel', 'Nguyen', '1968-03-12', 'M', '2750', '2789 01236 7', 3, '2024-05-02'),
    ('GP-0008', 'Sarah', 'Lee', '1975-09-19', 'F', '2150', '3890 12347 8', 1, '2024-06-01'),
    ('GP-0009', 'Sarah', 'Lee', '1975-09-19', 'F', '2148', '3890123478', 2, '2025-11-01'),
    ('GP-0010', 'Grace', 'Taylor', '1965-04-04', 'F', '2150', '4901 23458 9', 1, '2024-06-15'),
    ('GP-0011', 'William', 'Jones', '1950-12-12', 'M', '2148', '5012 34569 0', 2, '2024-07-01'),
    ('GP-0012', 'Emily', 'Davis', '1972-06-06', 'F', '2750', '6123 45070 1', 3, '2024-07-15'),
    ('GP-0013', 'Lucas', 'Martin', '1985-02-20', 'M', '2150', '2234 56181 2', 1, '2024-08-01'),
    ('GP-0014', 'Chloe', 'White', '1978-10-10', 'F', '2148', '3345 67292 3', 2, '2024-08-15'),
    ('GP-0015', 'Noah', 'Harris', '1960-03-03', 'M', '2750', '4456 78303 4', 3, '2024-09-01'),
    ('GP-0016', 'Ava', 'Robinson', '1969-07-21', 'F', '2150', '5567 89414 5', 1, '2024-09-15'),
    ('GP-0017', 'Zoe', 'Clark', '1967-01-15', 'F', '2148', '2789 01636 7', 2, '2024-10-01'),
    ('GP-0018', 'Ethan', 'Lewis', '1949-01-15', 'M', '2750', '3890 12747 8', 3, '2024-10-15');

-- 17 lab patients. Preserve DD/MM/YYYY text, /IRN suffixes and PATH0006 NULL.
INSERT INTO src_lab.lab_patient
    (lab_patient_id, patient_name, dob, sex, medicare_number)
VALUES
    ('PATH0001', 'SMITH, Thomas J', '14/05/1962', 'M', '2123456701/1'),
    ('PATH0002', 'CHEN, Mei', '02/08/1970', 'F', '3234567812/1'),
    ('PATH0003', 'KHAN, Ahmed', '23/11/1955', 'M', '4345678923/1'),
    ('PATH0004', 'BROWN, Olivia', '30/01/1980', 'F', '5456789034/2'),
    ('PATH0005', 'WILSON, James', '07/07/1958', 'M', '2567890145/1'),
    ('PATH0006', 'NGUYEN, Daniel', '12/03/1968', 'M', NULL),
    ('PATH0007', 'NGUYEN, Daniel', '12/03/1968', 'M', '2789012367/1'),
    ('PATH0008', 'LEE, Sarah', '19/09/1975', 'F', '3890123478/1'),
    ('PATH0009', 'TAYLOR, Grace', '04/04/1965', 'F', '4901234589/1'),
    ('PATH0010', 'JONES, William', '12/12/1950', 'M', '5012345690/1'),
    ('PATH0011', 'DAVIS, Emily', '06/06/1972', 'F', '6123450701/1'),
    ('PATH0012', 'MARTIN, Lucas', '20/02/1985', 'M', '2234561812/1'),
    ('PATH0013', 'WHITE, Chloe', '10/10/1978', 'F', '3345672923/1'),
    ('PATH0014', 'HARRIS, Noah', '03/03/1960', 'M', '4456783034/1'),
    ('PATH0015', 'ROBINSON, Ava', '21/07/1969', 'F', '5567894145/1'),
    ('PATH0016', 'CLARK, Zoe', '15/01/1967', 'F', '2789016367/1'),
    ('PATH0017', 'LEWIS, Ethan', '15/01/1949', 'M', '3890127478/1');

-- 13 pharmacy records: no PH-1004. Keep initials, full names, spaces and NULLs.
INSERT INTO src_pharm.pharmacy_patient
    (pharmacy_patient_id, given_name, surname, date_of_birth, medicare_number, pharmacy_id)
VALUES
    ('PH-1001', 'T', 'Smith', '14-May-62', '2123456701', 1),
    ('PH-1002', 'Mei', 'Chen', '02-Aug-70', NULL, 3),
    ('PH-1003', 'A', 'Khan', '23-Nov-55', '4345678923', 3),
    ('PH-1005', 'J', 'Wilson', '07-Jul-58', '2567890145', 1),
    ('PH-1006', 'James', 'Wilson', '07-Jul-58', '2567 890 145', 2),
    ('PH-1007', 'D', 'Nguyen', '12-Mar-68', '2789012367', 3),
    ('PH-1008', 'S', 'Lee', '19-Sep-75', '3890123478', 1),
    ('PH-1009', 'G', 'Taylor', '04-Apr-65', '4901234589', 1),
    ('PH-1010', 'W', 'Jones', '12-Dec-50', '5012345690', 2),
    ('PH-1011', 'L', 'Martin', '20-Feb-85', '2234561812', 1),
    ('PH-1012', 'Jack', 'Thompson', '05-May-90', '6678905256', 2),
    ('PH-1013', 'Z', 'Clark', '15-Jan-67', '2789016367', 2),
    ('PH-1014', 'E', 'Lewis', '15-Jan-49', NULL, 3);

-- 28 visits from Appendix B.3; E11 on every row, four reviews and two care plans.
INSERT INTO src_gp.encounter
    (encounter_id, gp_patient_id, clinic_id, encounter_date, encounter_type, diagnosis_code, medication_review_flag, care_plan_flag)
VALUES
    ('E0001', 'GP-0001', 1, '2025-10-15', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0002', 'GP-0001', 1, '2026-02-20', 'CARE_PLAN', 'E11', FALSE, TRUE),
    ('E0003', 'GP-0001', 1, '2026-04-01', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0004', 'GP-0002', 1, '2025-11-01', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0005', 'GP-0002', 1, '2026-03-10', 'MEDICATION_REVIEW', 'E11', TRUE, FALSE),
    ('E0006', 'GP-0002', 1, '2026-07-15', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0007', 'GP-0003', 2, '2025-12-05', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0008', 'GP-0003', 2, '2026-06-01', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0009', 'GP-0004', 2, '2026-03-01', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0010', 'GP-0004', 2, '2026-06-01', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0011', 'GP-0005', 3, '2026-01-10', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0012', 'GP-0005', 3, '2026-05-10', 'MEDICATION_REVIEW', 'E11', TRUE, FALSE),
    ('E0013', 'GP-0006', 1, '2026-02-02', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0014', 'GP-0007', 3, '2026-02-03', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0015', 'GP-0008', 1, '2026-01-15', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0016', 'GP-0009', 2, '2026-06-20', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0017', 'GP-0010', 1, '2025-10-05', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0018', 'GP-0010', 1, '2026-01-05', 'CARE_PLAN', 'E11', FALSE, TRUE),
    ('E0019', 'GP-0010', 1, '2026-04-05', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0020', 'GP-0010', 1, '2026-07-05', 'MEDICATION_REVIEW', 'E11', TRUE, FALSE),
    ('E0021', 'GP-0011', 2, '2026-03-03', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0022', 'GP-0012', 3, '2026-02-14', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0023', 'GP-0013', 1, '2026-05-05', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0024', 'GP-0014', 2, '2026-05-02', 'MEDICATION_REVIEW', 'E11', TRUE, FALSE),
    ('E0025', 'GP-0015', 3, '2026-08-20', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0026', 'GP-0016', 1, '2026-04-04', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0027', 'GP-0017', 2, '2026-06-10', 'STANDARD', 'E11', FALSE, FALSE),
    ('E0028', 'GP-0018', 3, '2026-01-20', 'STANDARD', 'E11', FALSE, FALSE);

-- 68 dispenses expanded from Appendix B.5; per-patient sequence IDs, all dates in 2026.
INSERT INTO src_pharm.dispense
    (dispense_id, pharmacy_patient_id, pharmacy_id, pbs_item_code, dispensed_date, quantity, days_supply)
VALUES
    ('D-PH-1001-01', 'PH-1001', 1, '2430X', '2026-02-01', 60, 30),
    ('D-PH-1001-02', 'PH-1001', 1, '2430X', '2026-03-03', 60, 30),
    ('D-PH-1001-03', 'PH-1001', 1, '2430X', '2026-04-02', 60, 30),
    ('D-PH-1001-04', 'PH-1001', 1, '2430X', '2026-05-02', 60, 30),
    ('D-PH-1001-05', 'PH-1001', 1, '2430X', '2026-06-01', 60, 30),
    ('D-PH-1001-06', 'PH-1001', 1, '2430X', '2026-07-01', 60, 30),
    ('D-PH-1001-07', 'PH-1001', 1, '2430X', '2026-07-31', 60, 30),
    ('D-PH-1002-01', 'PH-1002', 3, '2430X', '2026-01-10', 60, 30),
    ('D-PH-1002-02', 'PH-1002', 3, '2430X', '2026-03-20', 60, 30),
    ('D-PH-1002-03', 'PH-1002', 3, '2430X', '2026-06-15', 60, 30),
    ('D-PH-1003-01', 'PH-1003', 3, '2430X', '2026-03-01', 60, 30),
    ('D-PH-1003-02', 'PH-1003', 3, '2430X', '2026-03-31', 60, 30),
    ('D-PH-1003-03', 'PH-1003', 3, '2430X', '2026-04-30', 60, 30),
    ('D-PH-1003-04', 'PH-1003', 3, '2430X', '2026-05-30', 60, 30),
    ('D-PH-1003-05', 'PH-1003', 3, '2430X', '2026-06-29', 60, 30),
    ('D-PH-1003-06', 'PH-1003', 3, '2430X', '2026-07-29', 60, 30),
    ('D-PH-1005-01', 'PH-1005', 1, '2430X', '2026-03-10', 60, 30),
    ('D-PH-1005-02', 'PH-1005', 1, '2430X', '2026-04-09', 60, 30),
    ('D-PH-1005-03', 'PH-1005', 1, '2430X', '2026-05-09', 60, 30),
    ('D-PH-1005-04', 'PH-1005', 1, '2430X', '2026-06-08', 60, 30),
    ('D-PH-1005-05', 'PH-1005', 1, '2430X', '2026-07-08', 60, 30),
    ('D-PH-1005-06', 'PH-1005', 1, '2430X', '2026-08-07', 60, 30),
    ('D-PH-1006-01', 'PH-1006', 2, '2430X', '2026-04-20', 60, 30),
    ('D-PH-1006-02', 'PH-1006', 2, '2430X', '2026-06-20', 60, 30),
    ('D-PH-1007-01', 'PH-1007', 3, 'SYN002', '2026-03-05', 60, 30),
    ('D-PH-1007-02', 'PH-1007', 3, 'SYN002', '2026-04-04', 60, 30),
    ('D-PH-1007-03', 'PH-1007', 3, 'SYN002', '2026-05-04', 60, 30),
    ('D-PH-1007-04', 'PH-1007', 3, 'SYN002', '2026-06-03', 60, 30),
    ('D-PH-1007-05', 'PH-1007', 3, 'SYN002', '2026-07-03', 60, 30),
    ('D-PH-1007-06', 'PH-1007', 3, 'SYN002', '2026-08-02', 60, 30),
    ('D-PH-1008-01', 'PH-1008', 1, '2430X', '2026-03-01', 60, 30),
    ('D-PH-1008-02', 'PH-1008', 1, '2430X', '2026-03-31', 60, 30),
    ('D-PH-1008-03', 'PH-1008', 1, '2430X', '2026-04-30', 60, 30),
    ('D-PH-1008-04', 'PH-1008', 1, '2430X', '2026-05-30', 60, 30),
    ('D-PH-1008-05', 'PH-1008', 1, '2430X', '2026-06-29', 60, 30),
    ('D-PH-1008-06', 'PH-1008', 1, '2430X', '2026-07-29', 60, 30),
    ('D-PH-1009-01', 'PH-1009', 1, '2430X', '2026-02-15', 60, 30),
    ('D-PH-1009-02', 'PH-1009', 1, '2430X', '2026-03-17', 60, 30),
    ('D-PH-1009-03', 'PH-1009', 1, '2430X', '2026-04-16', 60, 30),
    ('D-PH-1009-04', 'PH-1009', 1, '2430X', '2026-05-16', 60, 30),
    ('D-PH-1009-05', 'PH-1009', 1, '2430X', '2026-06-15', 60, 30),
    ('D-PH-1009-06', 'PH-1009', 1, '2430X', '2026-07-15', 60, 30),
    ('D-PH-1009-07', 'PH-1009', 1, '2430X', '2026-08-14', 60, 30),
    ('D-PH-1010-01', 'PH-1010', 2, '2430X', '2026-03-15', 60, 30),
    ('D-PH-1010-02', 'PH-1010', 2, '2430X', '2026-05-20', 60, 30),
    ('D-PH-1010-03', 'PH-1010', 2, '2430X', '2026-07-25', 60, 30),
    ('D-PH-1011-01', 'PH-1011', 1, '2430X', '2026-03-10', 60, 30),
    ('D-PH-1011-02', 'PH-1011', 1, '2430X', '2026-04-09', 60, 30),
    ('D-PH-1011-03', 'PH-1011', 1, '2430X', '2026-05-09', 60, 30),
    ('D-PH-1011-04', 'PH-1011', 1, '2430X', '2026-06-08', 60, 30),
    ('D-PH-1011-05', 'PH-1011', 1, '2430X', '2026-07-08', 60, 30),
    ('D-PH-1011-06', 'PH-1011', 1, '2430X', '2026-08-07', 60, 30),
    ('D-PH-1012-01', 'PH-1012', 2, '2430X', '2026-03-01', 60, 30),
    ('D-PH-1012-02', 'PH-1012', 2, '2430X', '2026-03-31', 60, 30),
    ('D-PH-1012-03', 'PH-1012', 2, '2430X', '2026-04-30', 60, 30),
    ('D-PH-1013-01', 'PH-1013', 2, 'SYN003', '2026-03-01', 28, 28),
    ('D-PH-1013-02', 'PH-1013', 2, 'SYN003', '2026-03-29', 28, 28),
    ('D-PH-1013-03', 'PH-1013', 2, 'SYN003', '2026-04-26', 28, 28),
    ('D-PH-1013-04', 'PH-1013', 2, 'SYN003', '2026-05-24', 28, 28),
    ('D-PH-1013-05', 'PH-1013', 2, 'SYN003', '2026-06-21', 28, 28),
    ('D-PH-1013-06', 'PH-1013', 2, 'SYN003', '2026-07-19', 28, 28),
    ('D-PH-1013-07', 'PH-1013', 2, 'SYN003', '2026-08-16', 28, 28),
    ('D-PH-1014-01', 'PH-1014', 3, '2430X', '2026-03-20', 60, 30),
    ('D-PH-1014-02', 'PH-1014', 3, '2430X', '2026-04-19', 60, 30),
    ('D-PH-1014-03', 'PH-1014', 3, '2430X', '2026-05-19', 60, 30),
    ('D-PH-1014-04', 'PH-1014', 3, '2430X', '2026-06-18', 60, 30),
    ('D-PH-1014-05', 'PH-1014', 3, '2430X', '2026-07-18', 60, 30),
    ('D-PH-1014-06', 'PH-1014', 3, '2430X', '2026-08-17', 60, 30);

-- 48 answer-key rows from Appendix A, covering 18 true people including pharmacy-only P16.
INSERT INTO audit.identity_truth
    (true_person_id, source_system, source_patient_id)
VALUES
    ('P01', 'GP', 'GP-0001'),
    ('P01', 'LAB', 'PATH0001'),
    ('P01', 'PHARM', 'PH-1001'),
    ('P02', 'GP', 'GP-0002'),
    ('P02', 'LAB', 'PATH0002'),
    ('P02', 'PHARM', 'PH-1002'),
    ('P03', 'GP', 'GP-0003'),
    ('P03', 'LAB', 'PATH0003'),
    ('P03', 'PHARM', 'PH-1003'),
    ('P04', 'GP', 'GP-0004'),
    ('P04', 'LAB', 'PATH0004'),
    ('P05', 'GP', 'GP-0005'),
    ('P05', 'LAB', 'PATH0005'),
    ('P05', 'PHARM', 'PH-1005'),
    ('P05', 'PHARM', 'PH-1006'),
    ('P06', 'GP', 'GP-0006'),
    ('P06', 'LAB', 'PATH0006'),
    ('P07', 'GP', 'GP-0007'),
    ('P07', 'LAB', 'PATH0007'),
    ('P07', 'PHARM', 'PH-1007'),
    ('P08', 'GP', 'GP-0008'),
    ('P08', 'GP', 'GP-0009'),
    ('P08', 'LAB', 'PATH0008'),
    ('P08', 'PHARM', 'PH-1008'),
    ('P09', 'GP', 'GP-0010'),
    ('P09', 'LAB', 'PATH0009'),
    ('P09', 'PHARM', 'PH-1009'),
    ('P10', 'GP', 'GP-0011'),
    ('P10', 'LAB', 'PATH0010'),
    ('P10', 'PHARM', 'PH-1010'),
    ('P11', 'GP', 'GP-0012'),
    ('P11', 'LAB', 'PATH0011'),
    ('P12', 'GP', 'GP-0013'),
    ('P12', 'LAB', 'PATH0012'),
    ('P12', 'PHARM', 'PH-1011'),
    ('P13', 'GP', 'GP-0014'),
    ('P13', 'LAB', 'PATH0013'),
    ('P14', 'GP', 'GP-0015'),
    ('P14', 'LAB', 'PATH0014'),
    ('P15', 'GP', 'GP-0016'),
    ('P15', 'LAB', 'PATH0015'),
    ('P16', 'PHARM', 'PH-1012'),
    ('P17', 'GP', 'GP-0017'),
    ('P17', 'LAB', 'PATH0016'),
    ('P17', 'PHARM', 'PH-1013'),
    ('P18', 'GP', 'GP-0018'),
    ('P18', 'LAB', 'PATH0017'),
    ('P18', 'PHARM', 'PH-1014');

-- Commit only after every source and answer-key row has loaded.
COMMIT;

-- C-1/C-2 evidence: every status must be PASS (database name included).
SELECT current_database() AS database_name, table_name, actual_rows, expected_rows,
       CASE WHEN actual_rows = expected_rows THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT 1 AS sort_order, 'src_gp.clinic' AS table_name, COUNT(*) AS actual_rows, 3 AS expected_rows FROM src_gp.clinic
    UNION ALL
    SELECT 2 AS sort_order, 'src_lab.laboratory' AS table_name, COUNT(*) AS actual_rows, 2 AS expected_rows FROM src_lab.laboratory
    UNION ALL
    SELECT 3 AS sort_order, 'src_pharm.pharmacy' AS table_name, COUNT(*) AS actual_rows, 3 AS expected_rows FROM src_pharm.pharmacy
    UNION ALL
    SELECT 4 AS sort_order, 'src_pharm.medication' AS table_name, COUNT(*) AS actual_rows, 3 AS expected_rows FROM src_pharm.medication
    UNION ALL
    SELECT 5 AS sort_order, 'src_gp.gp_patient' AS table_name, COUNT(*) AS actual_rows, 18 AS expected_rows FROM src_gp.gp_patient
    UNION ALL
    SELECT 6 AS sort_order, 'src_lab.lab_patient' AS table_name, COUNT(*) AS actual_rows, 17 AS expected_rows FROM src_lab.lab_patient
    UNION ALL
    SELECT 7 AS sort_order, 'src_pharm.pharmacy_patient' AS table_name, COUNT(*) AS actual_rows, 13 AS expected_rows FROM src_pharm.pharmacy_patient
    UNION ALL
    SELECT 8 AS sort_order, 'src_gp.encounter' AS table_name, COUNT(*) AS actual_rows, 28 AS expected_rows FROM src_gp.encounter
    UNION ALL
    SELECT 9 AS sort_order, 'src_pharm.dispense' AS table_name, COUNT(*) AS actual_rows, 68 AS expected_rows FROM src_pharm.dispense
    UNION ALL
    SELECT 10 AS sort_order, 'audit.identity_truth' AS table_name, COUNT(*) AS actual_rows, 48 AS expected_rows FROM audit.identity_truth
) AS checks
ORDER BY sort_order;

-- C-1: exactly PATH0006, PH-1002 and PH-1014 have no Medicare.
SELECT gp_patient_id AS source_patient_id FROM src_gp.gp_patient WHERE medicare_number IS NULL
UNION ALL
SELECT lab_patient_id FROM src_lab.lab_patient WHERE medicare_number IS NULL
UNION ALL
SELECT pharmacy_patient_id FROM src_pharm.pharmacy_patient WHERE medicare_number IS NULL
ORDER BY source_patient_id;

-- C-1: the required sex type is character(1).
SELECT data_type, character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'src_lab' AND table_name = 'lab_patient' AND column_name = 'sex';

-- C-2: 28 visits, 4 medication reviews, 2 care plans; all diagnoses E11.
SELECT COUNT(*) AS encounters,
       COUNT(*) FILTER (WHERE medication_review_flag) AS medication_reviews,
       COUNT(*) FILTER (WHERE care_plan_flag) AS care_plans,
       COUNT(*) FILTER (WHERE diagnosis_code IS DISTINCT FROM 'E11') AS wrong_diagnoses
FROM src_gp.encounter;

-- C-2: truth covers GP 18, LAB 17, PHARM 13 and 18 distinct true people.
SELECT source_system, COUNT(*) AS records
FROM audit.identity_truth GROUP BY source_system ORDER BY source_system;
SELECT COUNT(*) AS truth_records, COUNT(DISTINCT true_person_id) AS true_people
FROM audit.identity_truth;

-- C-2: compare the per-patient dispense counts with task card C-2.
SELECT pharmacy_patient_id, COUNT(*) AS dispenses
FROM src_pharm.dispense GROUP BY pharmacy_patient_id ORDER BY pharmacy_patient_id;

-- Coverage check: missing_truth and orphan_truth must both be zero.
WITH source_ids AS (
    SELECT 'GP' AS source_system, gp_patient_id AS source_patient_id FROM src_gp.gp_patient
    UNION ALL SELECT 'LAB', lab_patient_id FROM src_lab.lab_patient
    UNION ALL SELECT 'PHARM', pharmacy_patient_id FROM src_pharm.pharmacy_patient
)
SELECT COUNT(*) FILTER (WHERE t.source_patient_id IS NULL) AS missing_truth,
       COUNT(*) FILTER (WHERE s.source_patient_id IS NULL) AS orphan_truth
FROM source_ids s FULL JOIN audit.identity_truth t
USING (source_system, source_patient_id);
