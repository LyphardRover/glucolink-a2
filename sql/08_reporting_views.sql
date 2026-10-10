-- File: sql/08_reporting_views.sql
-- Owner: Shuo Ding (E). Package E contribution: UC1 and UC3 ONLY.
-- Rules: docs/business_rules_v1.2.docx; task card E-4.
-- Reads: curated dimensions/facts, reporting.rule_parameter,
--        reporting.vw_uc2_pdc (owned by Yutong, D).
-- Writes: reporting.vw_uc1_care_gaps, reporting.vw_uc3_hba1c_trend.
-- Rebuild order: 06 -> 07 -> 08_vw_uc2_pdc.sql -> this file.
-- When consolidating all views into this file, insert D's UC2 block before UC3
-- and retain D's UC4 block. This contribution does not implement or replace UC2/UC4.
-- Uses CREATE OR REPLACE VIEW; no source data is modified.
-- 10 Oct coordination: upload to GitHub; leader performs the shared DB rebuild.

BEGIN;

DO $$
DECLARE missing_parameters text;
BEGIN
    IF to_regclass('reporting.vw_uc2_pdc') IS NULL THEN
        RAISE EXCEPTION 'UC2 is required: run 08_vw_uc2_pdc.sql before 08_reporting_views.sql.';
    END IF;
    SELECT string_agg(r.name, ', ' ORDER BY r.name) INTO missing_parameters
    FROM (VALUES ('as_of_date'), ('test_overdue_months'), ('hba1c_high_mmol'),
                 ('review_window_days'), ('trend_window_months'),
                 ('trend_min_change_mmol'), ('pdc_threshold')) r(name)
    LEFT JOIN reporting.rule_parameter p ON p.param_name = r.name
    WHERE nullif(btrim(p.param_value), '') IS NULL;
    IF missing_parameters IS NOT NULL THEN
        RAISE EXCEPTION 'Missing reporting parameters: %', missing_parameters;
    END IF;
END $$;

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

COMMIT;
