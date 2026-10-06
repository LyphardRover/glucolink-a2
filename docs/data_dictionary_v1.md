# Package B — logical data dictionary v1

Owner: Zhihao Zhang (B). Prepared 2026-10-06. **Review draft, not a migration script or final D/E sign-off.**

## Evidence and reading guide

Covers **47 objects / 338 columns**: 11 source, 11 RAW, 7 CLEANSED, 10 CURATED, 5 REPORTING (four views plus parameters), 3 AUDIT. Twenty table definitions were observed in the shared PostgreSQL catalog; the other 27 are contract/design drafts. No teammate SQL or shared objects were changed to produce this document.

Sources: Build Plan v2 §5, §6 and Appendices A–C retained by Task Cards v3 (2026-10-06), v3 D1/D8, the group guide, and E-owned `docs/star_schema_v1.drawio` on main d33375a. Live definitions were read independently. Numbers described as targets are acceptance expectations, not current data counts.

**Nullable:** Yes/No is observed PostgreSQL enforcement, not business desirability. TBD means the object is not observed and its owner must confirm. Types on draft objects are proposals unless the source contract or E model defines them. RAW inherits source payload types; no source PK/FK/CHECK constraints are copied. Its four provenance types are proposed. Keys on views are logical grains, not database constraints. Missing foreign keys are not silently invented.

**Known reconciliation points:** shared `src_lab.lab_patient.sex` is `character(1)`; the previously inspected main `01` used text, so C must reconcile its own release. `result_delivery.clinic_id` has no enforced FK in the observed schema. The source columns other than keys are often nullable. D must confirm exact lab-result and DQ-issue columns; E must confirm patient/fact nullability and final DDL. The E diagram provides field/type proposals for patient and facts; v3 D8 fixes home clinic to the lowest GP patient ID and permits RAW + CLEANSED input.

## Object index

|Object|Owner / observed object role|One row represents|Status|
|---|---|---|---|
|`audit.pipeline_run`|a2_team_editor|One explicitly logged pipeline execution|Observed 2026-10-06|
|`cleansed.patient_record`|a2_team_editor|One standardised source patient record; source system and source ID distinguish identities|Observed 2026-10-06|
|`curated.dim_clinic`|a2_team_editor|One clinic dimension member|Observed 2026-10-06|
|`curated.dim_date`|a2_team_editor|One date dimension member|Observed 2026-10-06|
|`curated.dim_lab`|a2_team_editor|One lab dimension member|Observed 2026-10-06|
|`curated.dim_medication`|a2_team_editor|One medication dimension member|Observed 2026-10-06|
|`curated.dim_pharmacy`|a2_team_editor|One pharmacy dimension member|Observed 2026-10-06|
|`curated.dim_test`|a2_team_editor|One test dimension member|Observed 2026-10-06|
|`reporting.rule_parameter`|a2_team_editor|One named business-rule parameter|Observed 2026-10-06|
|`src_gp.clinic`|a2_team_editor|One GP clinic|Observed 2026-10-06|
|`src_gp.encounter`|a2_team_editor|One GP encounter|Observed 2026-10-06|
|`src_gp.gp_patient`|a2_team_editor|One GP registration, not necessarily one real person|Observed 2026-10-06|
|`src_lab.lab_patient`|a2_team_editor|One laboratory patient record|Observed 2026-10-06|
|`src_lab.laboratory`|a2_team_editor|One laboratory|Observed 2026-10-06|
|`src_lab.observation_message`|a2_team_editor|One received FHIR Observation message; duplicate clinical events remain separate messages|Observed 2026-10-06|
|`src_lab.result_delivery`|a2_team_editor|One recorded delivery of a message to a clinic|Observed 2026-10-06|
|`src_pharm.dispense`|a2_team_editor|One dispensing event|Observed 2026-10-06|
|`src_pharm.medication`|a2_team_editor|One PBS medication item|Observed 2026-10-06|
|`src_pharm.pharmacy`|a2_team_editor|One pharmacy|Observed 2026-10-06|
|`src_pharm.pharmacy_patient`|a2_team_editor|One pharmacy patient registration|Observed 2026-10-06|
|`raw.gp_clinic`|C|One unchanged source row from src_gp.clinic|Contract draft; not observed|
|`raw.gp_patient`|C|One unchanged source row from src_gp.gp_patient|Contract draft; not observed|
|`raw.gp_encounter`|C|One unchanged source row from src_gp.encounter|Contract draft; not observed|
|`raw.lab_laboratory`|C|One unchanged source row from src_lab.laboratory|Contract draft; not observed|
|`raw.lab_patient`|C|One unchanged source row from src_lab.lab_patient|Contract draft; not observed|
|`raw.lab_observation`|C|One unchanged source row from src_lab.observation_message|Contract draft; not observed|
|`raw.lab_delivery`|C|One unchanged source row from src_lab.result_delivery|Contract draft; not observed|
|`raw.pharm_pharmacy`|C|One unchanged source row from src_pharm.pharmacy|Contract draft; not observed|
|`raw.pharm_medication`|C|One unchanged source row from src_pharm.medication|Contract draft; not observed|
|`raw.pharm_patient`|C|One unchanged source row from src_pharm.pharmacy_patient|Contract draft; not observed|
|`raw.pharm_dispense`|C|One unchanged source row from src_pharm.dispense|Contract draft; not observed|
|`cleansed.patient_master`|D|One canonical GP-anchored person (target 17)|Contract draft; not observed|
|`cleansed.patient_source_link`|D|One resolution decision for a source patient (target 48)|Contract draft; not observed|
|`cleansed.lab_result`|D|One parsed message including DQ-rejected and duplicate messages (target 36)|Contract draft; not observed|
|`cleansed.encounter`|D|One typed source encounter event|Contract draft; not observed|
|`cleansed.dispense`|D|One typed source dispense event|Contract draft; not observed|
|`cleansed.dq_issue`|D|One recorded data-quality issue; several may refer to a record|Contract draft; not observed|
|`curated.dim_patient`|E|One canonical patient|Contract draft; not observed|
|`curated.fact_encounter`|E|One LINKED encounter; target 28|Contract draft; not observed|
|`curated.fact_lab_result`|E|One VALID result linked to a canonical patient; target 32|Contract draft; not observed|
|`curated.fact_dispense`|E|One LINKED dispense; target 65|Contract draft; not observed|
|`audit.identity_truth`|C|One synthetic source identity answer-key row; NEVER used by matching|Contract draft; not observed|
|`audit.test_result`|F|One acceptance-test result; history/key policy awaits F|Contract draft; not observed|
|`reporting.vw_uc1_care_gaps`|E|One patient classified with a care gap|Contract draft; not observed|
|`reporting.vw_uc2_pdc`|D|One eligible patient and drug class|Contract draft; not observed|
|`reporting.vw_uc3_hba1c_trend`|E|One patient with at least one result in the trend window|Contract draft; not observed|
|`reporting.vw_uc4_care_path_breaks`|D|One missing-delivery event or overlapping pharmacy pair|Contract draft; not observed|

## audit.pipeline_run

**Grain:** One explicitly logged pipeline execution.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`run_id`|`bigint`|PRIMARY KEY (run_id)|No|Generated identifier of one run; preserve its sequence across setup|
|`pipeline_name`|`text`|—|No|Name of the pipeline being logged|
|`started_at`|`timestamp with time zone`|—|No|Run start instant|
|`finished_at`|`timestamp with time zone`|—|Yes|Run finish instant; NULL while unfinished|
|`rows_read`|`bigint`|—|No|Source rows read by the run|
|`rows_loaded`|`bigint`|—|No|Rows loaded by the run|
|`rows_rejected`|`bigint`|—|No|Rows rejected by the run|
|`status`|`text`|—|No|Run/FHIR status; interpret in the table context|
|`error_message`|`text`|—|Yes|Failure detail if present|

Defaults: `run_id`: GENERATED BY DEFAULT AS IDENTITY; `started_at`: clock_timestamp(); `rows_read`: 0; `rows_loaded`: 0; `rows_rejected`: 0; `status`: 'RUNNING'::text.

Observed constraints:

- `CHECK ((rows_read >= 0))`
- `CHECK ((rows_loaded >= 0))`
- `CHECK ((rows_rejected >= 0))`
- `CHECK ((status = ANY (ARRAY['RUNNING'::text, 'SUCCESS'::text, 'FAILED'::text])))`
- `CHECK (((finished_at IS NULL) OR (finished_at >= started_at)))`
- `PRIMARY KEY (run_id)`

## cleansed.patient_record

**Grain:** One standardised source patient record; source system and source ID distinguish identities.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`source_system`|`text`|PRIMARY KEY (source_system, source_patient_id)|No|GP, LAB or PHARM source label|
|`source_patient_id`|`text`|PRIMARY KEY (source_system, source_patient_id)|No|Identifier local to the named source|
|`given_name`|`text`|—|Yes|Given-name component|
|`family_name`|`text`|—|Yes|Family-name component|
|`dob`|`date`|—|Yes|Birth date; source lab keeps original text before cleansing|
|`sex`|`character(1)`|—|Yes|Recorded sex code; do not infer missing values|
|`medicare10`|`text`|—|Yes|Valid normalised ten-digit Medicare identifier or NULL|
|`postcode`|`text`|—|Yes|Postal code kept as text|

Observed constraints:

- `PRIMARY KEY (source_system, source_patient_id)`

## curated.dim_clinic

**Grain:** One clinic dimension member.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`clinic_key`|`integer`|PRIMARY KEY (clinic_key)|No|Surrogate clinic dimension key|
|`clinic_id`|`integer`|UNIQUE (clinic_id)|No|Source GP clinic identifier|
|`clinic_name`|`text`|—|Yes|GP clinic name|
|`suburb`|`text`|—|Yes|Source suburb text|
|`postcode`|`text`|—|Yes|Postal code kept as text|

Defaults: `clinic_key`: GENERATED BY DEFAULT AS IDENTITY.

Observed constraints:

- `PRIMARY KEY (clinic_key)`
- `UNIQUE (clinic_id)`

## curated.dim_date

**Grain:** One date dimension member.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`date_key`|`integer`|PRIMARY KEY (date_key)|No|Date dimension key for the event date|
|`full_date`|`date`|UNIQUE (full_date)|No|Calendar date represented by the member|
|`day`|`integer`|—|No|Day of month|
|`month`|`integer`|—|No|Month number|
|`month_name`|`text`|—|No|Month label|
|`quarter`|`integer`|—|No|Calendar quarter|
|`year`|`integer`|—|No|Calendar year|

Observed constraints:

- `PRIMARY KEY (date_key)`
- `UNIQUE (full_date)`

## curated.dim_lab

**Grain:** One lab dimension member.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`lab_key`|`integer`|PRIMARY KEY (lab_key)|No|Surrogate laboratory dimension key|
|`lab_id`|`integer`|UNIQUE (lab_id)|No|Source laboratory identifier|
|`lab_name`|`text`|—|Yes|Laboratory name|
|`reporting_unit`|`text`|—|Yes|Laboratory reference reporting unit|

Defaults: `lab_key`: GENERATED BY DEFAULT AS IDENTITY.

Observed constraints:

- `PRIMARY KEY (lab_key)`
- `UNIQUE (lab_id)`

## curated.dim_medication

**Grain:** One medication dimension member.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`medication_key`|`integer`|PRIMARY KEY (medication_key)|No|Surrogate medication dimension key|
|`pbs_item_code`|`text`|UNIQUE (pbs_item_code)|No|PBS medication-item identifier|
|`drug_name`|`text`|—|Yes|Medication name|
|`strength`|`text`|—|Yes|Medication strength|
|`pack_size`|`integer`|—|Yes|Units in a medication pack|
|`typical_daily_dose`|`numeric`|—|Yes|Reference daily-dose quantity|
|`drug_class`|`text`|—|Yes|Medication class used for adherence grouping|

Defaults: `medication_key`: GENERATED BY DEFAULT AS IDENTITY.

Observed constraints:

- `PRIMARY KEY (medication_key)`
- `UNIQUE (pbs_item_code)`

## curated.dim_pharmacy

**Grain:** One pharmacy dimension member.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`pharmacy_key`|`integer`|PRIMARY KEY (pharmacy_key)|No|Surrogate pharmacy dimension key|
|`pharmacy_id`|`integer`|UNIQUE (pharmacy_id)|No|Source pharmacy identifier|
|`pharmacy_name`|`text`|—|Yes|Pharmacy name|
|`suburb`|`text`|—|Yes|Source suburb text|

Defaults: `pharmacy_key`: GENERATED BY DEFAULT AS IDENTITY.

Observed constraints:

- `PRIMARY KEY (pharmacy_key)`
- `UNIQUE (pharmacy_id)`

## curated.dim_test

**Grain:** One test dimension member.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`test_key`|`integer`|PRIMARY KEY (test_key)|No|Conformed test dimension key|
|`loinc_code`|`text`|UNIQUE (loinc_code)|No|Laboratory test code|
|`test_name`|`text`|—|No|Readable test name|
|`reported_unit`|`text`|—|No|Unit associated with the LOINC test|

Observed constraints:

- `PRIMARY KEY (test_key)`
- `UNIQUE (loinc_code)`

## reporting.rule_parameter

**Grain:** One named business-rule parameter.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`param_name`|`text`|PRIMARY KEY (param_name)|No|Stable lookup name of a shared rule|
|`param_value`|`text`|—|No|Rule value stored as text; consumers explicitly cast|
|`description`|`text`|—|No|Human-readable explanation|

Observed constraints:

- `PRIMARY KEY (param_name)`

## src_gp.clinic

**Grain:** One GP clinic.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`clinic_id`|`integer`|PRIMARY KEY (clinic_id)|No|Source GP clinic identifier|
|`clinic_name`|`text`|—|Yes|GP clinic name|
|`suburb`|`text`|—|Yes|Source suburb text|
|`postcode`|`text`|—|Yes|Postal code kept as text|

Observed constraints:

- `PRIMARY KEY (clinic_id)`

## src_gp.encounter

**Grain:** One GP encounter.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`encounter_id`|`text`|PRIMARY KEY (encounter_id)|No|Source encounter identifier|
|`gp_patient_id`|`text`|FOREIGN KEY (gp_patient_id) REFERENCES src_gp.gp_patient(gp_patient_id)|Yes|GP registration identifier|
|`clinic_id`|`integer`|FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic(clinic_id)|Yes|Source GP clinic identifier|
|`encounter_date`|`date`|—|Yes|Date of the encounter|
|`encounter_type`|`text`|—|Yes|STANDARD, CARE_PLAN or MEDICATION_REVIEW|
|`diagnosis_code`|`text`|—|Yes|Recorded diagnosis code|
|`medication_review_flag`|`boolean`|—|Yes|Whether the event is a medication review|
|`care_plan_flag`|`boolean`|—|Yes|Whether the event is a care-plan event|

Observed constraints:

- `PRIMARY KEY (encounter_id)`
- `FOREIGN KEY (gp_patient_id) REFERENCES src_gp.gp_patient(gp_patient_id)`
- `FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic(clinic_id)`

## src_gp.gp_patient

**Grain:** One GP registration, not necessarily one real person.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`gp_patient_id`|`text`|PRIMARY KEY (gp_patient_id)|No|GP registration identifier|
|`first_name`|`text`|—|Yes|Source given name|
|`last_name`|`text`|—|Yes|Source family name|
|`dob`|`date`|—|Yes|Birth date; source lab keeps original text before cleansing|
|`sex`|`character(1)`|—|Yes|Recorded sex code; do not infer missing values|
|`postcode`|`text`|—|Yes|Postal code kept as text|
|`medicare_number`|`text`|—|Yes|Unnormalised source Medicare value, including deliberate defects|
|`clinic_id`|`integer`|FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic(clinic_id)|Yes|Source GP clinic identifier|
|`enrolment_date`|`date`|—|Yes|GP registration date|

Observed constraints:

- `PRIMARY KEY (gp_patient_id)`
- `FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic(clinic_id)`

## src_lab.lab_patient

**Grain:** One laboratory patient record.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`lab_patient_id`|`text`|PRIMARY KEY (lab_patient_id)|No|Laboratory-local patient identifier|
|`patient_name`|`text`|—|Yes|Original SURNAME, Given M name|
|`dob`|`text`|—|Yes|Birth date; source lab keeps original text before cleansing|
|`sex`|`character(1)`|—|Yes|Recorded sex code; do not infer missing values|
|`medicare_number`|`text`|—|Yes|Unnormalised source Medicare value, including deliberate defects|

Observed constraints:

- `PRIMARY KEY (lab_patient_id)`

## src_lab.laboratory

**Grain:** One laboratory.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`lab_id`|`integer`|PRIMARY KEY (lab_id)|No|Source laboratory identifier|
|`lab_name`|`text`|—|Yes|Laboratory name|
|`reporting_unit`|`text`|—|Yes|Laboratory reference reporting unit|

Observed constraints:

- `PRIMARY KEY (lab_id)`

## src_lab.observation_message

**Grain:** One received FHIR Observation message; duplicate clinical events remain separate messages.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`message_id`|`text`|PRIMARY KEY (message_id)|No|Transport/message identifier; distinct from observation_id|
|`lab_id`|`integer`|FOREIGN KEY (lab_id) REFERENCES src_lab.laboratory(lab_id)|Yes|Source laboratory identifier|
|`lab_patient_id`|`text`|FOREIGN KEY (lab_patient_id) REFERENCES src_lab.lab_patient(lab_patient_id)|Yes|Laboratory-local patient identifier|
|`received_at`|`timestamp with time zone`|—|Yes|Instant the Observation message was received|
|`fhir_json`|`jsonb`|—|Yes|Original synthetic FHIR R4 Observation JSON|

Observed constraints:

- `PRIMARY KEY (message_id)`
- `FOREIGN KEY (lab_id) REFERENCES src_lab.laboratory(lab_id)`
- `FOREIGN KEY (lab_patient_id) REFERENCES src_lab.lab_patient(lab_patient_id)`

## src_lab.result_delivery

**Grain:** One recorded delivery of a message to a clinic.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`delivery_id`|`text`|PRIMARY KEY (delivery_id)|No|Delivery-event identifier|
|`message_id`|`text`|FOREIGN KEY (message_id) REFERENCES src_lab.observation_message(message_id)|Yes|Transport/message identifier; distinct from observation_id|
|`clinic_id`|`integer`|—|Yes|Source GP clinic identifier|
|`delivered_at`|`timestamp with time zone`|—|Yes|Instant the result was delivered to the clinic|

Observed constraints:

- `PRIMARY KEY (delivery_id)`
- `FOREIGN KEY (message_id) REFERENCES src_lab.observation_message(message_id)`

## src_pharm.dispense

**Grain:** One dispensing event.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`dispense_id`|`text`|PRIMARY KEY (dispense_id)|No|Source dispensing-event identifier|
|`pharmacy_patient_id`|`text`|FOREIGN KEY (pharmacy_patient_id) REFERENCES src_pharm.pharmacy_patient(pharmacy_patient_id)|Yes|Pharmacy-local patient identifier|
|`pharmacy_id`|`integer`|FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy(pharmacy_id)|Yes|Source pharmacy identifier|
|`pbs_item_code`|`text`|FOREIGN KEY (pbs_item_code) REFERENCES src_pharm.medication(pbs_item_code)|Yes|PBS medication-item identifier|
|`dispensed_date`|`date`|—|Yes|Dispensing date|
|`quantity`|`integer`|—|Yes|Quantity dispensed|
|`days_supply`|`integer`|—|Yes|Days of supply for the dispensing event|

Observed constraints:

- `PRIMARY KEY (dispense_id)`
- `FOREIGN KEY (pharmacy_patient_id) REFERENCES src_pharm.pharmacy_patient(pharmacy_patient_id)`
- `FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy(pharmacy_id)`
- `FOREIGN KEY (pbs_item_code) REFERENCES src_pharm.medication(pbs_item_code)`

## src_pharm.medication

**Grain:** One PBS medication item.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`pbs_item_code`|`text`|PRIMARY KEY (pbs_item_code)|No|PBS medication-item identifier|
|`drug_name`|`text`|—|Yes|Medication name|
|`strength`|`text`|—|Yes|Medication strength|
|`pack_size`|`integer`|—|Yes|Units in a medication pack|
|`typical_daily_dose`|`numeric`|—|Yes|Reference daily-dose quantity|
|`drug_class`|`text`|—|Yes|Medication class used for adherence grouping|

Observed constraints:

- `PRIMARY KEY (pbs_item_code)`

## src_pharm.pharmacy

**Grain:** One pharmacy.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`pharmacy_id`|`integer`|PRIMARY KEY (pharmacy_id)|No|Source pharmacy identifier|
|`pharmacy_name`|`text`|—|Yes|Pharmacy name|
|`suburb`|`text`|—|Yes|Source suburb text|

Observed constraints:

- `PRIMARY KEY (pharmacy_id)`

## src_pharm.pharmacy_patient

**Grain:** One pharmacy patient registration.  
**Status:** Observed 2026-10-06.  
**Basis:** Live PostgreSQL catalog; definitions only.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`pharmacy_patient_id`|`text`|PRIMARY KEY (pharmacy_patient_id)|No|Pharmacy-local patient identifier|
|`given_name`|`text`|—|Yes|Given-name component|
|`surname`|`text`|—|Yes|Original pharmacy surname|
|`date_of_birth`|`text`|—|Yes|Birth date; pharmacy source uses original DD-Mon-YY text|
|`medicare_number`|`text`|—|Yes|Unnormalised source Medicare value, including deliberate defects|
|`pharmacy_id`|`integer`|FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy(pharmacy_id)|Yes|Source pharmacy identifier|

Observed constraints:

- `PRIMARY KEY (pharmacy_patient_id)`
- `FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy(pharmacy_id)`

## raw.gp_clinic

**Grain:** One unchanged source row from src_gp.clinic.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; names retained by v3; provenance types proposed.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`clinic_id`|`integer`|No RAW constraint|TBD|Source GP clinic identifier|
|`clinic_name`|`text`|No RAW constraint|TBD|GP clinic name|
|`suburb`|`text`|No RAW constraint|TBD|Source suburb text|
|`postcode`|`text`|No RAW constraint|TBD|Postal code kept as text|
|`_source_system`|`text`|—|TBD|Origin system: GP, LAB or PHARM|
|`_source_table`|`text`|—|TBD|Originating source-table name|
|`_pipeline_run_id`|`bigint`|Logical reference audit.pipeline_run.run_id (not enforced)|TBD|Ingestion run reference for traceability; not a RAW FK|
|`_loaded_at`|`timestamptz`|—|TBD|Timestamp when the RAW row was loaded|

## raw.gp_patient

**Grain:** One unchanged source row from src_gp.gp_patient.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; names retained by v3; provenance types proposed.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`gp_patient_id`|`text`|No RAW constraint|TBD|GP registration identifier|
|`first_name`|`text`|No RAW constraint|TBD|Source given name|
|`last_name`|`text`|No RAW constraint|TBD|Source family name|
|`dob`|`date`|No RAW constraint|TBD|Birth date; source lab keeps original text before cleansing|
|`sex`|`character(1)`|No RAW constraint|TBD|Recorded sex code; do not infer missing values|
|`postcode`|`text`|No RAW constraint|TBD|Postal code kept as text|
|`medicare_number`|`text`|No RAW constraint|TBD|Unnormalised source Medicare value, including deliberate defects|
|`clinic_id`|`integer`|No RAW constraint|TBD|Source GP clinic identifier|
|`enrolment_date`|`date`|No RAW constraint|TBD|GP registration date|
|`_source_system`|`text`|—|TBD|Origin system: GP, LAB or PHARM|
|`_source_table`|`text`|—|TBD|Originating source-table name|
|`_pipeline_run_id`|`bigint`|Logical reference audit.pipeline_run.run_id (not enforced)|TBD|Ingestion run reference for traceability; not a RAW FK|
|`_loaded_at`|`timestamptz`|—|TBD|Timestamp when the RAW row was loaded|

## raw.gp_encounter

**Grain:** One unchanged source row from src_gp.encounter.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; names retained by v3; provenance types proposed.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`encounter_id`|`text`|No RAW constraint|TBD|Source encounter identifier|
|`gp_patient_id`|`text`|No RAW constraint|TBD|GP registration identifier|
|`clinic_id`|`integer`|No RAW constraint|TBD|Source GP clinic identifier|
|`encounter_date`|`date`|No RAW constraint|TBD|Date of the encounter|
|`encounter_type`|`text`|No RAW constraint|TBD|STANDARD, CARE_PLAN or MEDICATION_REVIEW|
|`diagnosis_code`|`text`|No RAW constraint|TBD|Recorded diagnosis code|
|`medication_review_flag`|`boolean`|No RAW constraint|TBD|Whether the event is a medication review|
|`care_plan_flag`|`boolean`|No RAW constraint|TBD|Whether the event is a care-plan event|
|`_source_system`|`text`|—|TBD|Origin system: GP, LAB or PHARM|
|`_source_table`|`text`|—|TBD|Originating source-table name|
|`_pipeline_run_id`|`bigint`|Logical reference audit.pipeline_run.run_id (not enforced)|TBD|Ingestion run reference for traceability; not a RAW FK|
|`_loaded_at`|`timestamptz`|—|TBD|Timestamp when the RAW row was loaded|

## raw.lab_laboratory

**Grain:** One unchanged source row from src_lab.laboratory.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; names retained by v3; provenance types proposed.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`lab_id`|`integer`|No RAW constraint|TBD|Source laboratory identifier|
|`lab_name`|`text`|No RAW constraint|TBD|Laboratory name|
|`reporting_unit`|`text`|No RAW constraint|TBD|Laboratory reference reporting unit|
|`_source_system`|`text`|—|TBD|Origin system: GP, LAB or PHARM|
|`_source_table`|`text`|—|TBD|Originating source-table name|
|`_pipeline_run_id`|`bigint`|Logical reference audit.pipeline_run.run_id (not enforced)|TBD|Ingestion run reference for traceability; not a RAW FK|
|`_loaded_at`|`timestamptz`|—|TBD|Timestamp when the RAW row was loaded|

## raw.lab_patient

**Grain:** One unchanged source row from src_lab.lab_patient.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; names retained by v3; provenance types proposed.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`lab_patient_id`|`text`|No RAW constraint|TBD|Laboratory-local patient identifier|
|`patient_name`|`text`|No RAW constraint|TBD|Original SURNAME, Given M name|
|`dob`|`text`|No RAW constraint|TBD|Birth date; source lab keeps original text before cleansing|
|`sex`|`character(1)`|No RAW constraint|TBD|Recorded sex code; do not infer missing values|
|`medicare_number`|`text`|No RAW constraint|TBD|Unnormalised source Medicare value, including deliberate defects|
|`_source_system`|`text`|—|TBD|Origin system: GP, LAB or PHARM|
|`_source_table`|`text`|—|TBD|Originating source-table name|
|`_pipeline_run_id`|`bigint`|Logical reference audit.pipeline_run.run_id (not enforced)|TBD|Ingestion run reference for traceability; not a RAW FK|
|`_loaded_at`|`timestamptz`|—|TBD|Timestamp when the RAW row was loaded|

## raw.lab_observation

**Grain:** One unchanged source row from src_lab.observation_message.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; names retained by v3; provenance types proposed.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`message_id`|`text`|No RAW constraint|TBD|Transport/message identifier; distinct from observation_id|
|`lab_id`|`integer`|No RAW constraint|TBD|Source laboratory identifier|
|`lab_patient_id`|`text`|No RAW constraint|TBD|Laboratory-local patient identifier|
|`received_at`|`timestamp with time zone`|No RAW constraint|TBD|Instant the Observation message was received|
|`fhir_json`|`jsonb`|No RAW constraint|TBD|Original synthetic FHIR R4 Observation JSON|
|`_source_system`|`text`|—|TBD|Origin system: GP, LAB or PHARM|
|`_source_table`|`text`|—|TBD|Originating source-table name|
|`_pipeline_run_id`|`bigint`|Logical reference audit.pipeline_run.run_id (not enforced)|TBD|Ingestion run reference for traceability; not a RAW FK|
|`_loaded_at`|`timestamptz`|—|TBD|Timestamp when the RAW row was loaded|

## raw.lab_delivery

**Grain:** One unchanged source row from src_lab.result_delivery.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; names retained by v3; provenance types proposed.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`delivery_id`|`text`|No RAW constraint|TBD|Delivery-event identifier|
|`message_id`|`text`|No RAW constraint|TBD|Transport/message identifier; distinct from observation_id|
|`clinic_id`|`integer`|No RAW constraint|TBD|Source GP clinic identifier|
|`delivered_at`|`timestamp with time zone`|No RAW constraint|TBD|Instant the result was delivered to the clinic|
|`_source_system`|`text`|—|TBD|Origin system: GP, LAB or PHARM|
|`_source_table`|`text`|—|TBD|Originating source-table name|
|`_pipeline_run_id`|`bigint`|Logical reference audit.pipeline_run.run_id (not enforced)|TBD|Ingestion run reference for traceability; not a RAW FK|
|`_loaded_at`|`timestamptz`|—|TBD|Timestamp when the RAW row was loaded|

## raw.pharm_pharmacy

**Grain:** One unchanged source row from src_pharm.pharmacy.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; names retained by v3; provenance types proposed.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`pharmacy_id`|`integer`|No RAW constraint|TBD|Source pharmacy identifier|
|`pharmacy_name`|`text`|No RAW constraint|TBD|Pharmacy name|
|`suburb`|`text`|No RAW constraint|TBD|Source suburb text|
|`_source_system`|`text`|—|TBD|Origin system: GP, LAB or PHARM|
|`_source_table`|`text`|—|TBD|Originating source-table name|
|`_pipeline_run_id`|`bigint`|Logical reference audit.pipeline_run.run_id (not enforced)|TBD|Ingestion run reference for traceability; not a RAW FK|
|`_loaded_at`|`timestamptz`|—|TBD|Timestamp when the RAW row was loaded|

## raw.pharm_medication

**Grain:** One unchanged source row from src_pharm.medication.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; names retained by v3; provenance types proposed.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`pbs_item_code`|`text`|No RAW constraint|TBD|PBS medication-item identifier|
|`drug_name`|`text`|No RAW constraint|TBD|Medication name|
|`strength`|`text`|No RAW constraint|TBD|Medication strength|
|`pack_size`|`integer`|No RAW constraint|TBD|Units in a medication pack|
|`typical_daily_dose`|`numeric`|No RAW constraint|TBD|Reference daily-dose quantity|
|`drug_class`|`text`|No RAW constraint|TBD|Medication class used for adherence grouping|
|`_source_system`|`text`|—|TBD|Origin system: GP, LAB or PHARM|
|`_source_table`|`text`|—|TBD|Originating source-table name|
|`_pipeline_run_id`|`bigint`|Logical reference audit.pipeline_run.run_id (not enforced)|TBD|Ingestion run reference for traceability; not a RAW FK|
|`_loaded_at`|`timestamptz`|—|TBD|Timestamp when the RAW row was loaded|

## raw.pharm_patient

**Grain:** One unchanged source row from src_pharm.pharmacy_patient.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; names retained by v3; provenance types proposed.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`pharmacy_patient_id`|`text`|No RAW constraint|TBD|Pharmacy-local patient identifier|
|`given_name`|`text`|No RAW constraint|TBD|Given-name component|
|`surname`|`text`|No RAW constraint|TBD|Original pharmacy surname|
|`date_of_birth`|`text`|No RAW constraint|TBD|Birth date; pharmacy source uses original DD-Mon-YY text|
|`medicare_number`|`text`|No RAW constraint|TBD|Unnormalised source Medicare value, including deliberate defects|
|`pharmacy_id`|`integer`|No RAW constraint|TBD|Source pharmacy identifier|
|`_source_system`|`text`|—|TBD|Origin system: GP, LAB or PHARM|
|`_source_table`|`text`|—|TBD|Originating source-table name|
|`_pipeline_run_id`|`bigint`|Logical reference audit.pipeline_run.run_id (not enforced)|TBD|Ingestion run reference for traceability; not a RAW FK|
|`_loaded_at`|`timestamptz`|—|TBD|Timestamp when the RAW row was loaded|

## raw.pharm_dispense

**Grain:** One unchanged source row from src_pharm.dispense.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; names retained by v3; provenance types proposed.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`dispense_id`|`text`|No RAW constraint|TBD|Source dispensing-event identifier|
|`pharmacy_patient_id`|`text`|No RAW constraint|TBD|Pharmacy-local patient identifier|
|`pharmacy_id`|`integer`|No RAW constraint|TBD|Source pharmacy identifier|
|`pbs_item_code`|`text`|No RAW constraint|TBD|PBS medication-item identifier|
|`dispensed_date`|`date`|No RAW constraint|TBD|Dispensing date|
|`quantity`|`integer`|No RAW constraint|TBD|Quantity dispensed|
|`days_supply`|`integer`|No RAW constraint|TBD|Days of supply for the dispensing event|
|`_source_system`|`text`|—|TBD|Origin system: GP, LAB or PHARM|
|`_source_table`|`text`|—|TBD|Originating source-table name|
|`_pipeline_run_id`|`bigint`|Logical reference audit.pipeline_run.run_id (not enforced)|TBD|Ingestion run reference for traceability; not a RAW FK|
|`_loaded_at`|`timestamptz`|—|TBD|Timestamp when the RAW row was loaded|

## cleansed.patient_master

**Grain:** One canonical GP-anchored person (target 17).  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; physical types/nullability proposed for owner review.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`patient_id`|`text`|PK|TBD|Canonical GL patient identifier anchored in GP masters|
|`given_name`|`text`|—|TBD|Given-name component|
|`family_name`|`text`|—|TBD|Family-name component|
|`dob`|`date`|—|TBD|Birth date; source lab keeps original text before cleansing|
|`sex`|`char(1)`|—|TBD|Recorded sex code; do not infer missing values|
|`medicare10`|`text`|—|TBD|Valid normalised ten-digit Medicare identifier or NULL|

## cleansed.patient_source_link

**Grain:** One resolution decision for a source patient (target 48).  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; physical types/nullability proposed for owner review.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`source_system`|`text`|Composite PK|TBD|GP, LAB or PHARM source label|
|`source_patient_id`|`text`|Composite PK|TBD|Identifier local to the named source|
|`patient_id`|`text`|FK patient_master.patient_id; NULL unless LINKED|TBD|Canonical GL patient identifier anchored in GP masters|
|`match_status`|`text`|—|TBD|LINKED / REVIEW / UNMATCHED|
|`match_rule`|`text`|—|TBD|GP / R1 / R2; NULL if not linked|
|`candidate_count`|`integer`|—|TBD|Number of candidate masters|

## cleansed.lab_result

**Grain:** One parsed message including DQ-rejected and duplicate messages (target 36).  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; physical types/nullability proposed for owner review.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`message_id`|`text`|Proposed PK retained for traceability|TBD|Transport/message identifier; distinct from observation_id|
|`lab_patient_id`|`text`|Proposed retained source reference|TBD|Laboratory-local patient identifier|
|`lab_id`|`integer`|Proposed retained laboratory reference|TBD|Source laboratory identifier|
|`observation_id`|`text`|—|TBD|FHIR clinical observation identifier used for duplicate detection|
|`status`|`text`|—|TBD|FHIR Observation status|
|`loinc_code`|`text`|—|TBD|Laboratory test code|
|`value_as_received`|`numeric`|—|TBD|Original numeric value before unit conversion|
|`unit_as_received`|`text`|—|TBD|Original unit including deliberately empty units|
|`hba1c_mmol_mol`|`numeric(6,1)`|—|TBD|Converted value; NULL for invalid unit|
|`collected_date`|`date`|—|TBD|Sydney date from timestamp|
|`reported_date`|`date`|—|TBD|Sydney date from timestamp|
|`returned_to_clinic_id`|`integer`|Logical reference clinic|TBD|Clinic recorded for result return, if any|
|`returned_at`|`timestamptz`|—|TBD|Result-return timestamp, if any|
|`dq_status`|`text`|—|TBD|VALID / DUPLICATE / REJECTED_UNIT / FUTURE_DATE|

## cleansed.encounter

**Grain:** One typed source encounter event.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2: typed copy; exact retained columns, keys and nullability await D.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`encounter_id`|`text`|PRIMARY KEY (encounter_id)|TBD|Source encounter identifier|
|`gp_patient_id`|`text`|FOREIGN KEY (gp_patient_id) REFERENCES src_gp.gp_patient(gp_patient_id)|TBD|GP registration identifier|
|`clinic_id`|`integer`|FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic(clinic_id)|TBD|Source GP clinic identifier|
|`encounter_date`|`date`|—|TBD|Date of the encounter|
|`encounter_type`|`text`|—|TBD|STANDARD, CARE_PLAN or MEDICATION_REVIEW|
|`diagnosis_code`|`text`|—|TBD|Recorded diagnosis code|
|`medication_review_flag`|`boolean`|—|TBD|Whether the event is a medication review|
|`care_plan_flag`|`boolean`|—|TBD|Whether the event is a care-plan event|

## cleansed.dispense

**Grain:** One typed source dispense event.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2: typed copy; exact retained columns, keys and nullability await D.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`dispense_id`|`text`|PRIMARY KEY (dispense_id)|TBD|Source dispensing-event identifier|
|`pharmacy_patient_id`|`text`|FOREIGN KEY (pharmacy_patient_id) REFERENCES src_pharm.pharmacy_patient(pharmacy_patient_id)|TBD|Pharmacy-local patient identifier|
|`pharmacy_id`|`integer`|FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy(pharmacy_id)|TBD|Source pharmacy identifier|
|`pbs_item_code`|`text`|FOREIGN KEY (pbs_item_code) REFERENCES src_pharm.medication(pbs_item_code)|TBD|PBS medication-item identifier|
|`dispensed_date`|`date`|—|TBD|Dispensing date|
|`quantity`|`integer`|—|TBD|Quantity dispensed|
|`days_supply`|`integer`|—|TBD|Days of supply for the dispensing event|

## cleansed.dq_issue

**Grain:** One recorded data-quality issue; several may refer to a record.  
**Status:** Contract draft; not observed.  
**Basis:** Contract requires table, record ID, rule and detail; all exact column names and issue key are B proposals awaiting D.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`issue_id`|`bigint`|Proposed PK|TBD|Proposed generated issue identifier|
|`table_name`|`text`|—|TBD|Table containing the affected record|
|`record_id`|`text`|—|TBD|Identifier of the affected record|
|`rule_code`|`text`|—|TBD|Violated quality rule|
|`detail`|`text`|—|TBD|Readable explanation of an issue or break|

## curated.dim_patient

**Grain:** One canonical patient.  
**Status:** Contract draft; not observed.  
**Basis:** E-owned docs/star_schema_v1.drawio on main; design reference, not implemented DDL. Nullability awaits E.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`patient_key`|`integer`|PK|TBD|Surrogate patient dimension key|
|`patient_id`|`text`|UQ|TBD|Canonical GL patient identifier anchored in GP masters|
|`display_name`|`text`|—|TBD|Canonical patient display name|
|`date_of_birth`|`date`|—|TBD|Birth date; pharmacy source uses original DD-Mon-YY text|
|`sex`|`char(1)`|—|TBD|Recorded sex code; do not infer missing values|
|`home_clinic_key`|`integer`|FK|TBD|Home clinic of the lowest GP registration ID|

## curated.fact_encounter

**Grain:** One LINKED encounter; target 28.  
**Status:** Contract draft; not observed.  
**Basis:** E-owned docs/star_schema_v1.drawio on main; design reference, not implemented DDL. Nullability awaits E.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`encounter_key`|`integer`|PK|TBD|Surrogate encounter fact key|
|`encounter_id`|`text`|UQ|TBD|Source encounter identifier|
|`patient_key`|`integer`|FK|TBD|Surrogate patient dimension key|
|`date_key`|`integer`|FK|TBD|Date dimension key for the event date|
|`clinic_key`|`integer`|FK|TBD|Surrogate clinic dimension key|
|`encounter_type`|`text`|—|TBD|STANDARD, CARE_PLAN or MEDICATION_REVIEW|
|`diagnosis_code`|`text`|—|TBD|Recorded diagnosis code|
|`medication_review_flag`|`boolean`|—|TBD|Whether the event is a medication review|
|`care_plan_flag`|`boolean`|—|TBD|Whether the event is a care-plan event|

## curated.fact_lab_result

**Grain:** One VALID result linked to a canonical patient; target 32.  
**Status:** Contract draft; not observed.  
**Basis:** E-owned docs/star_schema_v1.drawio on main; design reference, not implemented DDL. Nullability awaits E.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`lab_result_key`|`integer`|PK|TBD|Surrogate laboratory fact key|
|`message_id`|`text`|UQ|TBD|Transport/message identifier; distinct from observation_id|
|`observation_id`|`text`|—|TBD|FHIR clinical observation identifier used for duplicate detection|
|`patient_key`|`integer`|FK|TBD|Surrogate patient dimension key|
|`collected_date_key`|`integer`|FK|TBD|Role-playing date key for collection|
|`reported_date_key`|`integer`|FK|TBD|Role-playing date key for reporting|
|`lab_key`|`integer`|FK|TBD|Surrogate laboratory dimension key|
|`test_key`|`integer`|FK|TBD|Conformed test dimension key|
|`hba1c_mmol_mol`|`numeric(6,1)`|—|TBD|Standardised HbA1c rounded to one decimal|
|`result_returned_flag`|`boolean`|—|TBD|Whether delivery evidence exists for this result|

## curated.fact_dispense

**Grain:** One LINKED dispense; target 65.  
**Status:** Contract draft; not observed.  
**Basis:** E-owned docs/star_schema_v1.drawio on main; design reference, not implemented DDL. Nullability awaits E.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`dispense_key`|`integer`|PK|TBD|Surrogate dispensing fact key|
|`dispense_id`|`text`|UQ|TBD|Source dispensing-event identifier|
|`patient_key`|`integer`|FK|TBD|Surrogate patient dimension key|
|`date_key`|`integer`|FK|TBD|Date dimension key for the event date|
|`pharmacy_key`|`integer`|FK|TBD|Surrogate pharmacy dimension key|
|`medication_key`|`integer`|FK|TBD|Surrogate medication dimension key|
|`quantity`|`integer`|—|TBD|Quantity dispensed|
|`days_supply`|`integer`|—|TBD|Days of supply for the dispensing event|

## audit.identity_truth

**Grain:** One synthetic source identity answer-key row; NEVER used by matching.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; physical types/nullability proposed for owner review.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`true_person_id`|`text`|—|TBD|Synthetic evaluation-only person label; excluded from matching|
|`source_system`|`text`|Proposed composite key|TBD|GP, LAB or PHARM source label|
|`source_patient_id`|`text`|Proposed composite key|TBD|Identifier local to the named source|

## audit.test_result

**Grain:** One acceptance-test result; history/key policy awaits F.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; physical types/nullability proposed for owner review.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`test_id`|`text`|—|TBD|Acceptance-test identifier|
|`description`|`text`|—|TBD|Human-readable explanation|
|`expected`|`text`|—|TBD|Expected test output|
|`actual`|`text`|—|TBD|Observed test output|
|`passed`|`boolean`|—|TBD|Whether the acceptance comparison passed|

## reporting.vw_uc1_care_gaps

**Grain:** One patient classified with a care gap.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; physical types/nullability proposed for owner review.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`patient_id`|`text`|View: no physical PK/FK|TBD|Canonical GL patient identifier anchored in GP masters|
|`display_name`|`text`|View: no physical PK/FK|TBD|Canonical patient display name|
|`home_clinic`|`text`|View: no physical PK/FK|TBD|Display name of the canonical home clinic|
|`last_test_date`|`date`|View: no physical PK/FK|TBD|Latest valid test date in the relevant rule window|
|`last_hba1c_mmol_mol`|`numeric`|View: no physical PK/FK|TBD|HbA1c for the latest qualifying test|
|`first_review_date`|`date`|View: no physical PK/FK|TBD|First qualifying review following a high result|
|`care_gap_status`|`text`|View: no physical PK/FK|TBD|Rule-derived care-gap category|
|`as_of_date`|`date`|View: no physical PK/FK|TBD|Fixed parameter date defining the analysis snapshot|

## reporting.vw_uc2_pdc

**Grain:** One eligible patient and drug class.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; physical types/nullability proposed for owner review.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`patient_id`|`text`|View: no physical PK/FK|TBD|Canonical GL patient identifier anchored in GP masters|
|`display_name`|`text`|View: no physical PK/FK|TBD|Canonical patient display name|
|`drug_class`|`text`|View: no physical PK/FK|TBD|Medication class used for adherence grouping|
|`fills_counted`|`integer`|View: no physical PK/FK|TBD|Eligible fills in the defined eligibility interval|
|`covered_days`|`integer`|View: no physical PK/FK|TBD|Distinct covered days clipped to the PDC window|
|`window_days`|`integer`|View: no physical PK/FK|TBD|Denominator days in the adherence window|
|`pdc`|`numeric`|View: no physical PK/FK|TBD|Covered days / window days, rounded as contracted|
|`adherence_status`|`text`|View: no physical PK/FK|TBD|Threshold-derived adherence category|
|`window_start`|`date`|View: no physical PK/FK|TBD|First included day of the PDC window|
|`window_end`|`date`|View: no physical PK/FK|TBD|Last included day, excluding as_of_date|
|`as_of_date`|`date`|View: no physical PK/FK|TBD|Fixed parameter date defining the analysis snapshot|

## reporting.vw_uc3_hba1c_trend

**Grain:** One patient with at least one result in the trend window.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; physical types/nullability proposed for owner review.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`patient_id`|`text`|View: no physical PK/FK|TBD|Canonical GL patient identifier anchored in GP masters|
|`display_name`|`text`|View: no physical PK/FK|TBD|Canonical patient display name|
|`n_results`|`integer`|View: no physical PK/FK|TBD|Valid results in the trend window|
|`first_test_date`|`date`|View: no physical PK/FK|TBD|Earliest selected trend test date|
|`first_hba1c`|`numeric`|View: no physical PK/FK|TBD|HbA1c of the first selected trend result|
|`last_test_date`|`date`|View: no physical PK/FK|TBD|Latest valid test date in the relevant rule window|
|`last_hba1c`|`numeric`|View: no physical PK/FK|TBD|HbA1c of the last selected trend result|
|`change_mmol_mol`|`numeric`|View: no physical PK/FK|TBD|Last minus first HbA1c|
|`trend_status`|`text`|View: no physical PK/FK|TBD|RISING, FALLING, STABLE or insufficient-data category|
|`best_pdc`|`numeric`|View: no physical PK/FK|TBD|Highest eligible class PDC for the patient|
|`rising_despite_adherence`|`boolean`|View: no physical PK/FK|TBD|True when rising trend and qualifying adherence coexist|
|`as_of_date`|`date`|View: no physical PK/FK|TBD|Fixed parameter date defining the analysis snapshot|

## reporting.vw_uc4_care_path_breaks

**Grain:** One missing-delivery event or overlapping pharmacy pair.  
**Status:** Contract draft; not observed.  
**Basis:** Build Plan v2 §5; physical types/nullability proposed for owner review.

|Column|Type|PK / FK / uniqueness|Nullable|Meaning|
|---|---|---|---|---|
|`patient_id`|`text`|View: no physical PK/FK|TBD|Canonical GL patient identifier anchored in GP masters|
|`display_name`|`text`|View: no physical PK/FK|TBD|Canonical patient display name|
|`break_type`|`text`|View: no physical PK/FK|TBD|Type of care-path break|
|`detail`|`text`|View: no physical PK/FK|TBD|Readable explanation of an issue or break|
|`event_date`|`date`|View: no physical PK/FK|TBD|Date attached to the care-path break|

## Review and freeze gate

D confirms the seven CLEANSED objects and UC2/UC4 view contract; E confirms ten CURATED objects and UC1/UC3; C confirms RAW provenance/identity truth and source DDL; F confirms test_result. Record each acknowledgement and commit, then regenerate the live comparison after 00–10 succeeds twice. This draft must not be labelled final until every TBD is resolved against the frozen SQL.

Prepared with AI assistance and checked against the cited project materials and observed metadata. Human review is pending; no hours or teammate approvals are asserted.
