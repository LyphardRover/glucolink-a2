-- File:          05_identity_resolution.sql
-- Package/owner: D - Yutong Geng
-- Purpose:       Build the golden patient index (cleansed.patient_master)
--                from GP records only, and link every GP/LAB/PHARM record
--                to a master in cleansed.patient_source_link, using the
--                deterministic R1/R2/REVIEW/UNMATCHED rules in
--                A2 Build Plan v2 section 6 and docs/identity_rules_v1.1.md.
-- Reads:         cleansed.patient_record.
-- Writes:        cleansed.patient_master, cleansed.patient_source_link.
-- Design link:   A2 Build Plan v2, section 5.3 and section 6.
--                Remediation Plan v3, task card D-2.
-- Run after:      04_cleansed_standardise.sql.
-- Re-runnable:    Yes; removes its own objects first (DROP TABLE IF EXISTS).
-- Keys:           patient_source_link.patient_id -> patient_master.patient_id (FK).
--                 patient_master holds identity fields only (no postcode).
--
-- IMPORTANT: this script never reads audit.identity_truth. That table is
-- the evaluation answer key; precision and recall are scored separately
-- (identity_rules_v1.1.md, section 6), never inside this script.

BEGIN;

DO $$
BEGIN
    IF to_regclass('cleansed.patient_record') IS NULL THEN
        RAISE EXCEPTION 'cleansed.patient_record is missing - run 04_cleansed_standardise.sql first.';
    END IF;
END
$$;

DROP TABLE IF EXISTS cleansed.patient_source_link CASCADE;
DROP TABLE IF EXISTS cleansed.patient_master CASCADE;

CREATE TABLE cleansed.patient_master (
    patient_id   text PRIMARY KEY,    -- 'GL-0001' style golden patient id
    given_name    text,
    family_name   text,
    dob            date,
    sex             char(1),
    medicare10      text               -- NULL if no GP record in the group had one
);

COMMENT ON TABLE cleansed.patient_master
IS 'Golden patient index, built only from GP records (GP = GlucoLink enrolment). Per identity_rules_v1.1.md.';

CREATE TABLE cleansed.patient_source_link (
    source_system     text NOT NULL,
    source_patient_id text NOT NULL,
    patient_id         text REFERENCES cleansed.patient_master (patient_id),  -- NULL unless LINKED
    match_status        text NOT NULL,     -- LINKED / REVIEW / UNMATCHED
    match_rule           text,              -- GP / R1 / R2 / NULL (REVIEW, UNMATCHED)
    candidate_count       int NOT NULL,      -- how many masters satisfied the rule tried
    PRIMARY KEY (source_system, source_patient_id)
);

COMMENT ON TABLE cleansed.patient_source_link
IS 'Links every source patient record to a golden patient (or REVIEW/UNMATCHED). Per identity_rules_v1.1.md. Never merges on doubt.';

-- ---------------------------------------------------------------------
-- Step 1: group GP records into golden patients.
-- A GP record with a valid medicare10 shares a master with every other
-- GP record that has the SAME medicare10 (this is how 18 GP records
-- become 17 masters: GP-0008 and GP-0009 share one medicare10 and
-- therefore one master). A GP record with no valid medicare10 forms its
-- own, single-member group. Each GP record is LINKED to its own group's
-- master directly, match_rule = 'GP' (never via R1/R2 - those only apply
-- to LAB/PHARM records being linked onto the GP-built masters).
-- ---------------------------------------------------------------------
CREATE TEMP TABLE gp_groups AS
SELECT
    source_patient_id,
    medicare10,
    COALESCE(medicare10, 'NOID_' || source_patient_id) AS group_key
FROM cleansed.patient_record
WHERE source_system = 'GP';

CREATE TEMP TABLE group_reps AS
SELECT
    g.group_key,
    MIN(g.source_patient_id) AS rep_source_patient_id,
    ROW_NUMBER() OVER (ORDER BY MIN(g.source_patient_id)) AS seq
FROM gp_groups g
GROUP BY g.group_key;

CREATE TEMP TABLE master_build AS
SELECT
    'GL-' || LPAD(gr.seq::text, 4, '0') AS patient_id,
    gr.group_key,
    pr.given_name,
    pr.family_name,
    pr.dob,
    pr.sex,
    pr.medicare10
FROM group_reps gr
JOIN cleansed.patient_record pr
  ON pr.source_system = 'GP'
 AND pr.source_patient_id = gr.rep_source_patient_id;

INSERT INTO cleansed.patient_master (patient_id, given_name, family_name, dob, sex, medicare10)
SELECT patient_id, given_name, family_name, dob, sex, medicare10
FROM master_build;

-- ---------------------------------------------------------------------
-- Step 2: link every GP record to its own group's master.
-- ---------------------------------------------------------------------
INSERT INTO cleansed.patient_source_link
    (source_system, source_patient_id, patient_id, match_status, match_rule, candidate_count)
SELECT
    'GP',
    gg.source_patient_id,
    mb.patient_id,
    'LINKED',
    'GP',
    1
FROM gp_groups gg
JOIN master_build mb ON mb.group_key = gg.group_key;

-- ---------------------------------------------------------------------
-- Step 3: link LAB and PHARM records onto the GP-built masters.
--   R1: record.medicare10 = exactly one master.medicare10         -> LINKED, rule R1
--       (if it equals more than one master's medicare10           -> REVIEW, rule R1)
--   R2 (only if R1 found zero candidates):
--       same dob, same family_name, same first letter of given_name
--       as a master, and medicare10s don't conflict (one NULL or equal)
--       -> exactly one such master -> LINKED, rule R2
--       -> more than one                                          -> REVIEW, rule R2
--       -> none                                                    -> UNMATCHED
-- Never merges on doubt: any ambiguity (candidate_count > 1) is REVIEW,
-- never forced to the "best" guess.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE non_gp AS
SELECT *
FROM cleansed.patient_record
WHERE source_system IN ('LAB', 'PHARM');

CREATE TEMP TABLE r1_candidates AS
SELECT
    ng.source_system,
    ng.source_patient_id,
    m.patient_id,
    COUNT(*) OVER (PARTITION BY ng.source_system, ng.source_patient_id) AS r1_count
FROM non_gp ng
JOIN cleansed.patient_master m
  ON ng.medicare10 IS NOT NULL
 AND ng.medicare10 = m.medicare10;

CREATE TEMP TABLE r2_candidates AS
SELECT
    ng.source_system,
    ng.source_patient_id,
    m.patient_id,
    COUNT(*) OVER (PARTITION BY ng.source_system, ng.source_patient_id) AS r2_count
FROM non_gp ng
JOIN cleansed.patient_master m
  ON ng.dob = m.dob
 AND ng.family_name = m.family_name
 AND ng.family_name IS NOT NULL
 AND LEFT(ng.given_name, 1) = LEFT(m.given_name, 1)
 AND ng.given_name IS NOT NULL
 AND (ng.medicare10 IS NULL OR m.medicare10 IS NULL OR ng.medicare10 = m.medicare10)
WHERE NOT EXISTS (
    -- only consider R2 for records that had zero R1 candidates
    SELECT 1 FROM r1_candidates rc
    WHERE rc.source_system = ng.source_system
      AND rc.source_patient_id = ng.source_patient_id
);

INSERT INTO cleansed.patient_source_link
    (source_system, source_patient_id, patient_id, match_status, match_rule, candidate_count)
SELECT
    ng.source_system,
    ng.source_patient_id,
    CASE WHEN r1.r1_count = 1 THEN r1_one.patient_id
         WHEN r1.r1_count IS NULL AND r2.r2_count = 1 THEN r2_one.patient_id
         ELSE NULL END,
    CASE WHEN r1.r1_count = 1 THEN 'LINKED'
         WHEN r1.r1_count > 1 THEN 'REVIEW'
         WHEN r1.r1_count IS NULL AND r2.r2_count = 1 THEN 'LINKED'
         WHEN r1.r1_count IS NULL AND r2.r2_count > 1 THEN 'REVIEW'
         ELSE 'UNMATCHED' END,
    -- match_rule is only ever filled for a LINKED row (GP / R1 / R2);
    -- REVIEW and UNMATCHED always get NULL here (10/8 correction: an
    -- ambiguous REVIEW used to still record which rule produced the
    -- multiple candidates -- the task card wants that column empty
    -- unless match_status = 'LINKED').
    CASE WHEN r1.r1_count = 1 THEN 'R1'
         WHEN r1.r1_count IS NULL AND r2.r2_count = 1 THEN 'R2'
         ELSE NULL END,
    COALESCE(r1.r1_count, r2.r2_count, 0)
FROM non_gp ng
LEFT JOIN (SELECT DISTINCT source_system, source_patient_id, r1_count FROM r1_candidates) r1
       ON r1.source_system = ng.source_system AND r1.source_patient_id = ng.source_patient_id
LEFT JOIN (SELECT * FROM r1_candidates WHERE r1_count = 1) r1_one
       ON r1_one.source_system = ng.source_system AND r1_one.source_patient_id = ng.source_patient_id
LEFT JOIN (SELECT DISTINCT source_system, source_patient_id, r2_count FROM r2_candidates) r2
       ON r2.source_system = ng.source_system AND r2.source_patient_id = ng.source_patient_id
LEFT JOIN (SELECT * FROM r2_candidates WHERE r2_count = 1) r2_one
       ON r2_one.source_system = ng.source_system AND r2_one.source_patient_id = ng.source_patient_id;

DROP TABLE gp_groups;
DROP TABLE group_reps;
DROP TABLE master_build;
DROP TABLE non_gp;
DROP TABLE r1_candidates;
DROP TABLE r2_candidates;

COMMIT;

-- ===================== Acceptance checks (card D-2) =====================

-- Expect 17 masters.
SELECT count(*) AS master_count FROM cleansed.patient_master;

-- Expect LINKED 46 / REVIEW 1 / UNMATCHED 1.
SELECT match_status, count(*) AS n
FROM cleansed.patient_source_link
GROUP BY match_status
ORDER BY match_status;

-- Expect PATH0006 to be the single REVIEW row.
SELECT * FROM cleansed.patient_source_link WHERE match_status = 'REVIEW';

-- Expect PH-1012 to be the single UNMATCHED row.
SELECT * FROM cleansed.patient_source_link WHERE match_status = 'UNMATCHED';

-- Expect PH-1002 and PH-1014 linked via R2; PH-1014 -> GL-0017 (Ethan Lewis).
SELECT * FROM cleansed.patient_source_link WHERE source_patient_id IN ('PH-1002', 'PH-1014');

-- Expect GP-0008 and GP-0009 to share the same patient_id (GL-0008).
SELECT * FROM cleansed.patient_source_link WHERE source_patient_id IN ('GP-0008', 'GP-0009');
