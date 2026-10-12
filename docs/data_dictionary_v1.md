# GlucoLink data dictionary

Database: glucolink_a2. Maintainer: Zhihao Zhang (Package B). Updated 11 October 2026.

## Reading the model

All 47 objects (43 tables and four views) and 338 columns are implemented and verified against the rebuilt test database catalog. The 24 foreign keys are enforced. Source: main 9a499ce4c1564dfdc06e5a521d714d6728337332; glucolink_a2_test rebuilt and rerun on 11 October 2026. Both 00–09 runs passed 46/46 tests.

There are no remaining planned objects in this dictionary. Views have no primary or foreign key constraints. Yes/No is nullability from the live catalog; PostgreSQL view metadata does not infer every non-null result expression. Defaults include identity, sequence and generated-column definitions.

Owner identifies the work package, not a database login. C owns source and RAW definitions; B supplies lab message data and common setup. D owns CLEANSED and UC2/UC4; E owns CURATED and UC1/UC3; F owns test results and Excel charts.

## Object index

|Object|One row represents|Owner|Columns|
|---|---|---|---|
|src_gp.clinic|One GP clinic.|C|4|
|src_gp.encounter|One GP encounter.|C|8|
|src_gp.gp_patient|One GP registration, not necessarily one real person.|C|9|
|src_lab.lab_patient|One laboratory patient record.|C|5|
|src_lab.laboratory|One laboratory.|C|3|
|src_lab.observation_message|One received FHIR Observation message; duplicate clinical events remain separate messages.|B / C|5|
|src_lab.result_delivery|One recorded delivery of a message to a clinic.|B / C|4|
|src_pharm.dispense|One dispensing event.|C|7|
|src_pharm.medication|One PBS medication item.|C|6|
|src_pharm.pharmacy|One pharmacy.|C|3|
|src_pharm.pharmacy_patient|One pharmacy patient registration.|C|6|
|raw.gp_clinic|One unchanged source row from src_gp.clinic.|C|8|
|raw.gp_encounter|One unchanged source row from src_gp.encounter.|C|12|
|raw.gp_patient|One unchanged source row from src_gp.gp_patient.|C|13|
|raw.lab_delivery|One unchanged source row from src_lab.result_delivery.|C|8|
|raw.lab_laboratory|One unchanged source row from src_lab.laboratory.|C|7|
|raw.lab_observation|One unchanged source row from src_lab.observation_message.|C|9|
|raw.lab_patient|One unchanged source row from src_lab.lab_patient.|C|9|
|raw.pharm_dispense|One unchanged source row from src_pharm.dispense.|C|11|
|raw.pharm_medication|One unchanged source row from src_pharm.medication.|C|10|
|raw.pharm_patient|One unchanged source row from src_pharm.pharmacy_patient.|C|10|
|raw.pharm_pharmacy|One unchanged source row from src_pharm.pharmacy.|C|7|
|cleansed.dispense|One typed source dispense event.|D|7|
|cleansed.dq_issue|One recorded data-quality issue; several may refer to a record.|D|5|
|cleansed.encounter|One typed source encounter event.|D|8|
|cleansed.lab_result|One parsed message including DQ-rejected and duplicate messages (target 36).|D|14|
|cleansed.patient_master|One canonical GP-anchored person (target 17).|D|6|
|cleansed.patient_record|One standardised source patient record; source system and source ID distinguish identities.|D|8|
|cleansed.patient_source_link|One resolution decision for a source patient (target 48).|D|6|
|curated.dim_clinic|One clinic dimension member.|E|5|
|curated.dim_date|One date dimension member.|E|7|
|curated.dim_lab|One lab dimension member.|E|4|
|curated.dim_medication|One medication dimension member.|E|7|
|curated.dim_patient|One canonical patient.|E|6|
|curated.dim_pharmacy|One pharmacy dimension member.|E|4|
|curated.dim_test|One test dimension member.|E|4|
|curated.fact_dispense|One LINKED dispense; target 65.|E|8|
|curated.fact_encounter|One LINKED encounter; target 28.|E|9|
|curated.fact_lab_result|One VALID result linked to a canonical patient; target 32.|E|10|
|reporting.rule_parameter|One named business-rule parameter.|B|3|
|reporting.vw_uc1_care_gaps|One golden patient with a care gap or a pending high-result review; expected 8 rows.|E|8|
|reporting.vw_uc2_pdc|One eligible golden patient and drug class; expected 11 rows.|D|11|
|reporting.vw_uc3_hba1c_trend|One golden patient with at least one VALID result in the 12-month trend window; expected 16 rows.|E|12|
|reporting.vw_uc4_care_path_breaks|One unreturned VALID result, or one patient/drug-class/pair-of-pharmacies overlap; expected 2 rows.|D|5|
|audit.identity_truth|One synthetic source identity answer-key row; 48 rows. Used only to evaluate matching.|C|3|
|audit.pipeline_run|One explicitly logged pipeline execution.|B / C|9|
|audit.test_result|One acceptance-test result; history/key policy awaits F.|F|5|

## src_gp.clinic

**Owner:** C. **Grain:** One GP clinic.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|clinic_id|integer|PRIMARY KEY (clinic_id)|No|—|Source GP clinic identifier|
|clinic_name|text|—|Yes|—|GP clinic name|
|suburb|text|—|Yes|—|Source suburb text|
|postcode|text|—|Yes|—|Postal code kept as text|

## src_gp.encounter

**Owner:** C. **Grain:** One GP encounter.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|encounter_id|text|PRIMARY KEY (encounter_id)|No|—|Source encounter identifier|
|gp_patient_id|text|FOREIGN KEY (gp_patient_id) REFERENCES src_gp.gp_patient(gp_patient_id)|Yes|—|GP registration identifier|
|clinic_id|integer|FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic(clinic_id)|Yes|—|Source GP clinic identifier|
|encounter_date|date|—|Yes|—|Date of the encounter|
|encounter_type|text|—|Yes|—|STANDARD, CARE_PLAN or MEDICATION_REVIEW|
|diagnosis_code|text|—|Yes|—|Recorded diagnosis code|
|medication_review_flag|boolean|—|Yes|—|Whether the event is a medication review|
|care_plan_flag|boolean|—|Yes|—|Whether the event is a care-plan event|

## src_gp.gp_patient

**Owner:** C. **Grain:** One GP registration, not necessarily one real person.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|gp_patient_id|text|PRIMARY KEY (gp_patient_id)|No|—|GP registration identifier|
|first_name|text|—|Yes|—|Source given name|
|last_name|text|—|Yes|—|Source family name|
|dob|date|—|Yes|—|Date of birth.|
|sex|character(1)|—|Yes|—|Recorded sex code; do not infer missing values|
|postcode|text|—|Yes|—|Postal code kept as text|
|medicare_number|text|—|Yes|—|Unnormalised source Medicare value, including deliberate defects|
|clinic_id|integer|FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic(clinic_id)|Yes|—|Source GP clinic identifier|
|enrolment_date|date|—|Yes|—|GP registration date|

## src_lab.lab_patient

**Owner:** C. **Grain:** One laboratory patient record.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|lab_patient_id|text|PRIMARY KEY (lab_patient_id)|No|—|Laboratory-local patient identifier|
|patient_name|text|—|Yes|—|Original SURNAME, Given M name|
|dob|text|—|Yes|—|Date of birth as received (DD/MM/YYYY text).|
|sex|character(1)|—|Yes|—|Recorded sex code; do not infer missing values|
|medicare_number|text|—|Yes|—|Unnormalised source Medicare value, including deliberate defects|

## src_lab.laboratory

**Owner:** C. **Grain:** One laboratory.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|lab_id|integer|PRIMARY KEY (lab_id)|No|—|Source laboratory identifier|
|lab_name|text|—|Yes|—|Laboratory name|
|reporting_unit|text|—|Yes|—|Laboratory reference reporting unit|

## src_lab.observation_message

**Owner:** B / C. **Grain:** One received FHIR Observation message; duplicate clinical events remain separate messages.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|message_id|text|PRIMARY KEY (message_id)|No|—|Transport/message identifier; distinct from observation_id|
|lab_id|integer|FOREIGN KEY (lab_id) REFERENCES src_lab.laboratory(lab_id)|Yes|—|Source laboratory identifier|
|lab_patient_id|text|FOREIGN KEY (lab_patient_id) REFERENCES src_lab.lab_patient(lab_patient_id)|Yes|—|Laboratory-local patient identifier|
|received_at|timestamp with time zone|—|Yes|—|Instant the Observation message was received|
|fhir_json|jsonb|—|Yes|—|Original synthetic FHIR R4 Observation JSON|

## src_lab.result_delivery

**Owner:** B / C. **Grain:** One recorded delivery of a message to a clinic.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|delivery_id|text|PRIMARY KEY (delivery_id)|No|—|Delivery-event identifier|
|message_id|text|FOREIGN KEY (message_id) REFERENCES src_lab.observation_message(message_id)|Yes|—|Transport/message identifier; distinct from observation_id|
|clinic_id|integer|—|Yes|—|Source GP clinic identifier|
|delivered_at|timestamp with time zone|—|Yes|—|Instant the result was delivered to the clinic|

## src_pharm.dispense

**Owner:** C. **Grain:** One dispensing event.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|dispense_id|text|PRIMARY KEY (dispense_id)|No|—|Source dispensing-event identifier|
|pharmacy_patient_id|text|FOREIGN KEY (pharmacy_patient_id) REFERENCES src_pharm.pharmacy_patient(pharmacy_patient_id)|Yes|—|Pharmacy-local patient identifier|
|pharmacy_id|integer|FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy(pharmacy_id)|Yes|—|Source pharmacy identifier|
|pbs_item_code|text|FOREIGN KEY (pbs_item_code) REFERENCES src_pharm.medication(pbs_item_code)|Yes|—|PBS medication-item identifier|
|dispensed_date|date|—|Yes|—|Dispensing date|
|quantity|integer|—|Yes|—|Quantity dispensed|
|days_supply|integer|—|Yes|—|Days of supply for the dispensing event|

## src_pharm.medication

**Owner:** C. **Grain:** One PBS medication item.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|pbs_item_code|text|PRIMARY KEY (pbs_item_code)|No|—|PBS medication-item identifier|
|drug_name|text|—|Yes|—|Medication name|
|strength|text|—|Yes|—|Medication strength|
|pack_size|integer|—|Yes|—|Units in a medication pack|
|typical_daily_dose|numeric|—|Yes|—|Reference daily-dose quantity|
|drug_class|text|—|Yes|—|Medication class used for adherence grouping|

## src_pharm.pharmacy

**Owner:** C. **Grain:** One pharmacy.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|pharmacy_id|integer|PRIMARY KEY (pharmacy_id)|No|—|Source pharmacy identifier|
|pharmacy_name|text|—|Yes|—|Pharmacy name|
|suburb|text|—|Yes|—|Source suburb text|

## src_pharm.pharmacy_patient

**Owner:** C. **Grain:** One pharmacy patient registration.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|pharmacy_patient_id|text|PRIMARY KEY (pharmacy_patient_id)|No|—|Pharmacy-local patient identifier|
|given_name|text|—|Yes|—|Given-name component|
|surname|text|—|Yes|—|Original pharmacy surname|
|date_of_birth|text|—|Yes|—|Date of birth as received (DD-Mon-YY text).|
|medicare_number|text|—|Yes|—|Unnormalised source Medicare value, including deliberate defects|
|pharmacy_id|integer|FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy(pharmacy_id)|Yes|—|Source pharmacy identifier|

## raw.gp_clinic

**Owner:** C. **Grain:** One unchanged source row from src_gp.clinic.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|clinic_id|integer|—|Yes|—|Source GP clinic identifier|
|clinic_name|text|—|Yes|—|GP clinic name|
|suburb|text|—|Yes|—|Source suburb text|
|postcode|text|—|Yes|—|Postal code kept as text|
|_source_system|text|—|Yes|—|Origin system: GP, LAB or PHARM|
|_source_table|text|—|Yes|—|Originating source-table name|
|_pipeline_run_id|bigint|—|Yes|—|Ingestion run reference for traceability; not a RAW FK|
|_loaded_at|timestamp with time zone|—|Yes|—|Timestamp when the RAW row was loaded|

## raw.gp_encounter

**Owner:** C. **Grain:** One unchanged source row from src_gp.encounter.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|encounter_id|text|—|Yes|—|Source encounter identifier|
|gp_patient_id|text|—|Yes|—|GP registration identifier|
|clinic_id|integer|—|Yes|—|Source GP clinic identifier|
|encounter_date|date|—|Yes|—|Date of the encounter|
|encounter_type|text|—|Yes|—|STANDARD, CARE_PLAN or MEDICATION_REVIEW|
|diagnosis_code|text|—|Yes|—|Recorded diagnosis code|
|medication_review_flag|boolean|—|Yes|—|Whether the event is a medication review|
|care_plan_flag|boolean|—|Yes|—|Whether the event is a care-plan event|
|_source_system|text|—|Yes|—|Origin system: GP, LAB or PHARM|
|_source_table|text|—|Yes|—|Originating source-table name|
|_pipeline_run_id|bigint|—|Yes|—|Ingestion run reference for traceability; not a RAW FK|
|_loaded_at|timestamp with time zone|—|Yes|—|Timestamp when the RAW row was loaded|

## raw.gp_patient

**Owner:** C. **Grain:** One unchanged source row from src_gp.gp_patient.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|gp_patient_id|text|—|Yes|—|GP registration identifier|
|first_name|text|—|Yes|—|Source given name|
|last_name|text|—|Yes|—|Source family name|
|dob|date|—|Yes|—|Date of birth.|
|sex|character(1)|—|Yes|—|Recorded sex code; do not infer missing values|
|postcode|text|—|Yes|—|Postal code kept as text|
|medicare_number|text|—|Yes|—|Unnormalised source Medicare value, including deliberate defects|
|clinic_id|integer|—|Yes|—|Source GP clinic identifier|
|enrolment_date|date|—|Yes|—|GP registration date|
|_source_system|text|—|Yes|—|Origin system: GP, LAB or PHARM|
|_source_table|text|—|Yes|—|Originating source-table name|
|_pipeline_run_id|bigint|—|Yes|—|Ingestion run reference for traceability; not a RAW FK|
|_loaded_at|timestamp with time zone|—|Yes|—|Timestamp when the RAW row was loaded|

## raw.lab_delivery

**Owner:** C. **Grain:** One unchanged source row from src_lab.result_delivery.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|delivery_id|text|—|Yes|—|Delivery-event identifier|
|message_id|text|—|Yes|—|Transport/message identifier; distinct from observation_id|
|clinic_id|integer|—|Yes|—|Source GP clinic identifier|
|delivered_at|timestamp with time zone|—|Yes|—|Instant the result was delivered to the clinic|
|_source_system|text|—|Yes|—|Origin system: GP, LAB or PHARM|
|_source_table|text|—|Yes|—|Originating source-table name|
|_pipeline_run_id|bigint|—|Yes|—|Ingestion run reference for traceability; not a RAW FK|
|_loaded_at|timestamp with time zone|—|Yes|—|Timestamp when the RAW row was loaded|

## raw.lab_laboratory

**Owner:** C. **Grain:** One unchanged source row from src_lab.laboratory.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|lab_id|integer|—|Yes|—|Source laboratory identifier|
|lab_name|text|—|Yes|—|Laboratory name|
|reporting_unit|text|—|Yes|—|Laboratory reference reporting unit|
|_source_system|text|—|Yes|—|Origin system: GP, LAB or PHARM|
|_source_table|text|—|Yes|—|Originating source-table name|
|_pipeline_run_id|bigint|—|Yes|—|Ingestion run reference for traceability; not a RAW FK|
|_loaded_at|timestamp with time zone|—|Yes|—|Timestamp when the RAW row was loaded|

## raw.lab_observation

**Owner:** C. **Grain:** One unchanged source row from src_lab.observation_message.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|message_id|text|—|Yes|—|Transport/message identifier; distinct from observation_id|
|lab_id|integer|—|Yes|—|Source laboratory identifier|
|lab_patient_id|text|—|Yes|—|Laboratory-local patient identifier|
|received_at|timestamp with time zone|—|Yes|—|Instant the Observation message was received|
|fhir_json|jsonb|—|Yes|—|Original synthetic FHIR R4 Observation JSON|
|_source_system|text|—|Yes|—|Origin system: GP, LAB or PHARM|
|_source_table|text|—|Yes|—|Originating source-table name|
|_pipeline_run_id|bigint|—|Yes|—|Ingestion run reference for traceability; not a RAW FK|
|_loaded_at|timestamp with time zone|—|Yes|—|Timestamp when the RAW row was loaded|

## raw.lab_patient

**Owner:** C. **Grain:** One unchanged source row from src_lab.lab_patient.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|lab_patient_id|text|—|Yes|—|Laboratory-local patient identifier|
|patient_name|text|—|Yes|—|Original SURNAME, Given M name|
|dob|text|—|Yes|—|Date of birth as received (DD/MM/YYYY text).|
|sex|character(1)|—|Yes|—|Recorded sex code; do not infer missing values|
|medicare_number|text|—|Yes|—|Unnormalised source Medicare value, including deliberate defects|
|_source_system|text|—|Yes|—|Origin system: GP, LAB or PHARM|
|_source_table|text|—|Yes|—|Originating source-table name|
|_pipeline_run_id|bigint|—|Yes|—|Ingestion run reference for traceability; not a RAW FK|
|_loaded_at|timestamp with time zone|—|Yes|—|Timestamp when the RAW row was loaded|

## raw.pharm_dispense

**Owner:** C. **Grain:** One unchanged source row from src_pharm.dispense.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|dispense_id|text|—|Yes|—|Source dispensing-event identifier|
|pharmacy_patient_id|text|—|Yes|—|Pharmacy-local patient identifier|
|pharmacy_id|integer|—|Yes|—|Source pharmacy identifier|
|pbs_item_code|text|—|Yes|—|PBS medication-item identifier|
|dispensed_date|date|—|Yes|—|Dispensing date|
|quantity|integer|—|Yes|—|Quantity dispensed|
|days_supply|integer|—|Yes|—|Days of supply for the dispensing event|
|_source_system|text|—|Yes|—|Origin system: GP, LAB or PHARM|
|_source_table|text|—|Yes|—|Originating source-table name|
|_pipeline_run_id|bigint|—|Yes|—|Ingestion run reference for traceability; not a RAW FK|
|_loaded_at|timestamp with time zone|—|Yes|—|Timestamp when the RAW row was loaded|

## raw.pharm_medication

**Owner:** C. **Grain:** One unchanged source row from src_pharm.medication.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|pbs_item_code|text|—|Yes|—|PBS medication-item identifier|
|drug_name|text|—|Yes|—|Medication name|
|strength|text|—|Yes|—|Medication strength|
|pack_size|integer|—|Yes|—|Units in a medication pack|
|typical_daily_dose|numeric|—|Yes|—|Reference daily-dose quantity|
|drug_class|text|—|Yes|—|Medication class used for adherence grouping|
|_source_system|text|—|Yes|—|Origin system: GP, LAB or PHARM|
|_source_table|text|—|Yes|—|Originating source-table name|
|_pipeline_run_id|bigint|—|Yes|—|Ingestion run reference for traceability; not a RAW FK|
|_loaded_at|timestamp with time zone|—|Yes|—|Timestamp when the RAW row was loaded|

## raw.pharm_patient

**Owner:** C. **Grain:** One unchanged source row from src_pharm.pharmacy_patient.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|pharmacy_patient_id|text|—|Yes|—|Pharmacy-local patient identifier|
|given_name|text|—|Yes|—|Given-name component|
|surname|text|—|Yes|—|Original pharmacy surname|
|date_of_birth|text|—|Yes|—|Date of birth as received (DD-Mon-YY text).|
|medicare_number|text|—|Yes|—|Unnormalised source Medicare value, including deliberate defects|
|pharmacy_id|integer|—|Yes|—|Source pharmacy identifier|
|_source_system|text|—|Yes|—|Origin system: GP, LAB or PHARM|
|_source_table|text|—|Yes|—|Originating source-table name|
|_pipeline_run_id|bigint|—|Yes|—|Ingestion run reference for traceability; not a RAW FK|
|_loaded_at|timestamp with time zone|—|Yes|—|Timestamp when the RAW row was loaded|

## raw.pharm_pharmacy

**Owner:** C. **Grain:** One unchanged source row from src_pharm.pharmacy.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|pharmacy_id|integer|—|Yes|—|Source pharmacy identifier|
|pharmacy_name|text|—|Yes|—|Pharmacy name|
|suburb|text|—|Yes|—|Source suburb text|
|_source_system|text|—|Yes|—|Origin system: GP, LAB or PHARM|
|_source_table|text|—|Yes|—|Originating source-table name|
|_pipeline_run_id|bigint|—|Yes|—|Ingestion run reference for traceability; not a RAW FK|
|_loaded_at|timestamp with time zone|—|Yes|—|Timestamp when the RAW row was loaded|

## cleansed.dispense

**Owner:** D. **Grain:** One typed source dispense event.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|dispense_id|text|PRIMARY KEY (dispense_id)|No|—|Source dispensing-event identifier|
|pharmacy_patient_id|text|—|Yes|—|Pharmacy-local patient identifier|
|pharmacy_id|integer|—|Yes|—|Source pharmacy identifier|
|pbs_item_code|text|—|Yes|—|PBS medication-item identifier|
|dispensed_date|date|—|Yes|—|Dispensing date|
|quantity|integer|—|Yes|—|Quantity dispensed|
|days_supply|integer|—|Yes|—|Days of supply for the dispensing event|

## cleansed.dq_issue

**Owner:** D. **Grain:** One recorded data-quality issue; several may refer to a record.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|issue_id|bigint|PRIMARY KEY (issue_id)|No|nextval('cleansed.dq_issue_issue_id_seq'::regclass)|Automatically generated data-quality issue identifier|
|table_name|text|—|No|—|Table containing the affected record|
|record_id|text|—|No|—|Identifier of the affected record|
|rule|text|—|No|—|Violated data-quality rule|
|detail|text|—|Yes|—|Readable explanation of an issue or break|

## cleansed.encounter

**Owner:** D. **Grain:** One typed source encounter event.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|encounter_id|text|PRIMARY KEY (encounter_id)|No|—|Source encounter identifier|
|gp_patient_id|text|—|Yes|—|GP registration identifier|
|clinic_id|integer|—|Yes|—|Source GP clinic identifier|
|encounter_date|date|—|Yes|—|Date of the encounter|
|encounter_type|text|—|Yes|—|STANDARD, CARE_PLAN or MEDICATION_REVIEW|
|diagnosis_code|text|—|Yes|—|Recorded diagnosis code|
|medication_review_flag|boolean|—|Yes|—|Whether the event is a medication review|
|care_plan_flag|boolean|—|Yes|—|Whether the event is a care-plan event|

## cleansed.lab_result

**Owner:** D. **Grain:** One parsed message including DQ-rejected and duplicate messages (target 36).

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|message_id|text|PRIMARY KEY (message_id)|No|—|Transport/message identifier; distinct from observation_id|
|lab_id|integer|—|Yes|—|Source laboratory identifier|
|lab_patient_id|text|—|Yes|—|Laboratory-local patient identifier|
|observation_id|text|—|Yes|—|FHIR clinical observation identifier used for duplicate detection|
|status|text|—|Yes|—|FHIR Observation status|
|loinc_code|text|—|Yes|—|Laboratory test code|
|value_as_received|text|—|Yes|—|Original numeric value before unit conversion|
|unit_as_received|text|—|Yes|—|Original unit including deliberately empty units|
|hba1c_mmol_mol|numeric(6,1)|—|Yes|—|Converted value; NULL for invalid unit|
|collected_date|date|—|Yes|—|Sydney date from timestamp|
|reported_date|date|—|Yes|—|Sydney date from timestamp|
|returned_to_clinic_id|integer|—|Yes|—|Clinic recorded for result return, if any|
|returned_at|timestamp with time zone|—|Yes|—|Result-return timestamp, if any|
|dq_status|text|—|No|—|VALID / DUPLICATE / REJECTED_UNIT / FUTURE_DATE|

## cleansed.patient_master

**Owner:** D. **Grain:** One canonical GP-anchored person (target 17).

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|patient_id|text|PRIMARY KEY (patient_id)|No|—|Canonical GL patient identifier anchored in GP masters|
|given_name|text|—|Yes|—|Given-name component|
|family_name|text|—|Yes|—|Family-name component|
|dob|date|—|Yes|—|Date of birth.|
|sex|character(1)|—|Yes|—|Recorded sex code; do not infer missing values|
|medicare10|text|—|Yes|—|Valid normalised ten-digit Medicare identifier or NULL|

## cleansed.patient_record

**Owner:** D. **Grain:** One standardised source patient record; source system and source ID distinguish identities.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|source_system|text|PRIMARY KEY (source_system, source_patient_id)|No|—|GP, LAB or PHARM source label|
|source_patient_id|text|PRIMARY KEY (source_system, source_patient_id)|No|—|Identifier local to the named source|
|given_name|text|—|Yes|—|Given-name component|
|family_name|text|—|Yes|—|Family-name component|
|dob|date|—|Yes|—|Date of birth.|
|sex|character(1)|—|Yes|—|Recorded sex code; do not infer missing values|
|medicare10|text|—|Yes|—|Valid normalised ten-digit Medicare identifier or NULL|
|postcode|text|—|Yes|—|Postal code kept as text|

## cleansed.patient_source_link

**Owner:** D. **Grain:** One resolution decision for a source patient (target 48).

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|source_system|text|PRIMARY KEY (source_system, source_patient_id)|No|—|GP, LAB or PHARM source label|
|source_patient_id|text|PRIMARY KEY (source_system, source_patient_id)|No|—|Identifier local to the named source|
|patient_id|text|FOREIGN KEY (patient_id) REFERENCES cleansed.patient_master(patient_id)|Yes|—|Canonical GL patient identifier anchored in GP masters|
|match_status|text|—|No|—|LINKED / REVIEW / UNMATCHED|
|match_rule|text|—|Yes|—|GP, R1 or R2 for LINKED; NULL for REVIEW and UNMATCHED (business rules v1.2).|
|candidate_count|integer|—|No|—|Number of candidate golden patients considered by the matching rule.|

## curated.dim_clinic

**Owner:** E. **Grain:** One clinic dimension member.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|clinic_key|integer|PRIMARY KEY (clinic_key)|No|GENERATED BY DEFAULT AS IDENTITY|Surrogate clinic dimension key|
|clinic_id|integer|UNIQUE (clinic_id)|No|—|Source GP clinic identifier|
|clinic_name|text|—|Yes|—|GP clinic name|
|suburb|text|—|Yes|—|Source suburb text|
|postcode|text|—|Yes|—|Postal code kept as text|

## curated.dim_date

**Owner:** E. **Grain:** One date dimension member.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|date_key|integer|PRIMARY KEY (date_key)|No|—|Date dimension key for the event date|
|full_date|date|UNIQUE (full_date)|No|—|Calendar date represented by the member|
|day|integer|—|No|—|Day of month|
|month|integer|—|No|—|Month number|
|month_name|text|—|No|—|Month label|
|quarter|integer|—|No|—|Calendar quarter|
|year|integer|—|No|—|Calendar year|

## curated.dim_lab

**Owner:** E. **Grain:** One lab dimension member.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|lab_key|integer|PRIMARY KEY (lab_key)|No|GENERATED BY DEFAULT AS IDENTITY|Surrogate laboratory dimension key|
|lab_id|integer|UNIQUE (lab_id)|No|—|Source laboratory identifier|
|lab_name|text|—|Yes|—|Laboratory name|
|reporting_unit|text|—|Yes|—|Laboratory reference reporting unit|

## curated.dim_medication

**Owner:** E. **Grain:** One medication dimension member.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|medication_key|integer|PRIMARY KEY (medication_key)|No|GENERATED BY DEFAULT AS IDENTITY|Surrogate medication dimension key|
|pbs_item_code|text|UNIQUE (pbs_item_code)|No|—|PBS medication-item identifier|
|drug_name|text|—|Yes|—|Medication name|
|strength|text|—|Yes|—|Medication strength|
|pack_size|integer|—|Yes|—|Units in a medication pack|
|typical_daily_dose|numeric|—|Yes|—|Reference daily-dose quantity|
|drug_class|text|—|Yes|—|Medication class used for adherence grouping|

## curated.dim_patient

**Owner:** E. **Grain:** One canonical patient.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|patient_key|integer|PRIMARY KEY (patient_key)|No|GENERATED BY DEFAULT AS IDENTITY|Surrogate patient dimension key|
|patient_id|text|UNIQUE (patient_id)|No|—|Canonical GL patient identifier anchored in GP masters|
|display_name|text|—|No|—|Canonical patient display name|
|date_of_birth|date|—|Yes|—|Date of birth.|
|sex|character(1)|—|Yes|—|Recorded sex code; do not infer missing values|
|home_clinic_key|integer|FOREIGN KEY (home_clinic_key) REFERENCES curated.dim_clinic(clinic_key)|No|—|Home clinic of the lowest GP registration ID|

## curated.dim_pharmacy

**Owner:** E. **Grain:** One pharmacy dimension member.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|pharmacy_key|integer|PRIMARY KEY (pharmacy_key)|No|GENERATED BY DEFAULT AS IDENTITY|Surrogate pharmacy dimension key|
|pharmacy_id|integer|UNIQUE (pharmacy_id)|No|—|Source pharmacy identifier|
|pharmacy_name|text|—|Yes|—|Pharmacy name|
|suburb|text|—|Yes|—|Source suburb text|

## curated.dim_test

**Owner:** E. **Grain:** One test dimension member.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|test_key|integer|PRIMARY KEY (test_key)|No|—|Conformed test dimension key|
|loinc_code|text|UNIQUE (loinc_code)|No|—|Laboratory test code|
|test_name|text|—|No|—|Readable test name|
|reported_unit|text|—|No|—|Unit associated with the LOINC test|

## curated.fact_dispense

**Owner:** E. **Grain:** One LINKED dispense; target 65.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|dispense_key|integer|PRIMARY KEY (dispense_key)|No|GENERATED BY DEFAULT AS IDENTITY|Surrogate dispensing fact key|
|dispense_id|text|UNIQUE (dispense_id)|No|—|Source dispensing-event identifier|
|patient_key|integer|FOREIGN KEY (patient_key) REFERENCES curated.dim_patient(patient_key)|No|—|Surrogate patient dimension key|
|date_key|integer|FOREIGN KEY (date_key) REFERENCES curated.dim_date(date_key)|No|—|Date dimension key for the event date|
|pharmacy_key|integer|FOREIGN KEY (pharmacy_key) REFERENCES curated.dim_pharmacy(pharmacy_key)|No|—|Surrogate pharmacy dimension key|
|medication_key|integer|FOREIGN KEY (medication_key) REFERENCES curated.dim_medication(medication_key)|No|—|Surrogate medication dimension key|
|quantity|integer|—|Yes|—|Quantity dispensed|
|days_supply|integer|—|Yes|—|Days of supply for the dispensing event|

## curated.fact_encounter

**Owner:** E. **Grain:** One LINKED encounter; target 28.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|encounter_key|integer|PRIMARY KEY (encounter_key)|No|GENERATED BY DEFAULT AS IDENTITY|Surrogate encounter fact key|
|encounter_id|text|UNIQUE (encounter_id)|No|—|Source encounter identifier|
|patient_key|integer|FOREIGN KEY (patient_key) REFERENCES curated.dim_patient(patient_key)|No|—|Surrogate patient dimension key|
|date_key|integer|FOREIGN KEY (date_key) REFERENCES curated.dim_date(date_key)|No|—|Date dimension key for the event date|
|clinic_key|integer|FOREIGN KEY (clinic_key) REFERENCES curated.dim_clinic(clinic_key)|No|—|Surrogate clinic dimension key|
|encounter_type|text|—|Yes|—|STANDARD, CARE_PLAN or MEDICATION_REVIEW|
|diagnosis_code|text|—|Yes|—|Recorded diagnosis code|
|medication_review_flag|boolean|—|Yes|—|Whether the event is a medication review|
|care_plan_flag|boolean|—|Yes|—|Whether the event is a care-plan event|

## curated.fact_lab_result

**Owner:** E. **Grain:** One VALID result linked to a canonical patient; target 32.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|lab_result_key|integer|PRIMARY KEY (lab_result_key)|No|GENERATED BY DEFAULT AS IDENTITY|Surrogate laboratory fact key|
|message_id|text|UNIQUE (message_id)|No|—|Transport/message identifier; distinct from observation_id|
|observation_id|text|—|No|—|FHIR clinical observation identifier used for duplicate detection|
|patient_key|integer|FOREIGN KEY (patient_key) REFERENCES curated.dim_patient(patient_key)|No|—|Surrogate patient dimension key|
|collected_date_key|integer|FOREIGN KEY (collected_date_key) REFERENCES curated.dim_date(date_key)|No|—|Role-playing date key for collection|
|reported_date_key|integer|FOREIGN KEY (reported_date_key) REFERENCES curated.dim_date(date_key)|No|—|Role-playing date key for reporting|
|lab_key|integer|FOREIGN KEY (lab_key) REFERENCES curated.dim_lab(lab_key)|No|—|Surrogate laboratory dimension key|
|test_key|integer|FOREIGN KEY (test_key) REFERENCES curated.dim_test(test_key)|No|—|Conformed test dimension key|
|hba1c_mmol_mol|numeric(6,1)|—|No|—|Standardised HbA1c rounded to one decimal|
|result_returned_flag|boolean|—|No|—|Whether delivery evidence exists for this result|

## reporting.rule_parameter

**Owner:** B. **Grain:** One named business-rule parameter.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|param_name|text|PRIMARY KEY (param_name)|No|—|Stable lookup name of a shared rule|
|param_value|text|—|No|—|Rule value stored as text; consumers explicitly cast|
|description|text|—|No|—|Human-readable explanation|

## reporting.vw_uc1_care_gaps

**Owner:** E. **Grain:** One golden patient with a care gap or a pending high-result review; expected 8 rows.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|patient_id|text|—|Yes|—|Canonical GL patient identifier anchored in GP masters|
|display_name|text|—|Yes|—|Canonical patient display name|
|home_clinic|text|—|Yes|—|Display name of the canonical home clinic|
|last_test_date|date|—|Yes|—|Latest VALID test collected on or before as_of_date; no six-month lower bound. NULL when no valid test exists.|
|last_hba1c_mmol_mol|numeric(6,1)|—|Yes|—|HbA1c for the latest qualifying test|
|first_review_date|date|—|Yes|—|First qualifying review following a high result|
|care_gap_status|text|—|Yes|—|NO_TEST_ON_RECORD, OVERDUE_TEST, HIGH_NO_REVIEW or HIGH_REVIEW_PENDING. Pending review is shown but is not yet a care gap.|
|as_of_date|date|—|Yes|—|Fixed parameter date defining the analysis snapshot|

## reporting.vw_uc2_pdc

**Owner:** D. **Grain:** One eligible golden patient and drug class; expected 11 rows.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|patient_id|text|—|Yes|—|Canonical GL patient identifier anchored in GP masters|
|display_name|text|—|Yes|—|Canonical patient display name|
|drug_class|text|—|Yes|—|Medication class used for adherence grouping|
|fills_counted|bigint|—|Yes|—|Eligible fills in the defined eligibility interval|
|covered_days|bigint|—|Yes|—|Distinct covered days clipped to the PDC window|
|window_days|integer|—|Yes|—|Denominator days in the adherence window|
|pdc|numeric|—|Yes|—|Covered days / window days, rounded as contracted|
|adherence_status|text|—|Yes|—|NON_ADHERENT when PDC < 0.8; otherwise ADHERENT. Fewer than two eligible fills are not listed.|
|window_start|date|—|Yes|—|First included day of the PDC window|
|window_end|date|—|Yes|—|Last included day, excluding as_of_date|
|as_of_date|date|—|Yes|—|Fixed parameter date defining the analysis snapshot|

## reporting.vw_uc3_hba1c_trend

**Owner:** E. **Grain:** One golden patient with at least one VALID result in the 12-month trend window; expected 16 rows.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|patient_id|text|—|Yes|—|Canonical GL patient identifier anchored in GP masters|
|display_name|text|—|Yes|—|Canonical patient display name|
|n_results|bigint|—|Yes|—|Valid results in the trend window|
|first_test_date|date|—|Yes|—|Earliest selected trend test date|
|first_hba1c|numeric|—|Yes|—|HbA1c of the first selected trend result|
|last_test_date|date|—|Yes|—|Latest VALID collection date after as_of_date minus 12 months and on or before as_of_date.|
|last_hba1c|numeric|—|Yes|—|HbA1c of the last selected trend result|
|change_mmol_mol|numeric|—|Yes|—|Last minus first HbA1c in mmol/mol. NULL when n_results < 2.|
|trend_status|text|—|Yes|—|RISING, FALLING, STABLE or INSUFFICIENT_HISTORY. Thresholds are +5 and -5 mmol/mol.|
|best_pdc|numeric|—|Yes|—|Highest eligible class PDC for the patient|
|rising_despite_adherence|boolean|—|Yes|—|True only for RISING with best_pdc >= 0.8. False when PDC is unavailable.|
|as_of_date|date|—|Yes|—|Fixed parameter date defining the analysis snapshot|

## reporting.vw_uc4_care_path_breaks

**Owner:** D. **Grain:** One unreturned VALID result, or one patient/drug-class/pair-of-pharmacies overlap; expected 2 rows.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|patient_id|text|—|Yes|—|Canonical GL patient identifier anchored in GP masters|
|display_name|text|—|Yes|—|Canonical patient display name|
|break_type|text|—|Yes|—|RESULT_NOT_RETURNED or MULTI_PHARMACY_OVERLAP.|
|detail|text|—|Yes|—|Readable explanation of an issue or break|
|event_date|date|—|Yes|—|Date attached to the care-path break|

## audit.identity_truth

**Owner:** C. **Grain:** One synthetic source identity answer-key row; 48 rows. Used only to evaluate matching.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|true_person_id|text|—|Yes|—|Synthetic evaluation-only person label; excluded from matching|
|source_system|text|PRIMARY KEY (source_system, source_patient_id)|No|—|GP, LAB or PHARM source label|
|source_patient_id|text|PRIMARY KEY (source_system, source_patient_id)|No|—|Identifier local to the named source|

## audit.pipeline_run

**Owner:** B / C. **Grain:** One explicitly logged pipeline execution.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|run_id|bigint|PRIMARY KEY (run_id)|No|GENERATED BY DEFAULT AS IDENTITY|Generated identifier of one run; preserve its sequence across setup|
|pipeline_name|text|—|No|—|Name of the pipeline being logged|
|started_at|timestamp with time zone|—|No|clock_timestamp()|Run start instant|
|finished_at|timestamp with time zone|—|Yes|—|Run finish instant; NULL while unfinished|
|rows_read|bigint|—|No|0|Source rows read by the run|
|rows_loaded|bigint|—|No|0|Rows loaded by the run|
|rows_rejected|bigint|—|No|0|Rows rejected by the run|
|status|text|—|No|'RUNNING'::text|RUNNING, SUCCESS or FAILED. Defaults to RUNNING.|
|error_message|text|—|Yes|—|Failure detail if present|

## audit.test_result

**Owner:** F. **Grain:** One acceptance-test result; history/key policy awaits F.

**Definition status:** Implemented; catalog verified after both full 00–09 runs at 9a499ce4 on 11 October 2026

|Column|Type|PK/FK/uniqueness|Nullable|Default|Meaning|
|---|---|---|---|---|---|
|test_id|text|PRIMARY KEY (test_id)|No|—|Acceptance-test identifier|
|description|text|—|No|—|Human-readable explanation|
|expected|text|—|No|—|Expected test output|
|actual|text|—|Yes|—|Observed test output|
|passed|boolean|—|Yes|GENERATED ALWAYS AS ((NOT (actual IS DISTINCT FROM expected))) STORED|Whether the acceptance comparison passed|

## Implementation notes

- patient_master.postcode has been removed. patient_source_link.patient_id is nullable and has an enforced foreign key to patient_master.patient_id.
- CLEANSED encounter and dispense have their own primary keys and no foreign keys back to source tables.
- cleansed.dq_issue uses rule (not rule_code); issue_id is bigint with a sequence default. table_name, record_id and rule are NOT NULL.
- audit.identity_truth holds 48 evaluation rows keyed by (source_system, source_patient_id); it is not used to assign patient identities.
- audit.pipeline_run statuses are RUNNING, SUCCESS and FAILED. dob means Date of birth.
- UC1 last_test_date is the latest VALID result on or before as_of_date, without a six-month lower limit.
- UC3 reads UC2 for best PDC. Fewer than two results gives change_mmol_mol = NULL; unavailable PDC gives rising_despite_adherence = false.
- UC4 uses fact_lab_result.result_returned_flag. The result-return grace period is applied by the view.
- Round 1 started in an empty test database. Round 2 repeated the same 11 scripts in that database. Each round passed 46/46 acceptance tests; RAW history contains exactly two SUCCESS rows after round 2.
- The read-only 10_demo_queries.sql is outside the completed 00–09 run. See [full rebuild evidence](../tests/B_00_09_rebuild_20261011.md).