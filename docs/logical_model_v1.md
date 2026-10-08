# GlucoLink logical model

Database: glucolink_a2. Maintainer: Zhihao Zhang (B). Updated 8 October 2026.

The model covers 47 tables/views and 339 columns. Use the detailed schema pages for report (v)c. They show every column, type, key and nullability, with a line for each declared or planned FK. The overview shows data flow.

## Notation

PK = primary key, FK = foreign key, UQ = unique, REF = logical reference. Solid relationship lines correspond to enforced FKs. Dashed lines show planned relationships. Circle = zero, bar = one, crow foot = many. ? means physical nullability awaits the owning SQL. Views have no PK/FK. The arrow from UC2 to UC3 denotes the best-PDC dependency.

## Detailed pages
- [src_gp](logical_model_detail_src_gp.png)
- [src_lab](logical_model_detail_src_lab.png)
- [src_pharm](logical_model_detail_src_pharm.png)
- [raw](logical_model_detail_raw.png)
- [cleansed](logical_model_detail_cleansed.png)
- [curated](logical_model_detail_curated.png)
- [reporting](logical_model_detail_reporting.png)
- [audit](logical_model_detail_audit.png)

## Relationships

|Parent|Child column|Meaning|
|---|---|---|
|src_gp.gp_patient(gp_patient_id)|src_gp.encounter.gp_patient_id|Enforced FK|
|src_gp.clinic(clinic_id)|src_gp.encounter.clinic_id|Enforced FK|
|src_gp.clinic(clinic_id)|src_gp.gp_patient.clinic_id|Enforced FK|
|src_lab.laboratory(lab_id)|src_lab.observation_message.lab_id|Enforced FK|
|src_lab.lab_patient(lab_patient_id)|src_lab.observation_message.lab_patient_id|Enforced FK|
|src_lab.observation_message(message_id)|src_lab.result_delivery.message_id|Enforced FK|
|src_pharm.pharmacy_patient(pharmacy_patient_id)|src_pharm.dispense.pharmacy_patient_id|Enforced FK|
|src_pharm.pharmacy(pharmacy_id)|src_pharm.dispense.pharmacy_id|Enforced FK|
|src_pharm.medication(pbs_item_code)|src_pharm.dispense.pbs_item_code|Enforced FK|
|src_pharm.pharmacy(pharmacy_id)|src_pharm.pharmacy_patient.pharmacy_id|Enforced FK|
|curated.dim_clinic(clinic_key)|curated.dim_patient.home_clinic_key|Enforced FK|
|curated.dim_patient(patient_key)|curated.fact_encounter.patient_key|Logical / planned FK|
|curated.dim_date(date_key)|curated.fact_encounter.date_key|Logical / planned FK|
|curated.dim_clinic(clinic_key)|curated.fact_encounter.clinic_key|Logical / planned FK|
|curated.dim_patient(patient_key)|curated.fact_lab_result.patient_key|Logical / planned FK|
|curated.dim_date(date_key)|curated.fact_lab_result.collected_date_key|Logical / planned FK|
|curated.dim_date(date_key)|curated.fact_lab_result.reported_date_key|Logical / planned FK|
|curated.dim_lab(lab_key)|curated.fact_lab_result.lab_key|Logical / planned FK|
|curated.dim_test(test_key)|curated.fact_lab_result.test_key|Logical / planned FK|
|curated.dim_patient(patient_key)|curated.fact_dispense.patient_key|Logical / planned FK|
|curated.dim_date(date_key)|curated.fact_dispense.date_key|Logical / planned FK|
|curated.dim_pharmacy(pharmacy_key)|curated.fact_dispense.pharmacy_key|Logical / planned FK|
|curated.dim_medication(medication_key)|curated.fact_dispense.medication_key|Logical / planned FK|
|cleansed.patient_master(patient_id)|cleansed.patient_source_link.patient_id|Logical / planned FK|

## Layer boundaries

Source data flows through RAW to CLEANSED. CURATED reads RAW reference data and CLEANSED events. CLEANSED encounter/dispense have no FK back to source tables. UC1–UC4 read CURATED and shared parameters; UC3 also reads UC2. UC4 uses fact_lab_result.result_returned_flag. audit.identity_truth is an evaluation answer key and never feeds matching.

Implementation differences and final checks are in [data_dictionary_v1.md](data_dictionary_v1.md). No teammate SQL is changed by this model.