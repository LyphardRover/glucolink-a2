-- File: sql/08_reporting_views.sql
-- Owner: E (Shuo Ding) for UC1 and UC3; D (Yutong Geng) for UC2 and UC4.
-- Rules: docs/business_rules_v1.2.docx; task cards D-4 and E-4.
-- Reads: curated dimensions/facts, reporting.rule_parameter.
-- Writes: reporting.vw_uc2_pdc, vw_uc1_care_gaps, vw_uc3_hba1c_trend,
--         vw_uc4_care_path_breaks.
-- Rebuild order: 06 -> 07 -> this file (UC2 is created before UC3 inside it;
--                the separate 08_vw_uc2_pdc.sql is no longer needed).
-- 07 uses DROP ... CASCADE, so always re-run this whole file after 07.
-- Uses CREATE OR REPLACE VIEW; no source data is modified.

BEGIN;

DO $$
DECLARE missing_parameters text;
BEGIN
    SELECT string_agg(r.name, ', ' ORDER BY r.name) INTO missing_parameters
    FROM (VALUES ('as_of_date'), ('test_overdue_months'), ('hba1c_high_mmol'),
                 ('review_window_days'), ('trend_window_months'),
                 ('trend_min_change_mmol'), ('pdc_threshold'),
                 ('pdc_window_days'), ('return_grace_days')) r(name)
    LEFT JOIN reporting.rule_parameter p ON p.param_name = r.name
    WHERE nullif(btrim(p.param_value), '') IS NULL;
    IF missing_parameters IS NOT NULL THEN
        RAISE EXCEPTION 'Missing reporting parameters: %', missing_parameters;
    END IF;
END $$;

-- ======================= vw_uc2_pdc =======================
-- window_end = as_of - 1; window_start = as_of - pdc_window_days;
-- eligible = >= 2 fills of the class dispensed from window_start - 90 days
-- to window_end; a fill covers dispensed_date .. +days_supply-1;
-- pdc = distinct covered days in window / pdc_window_days (3 dp);
-- pdc < pdc_threshold -> NON_ADHERENT. Only LINKED patients exist in the facts.
-- The 90-day look-back is the number in the business rules, not a parameter row.
CREATE OR REPLACE VIEW reporting.vw_uc2_pdc AS
WITH params AS (
    SELECT
        (SELECT param_value::date    FROM reporting.rule_parameter WHERE param_name = 'as_of_date')      AS as_of_date,
        (SELECT param_value::integer FROM reporting.rule_parameter WHERE param_name = 'pdc_window_days') AS window_days,
        (SELECT param_value::numeric FROM reporting.rule_parameter WHERE param_name = 'pdc_threshold')   AS pdc_threshold
),
win AS (
    SELECT as_of_date, window_days, pdc_threshold,
           as_of_date - window_days      AS window_start,
           as_of_date - 1                AS window_end,
           as_of_date - window_days - 90 AS eligibility_start
    FROM params
),
fills AS (
    SELECT f.patient_key, m.drug_class, f.dispense_id,
           d.full_date AS dispensed_date, f.days_supply
    FROM curated.fact_dispense f
    JOIN curated.dim_date d       ON d.date_key = f.date_key
    JOIN curated.dim_medication m ON m.medication_key = f.medication_key
    WHERE m.drug_class IN ('biguanide', 'sulfonylurea', 'DPP-4 inhibitor')
),
fill_counts AS (
    SELECT f.patient_key, f.drug_class, count(*) AS fills_counted
    FROM fills f CROSS JOIN win w
    WHERE f.dispensed_date BETWEEN w.eligibility_start AND w.window_end
    GROUP BY f.patient_key, f.drug_class
),
covered AS (
    -- DISTINCT so overlapping fills count a calendar day once
    SELECT DISTINCT f.patient_key, f.drug_class, gs.day::date AS covered_day
    FROM fills f CROSS JOIN win w
    CROSS JOIN LATERAL generate_series(
        f.dispensed_date, f.dispensed_date + f.days_supply - 1, interval '1 day'
    ) AS gs(day)
    WHERE gs.day::date BETWEEN w.window_start AND w.window_end
),
covered_days AS (
    SELECT patient_key, drug_class, count(*) AS covered_days
    FROM covered GROUP BY patient_key, drug_class
)
SELECT
    p.patient_id,
    p.display_name,
    fc.drug_class,
    fc.fills_counted,
    COALESCE(cd.covered_days, 0)                                    AS covered_days,
    w.window_days,
    round(COALESCE(cd.covered_days, 0)::numeric / w.window_days, 3) AS pdc,
    CASE WHEN round(COALESCE(cd.covered_days, 0)::numeric / w.window_days, 3) < w.pdc_threshold
         THEN 'NON_ADHERENT' ELSE 'ADHERENT' END                    AS adherence_status,
    w.window_start,
    w.window_end,
    w.as_of_date
FROM fill_counts fc
CROSS JOIN win w
JOIN curated.dim_patient p ON p.patient_key = fc.patient_key
LEFT JOIN covered_days cd
       ON cd.patient_key = fc.patient_key AND cd.drug_class = fc.drug_class
WHERE fc.fills_counted >= 2;

COMMENT ON VIEW reporting.vw_uc2_pdc
IS 'UC2: PDC medication adherence per golden patient and drug class. Parameters from reporting.rule_parameter.';

-- UC1: latest eligible result across all history, not just the overdue window.
CREATE OR REPLACE VIEW reporting.vw_uc1_care_gaps AS
WITH params AS (
    SELECT
        (SELECT param_value::date FROM reporting.rule_parameter WHERE param_name = 'as_of_date') AS as_of_date,
        (SELECT param_value::integer FROM reporting.rule_parameter WHERE param_name = 'test_overdue_months') AS overdue_months,
        (SELECT param_value::numeric FROM reporting.rule_parameter WHERE param_name = 'hba1c_high_mmol') AS high_mmol,
        (SELECT param_value::integer FROM reporting.rule_parameter WHERE param_name = 'review_window_days') AS review_days
), assessed AS (
    SELECT p.patient_id, p.display_name, c.clinic_name AS home_clinic,
           l.collected_date AS last_test_date,
           l.hba1c_mmol_mol AS last_hba1c_mmol_mol,
           rv.first_review_date,
           CASE
               WHEN l.message_id IS NULL THEN 'NO_TEST_ON_RECORD'
               WHEN l.collected_date < (r.as_of_date - make_interval(months => r.overdue_months))::date
                   THEN 'OVERDUE_TEST'
               WHEN l.hba1c_mmol_mol >= r.high_mmol AND rv.first_review_date IS NULL
                   THEN CASE WHEN l.collected_date + r.review_days <= r.as_of_date
                             THEN 'HIGH_NO_REVIEW' ELSE 'HIGH_REVIEW_PENDING' END
               ELSE NULL
           END AS care_gap_status,
           r.as_of_date
    FROM curated.dim_patient p
    CROSS JOIN params r
    LEFT JOIN curated.dim_clinic c ON c.clinic_key = p.home_clinic_key
    LEFT JOIN LATERAL (
        SELECT f.message_id, f.hba1c_mmol_mol, cd.full_date AS collected_date
        FROM curated.fact_lab_result f
        JOIN curated.dim_date cd ON cd.date_key = f.collected_date_key
        JOIN curated.dim_date rd ON rd.date_key = f.reported_date_key
        WHERE f.patient_key = p.patient_key AND cd.full_date <= r.as_of_date
        ORDER BY cd.full_date DESC, rd.full_date DESC, f.message_id DESC
        LIMIT 1
    ) l ON true
    LEFT JOIN LATERAL (
        SELECT min(d.full_date) AS first_review_date
        FROM curated.fact_encounter e
        JOIN curated.dim_date d ON d.date_key = e.date_key
        WHERE e.patient_key = p.patient_key
          AND (e.medication_review_flag IS TRUE OR e.care_plan_flag IS TRUE)
          AND d.full_date > l.collected_date
          AND d.full_date <= l.collected_date + r.review_days
          AND d.full_date <= r.as_of_date
    ) rv ON true
)
SELECT patient_id, display_name, home_clinic, last_test_date,
       last_hba1c_mmol_mol, first_review_date, care_gap_status, as_of_date
FROM assessed
WHERE care_gap_status IS NOT NULL;

COMMENT ON VIEW reporting.vw_uc1_care_gaps IS
'UC1: one row per golden patient with a care gap or pending high-result review; business_rules_v1.2. Dates and VALID/LINKED eligibility inherited from CURATED.';

-- UC3: lower date boundary is exclusive; upper boundary is inclusive.
-- Same-day observations remain separate results. Report date/message ID break ties.
CREATE OR REPLACE VIEW reporting.vw_uc3_hba1c_trend AS
WITH params AS (
    SELECT
        (SELECT param_value::date FROM reporting.rule_parameter WHERE param_name = 'as_of_date') AS as_of_date,
        (SELECT param_value::integer FROM reporting.rule_parameter WHERE param_name = 'trend_window_months') AS trend_months,
        (SELECT param_value::numeric FROM reporting.rule_parameter WHERE param_name = 'trend_min_change_mmol') AS min_change,
        (SELECT param_value::numeric FROM reporting.rule_parameter WHERE param_name = 'pdc_threshold') AS pdc_threshold
), ranked AS (
    SELECT f.patient_key, cd.full_date AS collected_date, f.hba1c_mmol_mol,
           count(*) OVER (PARTITION BY f.patient_key) AS n_results,
           row_number() OVER (PARTITION BY f.patient_key ORDER BY cd.full_date, rd.full_date, f.message_id) AS first_rank,
           row_number() OVER (PARTITION BY f.patient_key ORDER BY cd.full_date DESC, rd.full_date DESC, f.message_id DESC) AS last_rank
    FROM curated.fact_lab_result f
    JOIN curated.dim_date cd ON cd.date_key = f.collected_date_key
    JOIN curated.dim_date rd ON rd.date_key = f.reported_date_key
    CROSS JOIN params r
    WHERE cd.full_date > (r.as_of_date - make_interval(months => r.trend_months))::date
      AND cd.full_date <= r.as_of_date
), endpoints AS (
    SELECT patient_key, max(n_results) AS n_results,
           max(collected_date) FILTER (WHERE first_rank = 1) AS first_test_date,
           max(hba1c_mmol_mol) FILTER (WHERE first_rank = 1) AS first_hba1c,
           max(collected_date) FILTER (WHERE last_rank = 1) AS last_test_date,
           max(hba1c_mmol_mol) FILTER (WHERE last_rank = 1) AS last_hba1c
    FROM ranked GROUP BY patient_key
), changes AS (
    SELECT e.*, CASE WHEN n_results >= 2 THEN last_hba1c - first_hba1c ELSE NULL END AS change_mmol_mol
    FROM endpoints e
), classified AS (
    SELECT e.*, r.as_of_date, r.pdc_threshold,
           CASE WHEN n_results < 2 THEN 'INSUFFICIENT_HISTORY'
                WHEN change_mmol_mol >= r.min_change THEN 'RISING'
                WHEN change_mmol_mol <= -r.min_change THEN 'FALLING'
                ELSE 'STABLE' END AS trend_status
    FROM changes e CROSS JOIN params r
), best_adherence AS (
    SELECT patient_id, max(pdc) AS best_pdc
    FROM reporting.vw_uc2_pdc GROUP BY patient_id
)
SELECT p.patient_id, p.display_name, e.n_results,
       e.first_test_date, e.first_hba1c, e.last_test_date, e.last_hba1c,
       e.change_mmol_mol, e.trend_status, b.best_pdc,
       coalesce(e.trend_status = 'RISING' AND b.best_pdc >= e.pdc_threshold, false) AS rising_despite_adherence,
       e.as_of_date
FROM classified e
JOIN curated.dim_patient p ON p.patient_key = e.patient_key
LEFT JOIN best_adherence b ON b.patient_id = p.patient_id;

COMMENT ON VIEW reporting.vw_uc3_hba1c_trend IS
'UC3: parameterised HbA1c trend over (as_of_date - trend_window_months, as_of_date]; best PDC across UC2 drug classes; no PDC gives a false adherence flag. business_rules_v1.2.';

-- ================= vw_uc4_care_path_breaks =================
-- (a) RESULT_NOT_RETURNED: VALID result (only VALID rows are in the fact) with
--     result_returned_flag = false, reported at least return_grace_days before
--     as_of_date.
-- (b) MULTI_PHARMACY_OVERLAP: same patient and drug class supplied by two
--     pharmacies in overlapping supply periods; ONE row per patient, drug
--     class and pharmacy pair (pharmacy_a < pharmacy_b).
CREATE OR REPLACE VIEW reporting.vw_uc4_care_path_breaks AS
WITH params AS (
    SELECT
        (SELECT param_value::date    FROM reporting.rule_parameter WHERE param_name = 'as_of_date')         AS as_of_date,
        (SELECT param_value::integer FROM reporting.rule_parameter WHERE param_name = 'return_grace_days')  AS grace_days
),
not_returned AS (
    SELECT p.patient_id,
           p.display_name,
           'RESULT_NOT_RETURNED'::text AS break_type,
           ('Result ' || f.observation_id || ' reported ' || rd.full_date
            || ' has no delivery record to a clinic')::text AS detail,
           rd.full_date AS event_date
    FROM curated.fact_lab_result f
    JOIN curated.dim_patient p ON p.patient_key = f.patient_key
    JOIN curated.dim_date rd   ON rd.date_key = f.reported_date_key
    CROSS JOIN params x
    WHERE f.result_returned_flag = false
      AND rd.full_date <= x.as_of_date - x.grace_days
),
fills AS (
    SELECT f.patient_key, m.drug_class, h.pharmacy_id,
           d.full_date AS start_date,
           d.full_date + f.days_supply - 1 AS end_date
    FROM curated.fact_dispense f
    JOIN curated.dim_date d       ON d.date_key = f.date_key
    JOIN curated.dim_medication m ON m.medication_key = f.medication_key
    JOIN curated.dim_pharmacy h   ON h.pharmacy_key = f.pharmacy_key
),
overlap_pairs AS (
    SELECT a.patient_key, a.drug_class,
           a.pharmacy_id AS pharmacy_a, b.pharmacy_id AS pharmacy_b,
           min(greatest(a.start_date, b.start_date)) AS first_overlap_date,
           count(*) AS overlapping_fill_pairs
    FROM fills a
    JOIN fills b
      ON b.patient_key = a.patient_key
     AND b.drug_class  = a.drug_class
     AND a.pharmacy_id < b.pharmacy_id
     AND a.start_date <= b.end_date
     AND b.start_date <= a.end_date
    GROUP BY a.patient_key, a.drug_class, a.pharmacy_id, b.pharmacy_id
),
multi_pharmacy AS (
    SELECT p.patient_id,
           p.display_name,
           'MULTI_PHARMACY_OVERLAP'::text AS break_type,
           (o.drug_class || ' supplied by pharmacies ' || o.pharmacy_a || ' and '
            || o.pharmacy_b || ' with overlapping supply from ' || o.first_overlap_date)::text AS detail,
           o.first_overlap_date AS event_date
    FROM overlap_pairs o
    JOIN curated.dim_patient p ON p.patient_key = o.patient_key
)
SELECT patient_id, display_name, break_type, detail, event_date FROM not_returned
UNION ALL
SELECT patient_id, display_name, break_type, detail, event_date FROM multi_pharmacy;

COMMENT ON VIEW reporting.vw_uc4_care_path_breaks
IS 'UC4: care-path breaks - unreturned VALID results and multi-pharmacy overlaps. Parameters from reporting.rule_parameter.';

COMMIT;
