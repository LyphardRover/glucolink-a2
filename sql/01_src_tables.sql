-- File:          01_src_tables.sql
-- Package/owner: C - Quang Tien Le
-- Purpose:       Rebuild the 11 source tables for the GlucoLink A2 prototype.
-- Reads:         Existing source definitions (reset); system catalogues (checks).
-- Writes:        The 11 named tables in src_gp, src_lab and src_pharm below.
-- Design link:   A2 Build Plan v2, sections 2 and 5.1 (three source systems).
-- Run after:     00_setup.sql, using the intended GlucoLink database connection.
-- Re-runnable:   Yes; resets the named source tables before recreating them.
-- Data loading:  Run 02_src_data.sql, then 02b_src_lab_messages.sql after this.
-- Assistance:    Assembled with AI assistance during the step-by-step walkthrough;
--                review and record that assistance in the contribution log.
--
-- WARNING: This is a RESET/BUILD script, not a read-only verification script.
-- It deletes existing data in these 11 tables, including B's lab messages and
-- deliveries. CASCADE can also remove dependent views or foreign-key constraints.
-- Coordinate any reset of the shared database with the team. Prefer testing
-- repeatability in a separate empty test database prepared by B.
-- Never run only the DROP block. Execute the complete script in order, in one
-- session. If a statement fails before COMMIT, stop and run ROLLBACK; investigate
-- the error before retrying. This file does not create or remove any schemas.

-- Keep the reset and rebuild in a single transaction.
BEGIN;

-- Reset only the 11 named source tables, children before parents.
-- This follows the reset pattern in section 3 of the team plan.
DROP TABLE IF EXISTS src_lab.result_delivery CASCADE;
DROP TABLE IF EXISTS src_lab.observation_message CASCADE;
DROP TABLE IF EXISTS src_gp.encounter CASCADE;
DROP TABLE IF EXISTS src_pharm.dispense CASCADE;
DROP TABLE IF EXISTS src_pharm.pharmacy_patient CASCADE;
DROP TABLE IF EXISTS src_gp.gp_patient CASCADE;
DROP TABLE IF EXISTS src_lab.lab_patient CASCADE;
DROP TABLE IF EXISTS src_pharm.medication CASCADE;
DROP TABLE IF EXISTS src_pharm.pharmacy CASCADE;
DROP TABLE IF EXISTS src_lab.laboratory CASCADE;
DROP TABLE IF EXISTS src_gp.clinic CASCADE;

-- Table 1: one row per GP clinic.
CREATE TABLE src_gp.clinic (
    clinic_id INTEGER PRIMARY KEY,
    clinic_name TEXT,
    suburb TEXT,
    postcode TEXT
);
COMMENT ON TABLE src_gp.clinic
IS 'One row per GP clinic in the source system.';

-- Table 2: one row per patient registration at a clinic.
-- Medicare is deliberately not UNIQUE: retain duplicate registrations and
-- original spacing so Package D can apply the agreed identity rules.
CREATE TABLE src_gp.gp_patient (
    gp_patient_id TEXT PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    dob DATE,
    sex CHAR(1),
    postcode TEXT,
    medicare_number TEXT,
    clinic_id INTEGER,
    enrolment_date DATE,
    CONSTRAINT fk_gp_patient_clinic
        FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic (clinic_id)
);
COMMENT ON TABLE src_gp.gp_patient
IS 'One row per patient registration at a GP clinic.';

-- Table 3: one row per GP visit.
-- Appendix B uses STANDARD, CARE_PLAN or MEDICATION_REVIEW as encounter_type.
CREATE TABLE src_gp.encounter (
    encounter_id TEXT PRIMARY KEY,
    gp_patient_id TEXT,
    clinic_id INTEGER,
    encounter_date DATE,
    encounter_type TEXT,
    diagnosis_code TEXT,
    medication_review_flag BOOLEAN,
    care_plan_flag BOOLEAN,
    CONSTRAINT fk_encounter_patient
        FOREIGN KEY (gp_patient_id) REFERENCES src_gp.gp_patient (gp_patient_id),
    CONSTRAINT fk_encounter_clinic
        FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic (clinic_id)
);
COMMENT ON TABLE src_gp.encounter
IS 'One row per GP visit, linked to a patient and clinic.';

-- Table 4: one row per pathology laboratory.
CREATE TABLE src_lab.laboratory (
    lab_id INTEGER PRIMARY KEY,
    lab_name TEXT,
    reporting_unit TEXT
);
COMMENT ON TABLE src_lab.laboratory
IS 'One row per pathology laboratory and its reporting unit.';

-- Table 5: one row per laboratory patient record.
-- Keep DOB as DD/MM/YYYY text and Medicare with its source suffix/formatting.
CREATE TABLE src_lab.lab_patient (
    lab_patient_id TEXT PRIMARY KEY,
    patient_name TEXT,
    dob TEXT,
    sex TEXT,
    medicare_number TEXT
);
COMMENT ON TABLE src_lab.lab_patient
IS 'One row per laboratory patient, preserving source formatting.';

-- Table 6: one row per FHIR-style result message. C creates; B populates.
-- JSON remains intact here; Package D parses and validates it later.
CREATE TABLE src_lab.observation_message (
    message_id TEXT PRIMARY KEY,
    lab_id INTEGER,
    lab_patient_id TEXT,
    received_at TIMESTAMPTZ,
    fhir_json JSONB,
    CONSTRAINT fk_observation_laboratory
        FOREIGN KEY (lab_id) REFERENCES src_lab.laboratory (lab_id),
    CONSTRAINT fk_observation_lab_patient
        FOREIGN KEY (lab_patient_id) REFERENCES src_lab.lab_patient (lab_patient_id)
);
COMMENT ON TABLE src_lab.observation_message
IS 'One row per laboratory result message containing a FHIR Observation.';

-- Table 7: one row per result delivery. C creates; B populates.
-- No delivery row means the result was not delivered.
-- clinic_id is INTEGER without an FK, as specified in section 5.1.
CREATE TABLE src_lab.result_delivery (
    delivery_id TEXT PRIMARY KEY,
    message_id TEXT,
    clinic_id INTEGER,
    delivered_at TIMESTAMPTZ,
    CONSTRAINT fk_delivery_message
        FOREIGN KEY (message_id) REFERENCES src_lab.observation_message (message_id)
);
COMMENT ON TABLE src_lab.result_delivery
IS 'One row per laboratory result delivery to a clinic.';

-- Table 8: one row per pharmacy.
CREATE TABLE src_pharm.pharmacy (
    pharmacy_id INTEGER PRIMARY KEY,
    pharmacy_name TEXT,
    suburb TEXT
);
COMMENT ON TABLE src_pharm.pharmacy
IS 'One row per pharmacy in the source system.';

-- Table 9: one row per medicine item.
CREATE TABLE src_pharm.medication (
    pbs_item_code TEXT PRIMARY KEY,
    drug_name TEXT,
    strength TEXT,
    pack_size INTEGER,
    typical_daily_dose NUMERIC,
    drug_class TEXT
);
COMMENT ON TABLE src_pharm.medication
IS 'One row per medicine item, including pack size, dose and drug class.';

-- Table 10: one row per pharmacy patient registration.
-- DOB stays as DD-Mon-YY text; Package D resolves the century later.
CREATE TABLE src_pharm.pharmacy_patient (
    pharmacy_patient_id TEXT PRIMARY KEY,
    given_name TEXT,
    surname TEXT,
    date_of_birth TEXT,
    medicare_number TEXT,
    pharmacy_id INTEGER,
    CONSTRAINT fk_pharmacy_patient_pharmacy
        FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy (pharmacy_id)
);
COMMENT ON TABLE src_pharm.pharmacy_patient
IS 'One row per patient registration at a pharmacy, preserving source formatting.';

-- Table 11: one row per medication dispensing event.
CREATE TABLE src_pharm.dispense (
    dispense_id TEXT PRIMARY KEY,
    pharmacy_patient_id TEXT,
    pharmacy_id INTEGER,
    pbs_item_code TEXT,
    dispensed_date DATE,
    quantity INTEGER,
    days_supply INTEGER,
    CONSTRAINT fk_dispense_patient
        FOREIGN KEY (pharmacy_patient_id)
        REFERENCES src_pharm.pharmacy_patient (pharmacy_patient_id),
    CONSTRAINT fk_dispense_pharmacy
        FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy (pharmacy_id),
    CONSTRAINT fk_dispense_medication
        FOREIGN KEY (pbs_item_code) REFERENCES src_pharm.medication (pbs_item_code)
);
COMMENT ON TABLE src_pharm.dispense
IS 'One row per dispensing event, linked to a pharmacy patient, pharmacy and medicine.';

-- Commit only after all 11 tables and their comments have been created.
COMMIT;

-- Check 1: expected table counts are src_gp=3, src_lab=4, src_pharm=4.
SELECT table_schema, COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema IN ('src_gp', 'src_lab', 'src_pharm')
  AND table_type = 'BASE TABLE'
GROUP BY table_schema
ORDER BY table_schema;

-- Check 2: list every column for comparison with the section 5.1 data contract.
SELECT table_schema, table_name, ordinal_position, column_name,
       data_type, character_maximum_length, is_nullable
FROM information_schema.columns
WHERE table_schema IN ('src_gp', 'src_lab', 'src_pharm')
ORDER BY table_schema, table_name, ordinal_position;

-- Check 3: expected PK/FK counts by schema are GP=3/3, LAB=4/3, PHARM=4/4.
SELECT table_schema,
       COUNT(*) FILTER (WHERE constraint_type = 'PRIMARY KEY') AS primary_keys,
       COUNT(*) FILTER (WHERE constraint_type = 'FOREIGN KEY') AS foreign_keys
FROM information_schema.table_constraints
WHERE table_schema IN ('src_gp', 'src_lab', 'src_pharm')
  AND constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
GROUP BY table_schema
ORDER BY table_schema;

-- Check 4: all 11 source tables should have a non-empty stored comment.
SELECT n.nspname AS table_schema, c.relname AS table_name,
       obj_description(c.oid, 'pg_class') AS table_comment
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname IN ('src_gp', 'src_lab', 'src_pharm')
  AND c.relkind IN ('r', 'p')
ORDER BY n.nspname, c.relname;
