-- File:          08_vw_uc2_pdc.sql  (block to sit inside 08_reporting_views.sql, before vw_uc3)
-- Package/owner: D - Yutong Geng
-- Purpose:       UC2 medication adherence: PDC per golden patient and drug class.
-- Reads:         cleansed.dispense, cleansed.patient_source_link,
--                cleansed.patient_master, raw.pharm_medication,
--                reporting.rule_parameter.
-- Writes:        reporting.vw_uc2_pdc (view).
-- Design link:   Build Plan v2 section 5.5; business_rules_v1.docx UC2;
--                Remediation Plan v3 card D-4.
-- Run after:      04_cleansed_standardise.sql, 05_identity_resolution.sql.
-- Re-runnable:    Yes (CREATE OR REPLACE VIEW).
--
-- Rule summary (all dates/lengths come from reporting.rule_parameter):
--   window_end   = as_of_date - 1 day
--   window_start = as_of_date - pdc_window_days        (5 Mar 2026 .. 31 Aug 2026)
--   eligible     = at least 2 fills of the class dispensed from
--                  window_start - 90 days to window_end (5 Dec 2025 .. 31 Aug 2026)
--   a fill covers dispensed_date .. dispensed_date + days_supply - 1
--   pdc          = distinct covered days inside the window / pdc_window_days, 3 decimals
--   pdc < pdc_threshold -> NON_ADHERENT, else ADHERENT
-- Only LINKED PHARM records count (unlinked pharmacy customers are excluded).
-- The 90-day look-back is the number written in the business rules; it is
-- not one of the nine rule_parameter rows.

CREATE OR REPLACE VIEW reporting.vw_uc2_pdc AS
WITH params AS (
    SELECT
        (SELECT param_value::date    FROM reporting.rule_parameter WHERE param_name = 'as_of_date')       AS as_of_date,
        (SELECT param_value::integer FROM reporting.rule_parameter WHERE param_name = 'pdc_window_days')  AS window_days,
        (SELECT param_value::numeric FROM reporting.rule_parameter WHERE param_name = 'pdc_threshold')    AS pdc_threshold
),
win AS (
    SELECT
        as_of_date,
        window_days,
        pdc_threshold,
        as_of_date - window_days            AS window_start,
        as_of_date - 1                      AS window_end,
        as_of_date - window_days - 90       AS eligibility_start
    FROM params
),
fills AS (
    -- one row per dispensing event of a LINKED patient, with its drug class
    SELECT
        l.patient_id,
        m.drug_class,
        d.dispense_id,
        d.dispensed_date,
        d.days_supply
    FROM cleansed.dispense d
    JOIN cleansed.patient_source_link l
      ON l.source_system = 'PHARM'
     AND l.source_patient_id = d.pharmacy_patient_id
     AND l.match_status = 'LINKED'
    JOIN raw.pharm_medication m
      ON m.pbs_item_code = d.pbs_item_code
    WHERE m.drug_class IN ('biguanide', 'sulfonylurea', 'DPP-4 inhibitor')
),
fill_counts AS (
    SELECT f.patient_id, f.drug_class, count(*) AS fills_counted
    FROM fills f
    CROSS JOIN win w
    WHERE f.dispensed_date BETWEEN w.eligibility_start AND w.window_end
    GROUP BY f.patient_id, f.drug_class
),
covered AS (
    -- every day covered by any fill, kept only if inside the window;
    -- DISTINCT so overlapping fills count a day once
    SELECT DISTINCT
        f.patient_id,
        f.drug_class,
        gs.day::date AS covered_day
    FROM fills f
    CROSS JOIN win w
    CROSS JOIN LATERAL generate_series(
        f.dispensed_date,
        f.dispensed_date + f.days_supply - 1,
        interval '1 day'
    ) AS gs(day)
    WHERE gs.day::date BETWEEN w.window_start AND w.window_end
),
covered_days AS (
    SELECT patient_id, drug_class, count(*) AS covered_days
    FROM covered
    GROUP BY patient_id, drug_class
)
SELECT
    fc.patient_id,
    initcap(lower(pm.given_name || ' ' || pm.family_name))          AS display_name,
    fc.drug_class,
    fc.fills_counted,
    COALESCE(cd.covered_days, 0)                                      AS covered_days,
    w.window_days,
    round(COALESCE(cd.covered_days, 0)::numeric / w.window_days, 3)   AS pdc,
    CASE
        WHEN round(COALESCE(cd.covered_days, 0)::numeric / w.window_days, 3) < w.pdc_threshold
        THEN 'NON_ADHERENT' ELSE 'ADHERENT'
    END                                                               AS adherence_status,
    w.window_start,
    w.window_end,
    w.as_of_date
FROM fill_counts fc
CROSS JOIN win w
JOIN cleansed.patient_master pm ON pm.patient_id = fc.patient_id
LEFT JOIN covered_days cd
       ON cd.patient_id = fc.patient_id AND cd.drug_class = fc.drug_class
WHERE fc.fills_counted >= 2;

COMMENT ON VIEW reporting.vw_uc2_pdc
IS 'UC2: PDC medication adherence per golden patient and drug class. Rules in business_rules_v1.docx; parameters from reporting.rule_parameter.';

-- ===================== Acceptance check (card D-4) =====================
-- Expect 11 rows; NON_ADHERENT 2 (GL-0002 0.333, GL-0010 0.500), ADHERENT 9:
-- GL-0001 0.989, GL-0003 0.978, GL-0005 0.972, GL-0007 1.000 (sulfonylurea),
-- GL-0008 0.978, GL-0009 1.000, GL-0012 0.972, GL-0016 1.000, GL-0017 0.917.
SELECT patient_id, display_name, drug_class, fills_counted, covered_days, pdc, adherence_status
FROM reporting.vw_uc2_pdc
ORDER BY patient_id;
