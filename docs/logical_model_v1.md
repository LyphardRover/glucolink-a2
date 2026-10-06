# Package B — logical model v1

Review draft, 2026-10-06. Companion: data_dictionary_v1.md (47 objects / 338 columns). **This is documentation, not DDL.** D/E/C/F own their implementations; proposed columns and unenforced logical references require their approval. Every field/type/nullability and observed constraint is listed in the dictionary.

## Layer lineage

```mermaid
flowchart LR
  GP[src_gp — C] --> RAW[raw: 11 source copies + 4 provenance fields — C]
  LAB[src_lab — C DDL / B lab fixture] --> RAW
  PHARM[src_pharm — C] --> RAW
  RAW --> CLEAN[cleansed: 7 objects — D]
  CLEAN --> CUR[curated: 7 dimensions + 3 facts — E]
  RAW -->|v3 D8: reference data and GP home clinic| CUR
  CUR --> UC1[reporting.vw_uc1_care_gaps — E]
  CUR --> UC2[reporting.vw_uc2_pdc — D]
  CUR --> UC3[reporting.vw_uc3_hba1c_trend — E]
  CUR --> UC4[reporting.vw_uc4_care_path_breaks — D]
  UC1 --> F[Dashboards / Excel — F]
  UC2 --> F
  UC3 --> F
  UC4 --> F
  PARAM[reporting.rule_parameter — A rules / B setup] -.-> CLEAN
  PARAM -.-> UC1
  PARAM -.-> UC2
  PARAM -.-> UC3
  PARAM -.-> UC4
  RUN[audit.pipeline_run — B DDL / C run logging] -.-> RAW
  TRUTH[audit.identity_truth — C, evaluation only] -.-> TEST[audit.test_result — F]
```

## Source relationships

```mermaid
erDiagram
  CLINIC ||--o{ GP_PATIENT : registers
  GP_PATIENT ||--o{ ENCOUNTER : has
  CLINIC ||--o{ ENCOUNTER : hosts
  LABORATORY ||--o{ OBSERVATION_MESSAGE : sends
  LAB_PATIENT ||--o{ OBSERVATION_MESSAGE : subject
  OBSERVATION_MESSAGE ||--o{ RESULT_DELIVERY : delivery
  CLINIC ||--o{ RESULT_DELIVERY : "logical clinic reference; no observed FK"
  PHARMACY ||--o{ PHARMACY_PATIENT : registers
  PHARMACY_PATIENT ||--o{ DISPENSE : has
  PHARMACY ||--o{ DISPENSE : supplies
  MEDICATION ||--o{ DISPENSE : item
```

These show intended business references. Actual FK columns in source tables can be nullable: consult the observed dictionary rather than interpreting a drawn relationship as a NOT NULL constraint. A message may have no delivery; a message ID is not an Observation ID. RAW has all eleven mapped payload tables but no copied source constraints.

## Identity and quality relationships

```mermaid
erDiagram
  PATIENT_RECORD ||--|| PATIENT_SOURCE_LINK : "one decision per system plus source ID"
  PATIENT_MASTER |o--o{ PATIENT_SOURCE_LINK : "nullable patient_id unless LINKED"
  LAB_RESULT }o--o| PATIENT_SOURCE_LINK : "LAB plus lab_patient_id, logical reference"
  ENCOUNTER }o--o| PATIENT_SOURCE_LINK : "GP plus gp_patient_id, logical reference"
  DISPENSE }o--o| PATIENT_SOURCE_LINK : "PHARM plus pharmacy_patient_id, logical reference"
```

The target is 48 source records and decisions, 17 canonical masters, 46 LINKED / 1 REVIEW / 1 UNMATCHED. DQ issues reference table plus record identifiers; an exact enforced FK across several target tables is not implied. Identity truth is separate from operational matching. Unresolved rows remain inspectable and do not enter patient-linked facts.

## Conformed dimensional model

```mermaid
erDiagram
  DIM_PATIENT ||--o{ FACT_ENCOUNTER : patient_key
  DIM_DATE ||--o{ FACT_ENCOUNTER : date_key
  DIM_CLINIC ||--o{ FACT_ENCOUNTER : clinic_key
  DIM_CLINIC ||--o{ DIM_PATIENT : home_clinic_key
  DIM_PATIENT ||--o{ FACT_LAB_RESULT : patient_key
  DIM_DATE ||--o{ FACT_LAB_RESULT : collected_date_key
  DIM_DATE ||--o{ FACT_LAB_RESULT : reported_date_key
  DIM_LAB ||--o{ FACT_LAB_RESULT : lab_key
  DIM_TEST ||--o{ FACT_LAB_RESULT : test_key
  DIM_PATIENT ||--o{ FACT_DISPENSE : patient_key
  DIM_DATE ||--o{ FACT_DISPENSE : date_key
  DIM_PHARMACY ||--o{ FACT_DISPENSE : pharmacy_key
  DIM_MEDICATION ||--o{ FACT_DISPENSE : medication_key
```

Field/type proposals for the patient dimension and facts are taken from E-owned star_schema_v1.drawio; exact constraints await final E SQL. Observed dimensions are documented as observed. Each fact is one event; never join all facts at patient level before aggregation. Home clinic follows v3 D8: the clinic belonging to the lowest gp_patient_id among that master's GP records.

## Full object inventory

### audit.pipeline_run

One explicitly logged pipeline execution. Observed 2026-10-06.

`run_id: bigint [PRIMARY KEY (run_id)]`  
`pipeline_name: text`  
`started_at: timestamp with time zone`  
`finished_at: timestamp with time zone`  
`rows_read: bigint`  
`rows_loaded: bigint`  
`rows_rejected: bigint`  
`status: text`  
`error_message: text`

### cleansed.patient_record

One standardised source patient record; source system and source ID distinguish identities. Observed 2026-10-06.

`source_system: text [PRIMARY KEY (source_system, source_patient_id)]`  
`source_patient_id: text [PRIMARY KEY (source_system, source_patient_id)]`  
`given_name: text`  
`family_name: text`  
`dob: date`  
`sex: character(1)`  
`medicare10: text`  
`postcode: text`

### curated.dim_clinic

One clinic dimension member. Observed 2026-10-06.

`clinic_key: integer [PRIMARY KEY (clinic_key)]`  
`clinic_id: integer [UNIQUE (clinic_id)]`  
`clinic_name: text`  
`suburb: text`  
`postcode: text`

### curated.dim_date

One date dimension member. Observed 2026-10-06.

`date_key: integer [PRIMARY KEY (date_key)]`  
`full_date: date [UNIQUE (full_date)]`  
`day: integer`  
`month: integer`  
`month_name: text`  
`quarter: integer`  
`year: integer`

### curated.dim_lab

One lab dimension member. Observed 2026-10-06.

`lab_key: integer [PRIMARY KEY (lab_key)]`  
`lab_id: integer [UNIQUE (lab_id)]`  
`lab_name: text`  
`reporting_unit: text`

### curated.dim_medication

One medication dimension member. Observed 2026-10-06.

`medication_key: integer [PRIMARY KEY (medication_key)]`  
`pbs_item_code: text [UNIQUE (pbs_item_code)]`  
`drug_name: text`  
`strength: text`  
`pack_size: integer`  
`typical_daily_dose: numeric`  
`drug_class: text`

### curated.dim_pharmacy

One pharmacy dimension member. Observed 2026-10-06.

`pharmacy_key: integer [PRIMARY KEY (pharmacy_key)]`  
`pharmacy_id: integer [UNIQUE (pharmacy_id)]`  
`pharmacy_name: text`  
`suburb: text`

### curated.dim_test

One test dimension member. Observed 2026-10-06.

`test_key: integer [PRIMARY KEY (test_key)]`  
`loinc_code: text [UNIQUE (loinc_code)]`  
`test_name: text`  
`reported_unit: text`

### reporting.rule_parameter

One named business-rule parameter. Observed 2026-10-06.

`param_name: text [PRIMARY KEY (param_name)]`  
`param_value: text`  
`description: text`

### src_gp.clinic

One GP clinic. Observed 2026-10-06.

`clinic_id: integer [PRIMARY KEY (clinic_id)]`  
`clinic_name: text`  
`suburb: text`  
`postcode: text`

### src_gp.encounter

One GP encounter. Observed 2026-10-06.

`encounter_id: text [PRIMARY KEY (encounter_id)]`  
`gp_patient_id: text [FOREIGN KEY (gp_patient_id) REFERENCES src_gp.gp_patient(gp_patient_id)]`  
`clinic_id: integer [FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic(clinic_id)]`  
`encounter_date: date`  
`encounter_type: text`  
`diagnosis_code: text`  
`medication_review_flag: boolean`  
`care_plan_flag: boolean`

### src_gp.gp_patient

One GP registration, not necessarily one real person. Observed 2026-10-06.

`gp_patient_id: text [PRIMARY KEY (gp_patient_id)]`  
`first_name: text`  
`last_name: text`  
`dob: date`  
`sex: character(1)`  
`postcode: text`  
`medicare_number: text`  
`clinic_id: integer [FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic(clinic_id)]`  
`enrolment_date: date`

### src_lab.lab_patient

One laboratory patient record. Observed 2026-10-06.

`lab_patient_id: text [PRIMARY KEY (lab_patient_id)]`  
`patient_name: text`  
`dob: text`  
`sex: character(1)`  
`medicare_number: text`

### src_lab.laboratory

One laboratory. Observed 2026-10-06.

`lab_id: integer [PRIMARY KEY (lab_id)]`  
`lab_name: text`  
`reporting_unit: text`

### src_lab.observation_message

One received FHIR Observation message; duplicate clinical events remain separate messages. Observed 2026-10-06.

`message_id: text [PRIMARY KEY (message_id)]`  
`lab_id: integer [FOREIGN KEY (lab_id) REFERENCES src_lab.laboratory(lab_id)]`  
`lab_patient_id: text [FOREIGN KEY (lab_patient_id) REFERENCES src_lab.lab_patient(lab_patient_id)]`  
`received_at: timestamp with time zone`  
`fhir_json: jsonb`

### src_lab.result_delivery

One recorded delivery of a message to a clinic. Observed 2026-10-06.

`delivery_id: text [PRIMARY KEY (delivery_id)]`  
`message_id: text [FOREIGN KEY (message_id) REFERENCES src_lab.observation_message(message_id)]`  
`clinic_id: integer`  
`delivered_at: timestamp with time zone`

### src_pharm.dispense

One dispensing event. Observed 2026-10-06.

`dispense_id: text [PRIMARY KEY (dispense_id)]`  
`pharmacy_patient_id: text [FOREIGN KEY (pharmacy_patient_id) REFERENCES src_pharm.pharmacy_patient(pharmacy_patient_id)]`  
`pharmacy_id: integer [FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy(pharmacy_id)]`  
`pbs_item_code: text [FOREIGN KEY (pbs_item_code) REFERENCES src_pharm.medication(pbs_item_code)]`  
`dispensed_date: date`  
`quantity: integer`  
`days_supply: integer`

### src_pharm.medication

One PBS medication item. Observed 2026-10-06.

`pbs_item_code: text [PRIMARY KEY (pbs_item_code)]`  
`drug_name: text`  
`strength: text`  
`pack_size: integer`  
`typical_daily_dose: numeric`  
`drug_class: text`

### src_pharm.pharmacy

One pharmacy. Observed 2026-10-06.

`pharmacy_id: integer [PRIMARY KEY (pharmacy_id)]`  
`pharmacy_name: text`  
`suburb: text`

### src_pharm.pharmacy_patient

One pharmacy patient registration. Observed 2026-10-06.

`pharmacy_patient_id: text [PRIMARY KEY (pharmacy_patient_id)]`  
`given_name: text`  
`surname: text`  
`date_of_birth: text`  
`medicare_number: text`  
`pharmacy_id: integer [FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy(pharmacy_id)]`

### raw.gp_clinic

One unchanged source row from src_gp.clinic. Contract draft; not observed.

`clinic_id: integer [No RAW constraint]`  
`clinic_name: text [No RAW constraint]`  
`suburb: text [No RAW constraint]`  
`postcode: text [No RAW constraint]`  
`_source_system: text`  
`_source_table: text`  
`_pipeline_run_id: bigint [Logical reference audit.pipeline_run.run_id (not enforced)]`  
`_loaded_at: timestamptz`

### raw.gp_patient

One unchanged source row from src_gp.gp_patient. Contract draft; not observed.

`gp_patient_id: text [No RAW constraint]`  
`first_name: text [No RAW constraint]`  
`last_name: text [No RAW constraint]`  
`dob: date [No RAW constraint]`  
`sex: character(1) [No RAW constraint]`  
`postcode: text [No RAW constraint]`  
`medicare_number: text [No RAW constraint]`  
`clinic_id: integer [No RAW constraint]`  
`enrolment_date: date [No RAW constraint]`  
`_source_system: text`  
`_source_table: text`  
`_pipeline_run_id: bigint [Logical reference audit.pipeline_run.run_id (not enforced)]`  
`_loaded_at: timestamptz`

### raw.gp_encounter

One unchanged source row from src_gp.encounter. Contract draft; not observed.

`encounter_id: text [No RAW constraint]`  
`gp_patient_id: text [No RAW constraint]`  
`clinic_id: integer [No RAW constraint]`  
`encounter_date: date [No RAW constraint]`  
`encounter_type: text [No RAW constraint]`  
`diagnosis_code: text [No RAW constraint]`  
`medication_review_flag: boolean [No RAW constraint]`  
`care_plan_flag: boolean [No RAW constraint]`  
`_source_system: text`  
`_source_table: text`  
`_pipeline_run_id: bigint [Logical reference audit.pipeline_run.run_id (not enforced)]`  
`_loaded_at: timestamptz`

### raw.lab_laboratory

One unchanged source row from src_lab.laboratory. Contract draft; not observed.

`lab_id: integer [No RAW constraint]`  
`lab_name: text [No RAW constraint]`  
`reporting_unit: text [No RAW constraint]`  
`_source_system: text`  
`_source_table: text`  
`_pipeline_run_id: bigint [Logical reference audit.pipeline_run.run_id (not enforced)]`  
`_loaded_at: timestamptz`

### raw.lab_patient

One unchanged source row from src_lab.lab_patient. Contract draft; not observed.

`lab_patient_id: text [No RAW constraint]`  
`patient_name: text [No RAW constraint]`  
`dob: text [No RAW constraint]`  
`sex: character(1) [No RAW constraint]`  
`medicare_number: text [No RAW constraint]`  
`_source_system: text`  
`_source_table: text`  
`_pipeline_run_id: bigint [Logical reference audit.pipeline_run.run_id (not enforced)]`  
`_loaded_at: timestamptz`

### raw.lab_observation

One unchanged source row from src_lab.observation_message. Contract draft; not observed.

`message_id: text [No RAW constraint]`  
`lab_id: integer [No RAW constraint]`  
`lab_patient_id: text [No RAW constraint]`  
`received_at: timestamp with time zone [No RAW constraint]`  
`fhir_json: jsonb [No RAW constraint]`  
`_source_system: text`  
`_source_table: text`  
`_pipeline_run_id: bigint [Logical reference audit.pipeline_run.run_id (not enforced)]`  
`_loaded_at: timestamptz`

### raw.lab_delivery

One unchanged source row from src_lab.result_delivery. Contract draft; not observed.

`delivery_id: text [No RAW constraint]`  
`message_id: text [No RAW constraint]`  
`clinic_id: integer [No RAW constraint]`  
`delivered_at: timestamp with time zone [No RAW constraint]`  
`_source_system: text`  
`_source_table: text`  
`_pipeline_run_id: bigint [Logical reference audit.pipeline_run.run_id (not enforced)]`  
`_loaded_at: timestamptz`

### raw.pharm_pharmacy

One unchanged source row from src_pharm.pharmacy. Contract draft; not observed.

`pharmacy_id: integer [No RAW constraint]`  
`pharmacy_name: text [No RAW constraint]`  
`suburb: text [No RAW constraint]`  
`_source_system: text`  
`_source_table: text`  
`_pipeline_run_id: bigint [Logical reference audit.pipeline_run.run_id (not enforced)]`  
`_loaded_at: timestamptz`

### raw.pharm_medication

One unchanged source row from src_pharm.medication. Contract draft; not observed.

`pbs_item_code: text [No RAW constraint]`  
`drug_name: text [No RAW constraint]`  
`strength: text [No RAW constraint]`  
`pack_size: integer [No RAW constraint]`  
`typical_daily_dose: numeric [No RAW constraint]`  
`drug_class: text [No RAW constraint]`  
`_source_system: text`  
`_source_table: text`  
`_pipeline_run_id: bigint [Logical reference audit.pipeline_run.run_id (not enforced)]`  
`_loaded_at: timestamptz`

### raw.pharm_patient

One unchanged source row from src_pharm.pharmacy_patient. Contract draft; not observed.

`pharmacy_patient_id: text [No RAW constraint]`  
`given_name: text [No RAW constraint]`  
`surname: text [No RAW constraint]`  
`date_of_birth: text [No RAW constraint]`  
`medicare_number: text [No RAW constraint]`  
`pharmacy_id: integer [No RAW constraint]`  
`_source_system: text`  
`_source_table: text`  
`_pipeline_run_id: bigint [Logical reference audit.pipeline_run.run_id (not enforced)]`  
`_loaded_at: timestamptz`

### raw.pharm_dispense

One unchanged source row from src_pharm.dispense. Contract draft; not observed.

`dispense_id: text [No RAW constraint]`  
`pharmacy_patient_id: text [No RAW constraint]`  
`pharmacy_id: integer [No RAW constraint]`  
`pbs_item_code: text [No RAW constraint]`  
`dispensed_date: date [No RAW constraint]`  
`quantity: integer [No RAW constraint]`  
`days_supply: integer [No RAW constraint]`  
`_source_system: text`  
`_source_table: text`  
`_pipeline_run_id: bigint [Logical reference audit.pipeline_run.run_id (not enforced)]`  
`_loaded_at: timestamptz`

### cleansed.patient_master

One canonical GP-anchored person (target 17). Contract draft; not observed.

`patient_id: text [PK]`  
`given_name: text`  
`family_name: text`  
`dob: date`  
`sex: char(1)`  
`medicare10: text`

### cleansed.patient_source_link

One resolution decision for a source patient (target 48). Contract draft; not observed.

`source_system: text [Composite PK]`  
`source_patient_id: text [Composite PK]`  
`patient_id: text [FK patient_master.patient_id; NULL unless LINKED]`  
`match_status: text`  
`match_rule: text`  
`candidate_count: integer`

### cleansed.lab_result

One parsed message including DQ-rejected and duplicate messages (target 36). Contract draft; not observed.

`message_id: text [Proposed PK retained for traceability]`  
`lab_patient_id: text [Proposed retained source reference]`  
`lab_id: integer [Proposed retained laboratory reference]`  
`observation_id: text`  
`status: text`  
`loinc_code: text`  
`value_as_received: numeric`  
`unit_as_received: text`  
`hba1c_mmol_mol: numeric(6,1)`  
`collected_date: date`  
`reported_date: date`  
`returned_to_clinic_id: integer [Logical reference clinic]`  
`returned_at: timestamptz`  
`dq_status: text`

### cleansed.encounter

One typed source encounter event. Contract draft; not observed.

`encounter_id: text [PRIMARY KEY (encounter_id)]`  
`gp_patient_id: text [FOREIGN KEY (gp_patient_id) REFERENCES src_gp.gp_patient(gp_patient_id)]`  
`clinic_id: integer [FOREIGN KEY (clinic_id) REFERENCES src_gp.clinic(clinic_id)]`  
`encounter_date: date`  
`encounter_type: text`  
`diagnosis_code: text`  
`medication_review_flag: boolean`  
`care_plan_flag: boolean`

### cleansed.dispense

One typed source dispense event. Contract draft; not observed.

`dispense_id: text [PRIMARY KEY (dispense_id)]`  
`pharmacy_patient_id: text [FOREIGN KEY (pharmacy_patient_id) REFERENCES src_pharm.pharmacy_patient(pharmacy_patient_id)]`  
`pharmacy_id: integer [FOREIGN KEY (pharmacy_id) REFERENCES src_pharm.pharmacy(pharmacy_id)]`  
`pbs_item_code: text [FOREIGN KEY (pbs_item_code) REFERENCES src_pharm.medication(pbs_item_code)]`  
`dispensed_date: date`  
`quantity: integer`  
`days_supply: integer`

### cleansed.dq_issue

One recorded data-quality issue; several may refer to a record. Contract draft; not observed.

`issue_id: bigint [Proposed PK]`  
`table_name: text`  
`record_id: text`  
`rule_code: text`  
`detail: text`

### curated.dim_patient

One canonical patient. Contract draft; not observed.

`patient_key: integer [PK]`  
`patient_id: text [UQ]`  
`display_name: text`  
`date_of_birth: date`  
`sex: char(1)`  
`home_clinic_key: integer [FK]`

### curated.fact_encounter

One LINKED encounter; target 28. Contract draft; not observed.

`encounter_key: integer [PK]`  
`encounter_id: text [UQ]`  
`patient_key: integer [FK]`  
`date_key: integer [FK]`  
`clinic_key: integer [FK]`  
`encounter_type: text`  
`diagnosis_code: text`  
`medication_review_flag: boolean`  
`care_plan_flag: boolean`

### curated.fact_lab_result

One VALID result linked to a canonical patient; target 32. Contract draft; not observed.

`lab_result_key: integer [PK]`  
`message_id: text [UQ]`  
`observation_id: text`  
`patient_key: integer [FK]`  
`collected_date_key: integer [FK]`  
`reported_date_key: integer [FK]`  
`lab_key: integer [FK]`  
`test_key: integer [FK]`  
`hba1c_mmol_mol: numeric(6,1)`  
`result_returned_flag: boolean`

### curated.fact_dispense

One LINKED dispense; target 65. Contract draft; not observed.

`dispense_key: integer [PK]`  
`dispense_id: text [UQ]`  
`patient_key: integer [FK]`  
`date_key: integer [FK]`  
`pharmacy_key: integer [FK]`  
`medication_key: integer [FK]`  
`quantity: integer`  
`days_supply: integer`

### audit.identity_truth

One synthetic source identity answer-key row; NEVER used by matching. Contract draft; not observed.

`true_person_id: text`  
`source_system: text [Proposed composite key]`  
`source_patient_id: text [Proposed composite key]`

### audit.test_result

One acceptance-test result; history/key policy awaits F. Contract draft; not observed.

`test_id: text`  
`description: text`  
`expected: text`  
`actual: text`  
`passed: boolean`

### reporting.vw_uc1_care_gaps

One patient classified with a care gap. Contract draft; not observed.

`patient_id: text [View: no physical PK/FK]`  
`display_name: text [View: no physical PK/FK]`  
`home_clinic: text [View: no physical PK/FK]`  
`last_test_date: date [View: no physical PK/FK]`  
`last_hba1c_mmol_mol: numeric [View: no physical PK/FK]`  
`first_review_date: date [View: no physical PK/FK]`  
`care_gap_status: text [View: no physical PK/FK]`  
`as_of_date: date [View: no physical PK/FK]`

### reporting.vw_uc2_pdc

One eligible patient and drug class. Contract draft; not observed.

`patient_id: text [View: no physical PK/FK]`  
`display_name: text [View: no physical PK/FK]`  
`drug_class: text [View: no physical PK/FK]`  
`fills_counted: integer [View: no physical PK/FK]`  
`covered_days: integer [View: no physical PK/FK]`  
`window_days: integer [View: no physical PK/FK]`  
`pdc: numeric [View: no physical PK/FK]`  
`adherence_status: text [View: no physical PK/FK]`  
`window_start: date [View: no physical PK/FK]`  
`window_end: date [View: no physical PK/FK]`  
`as_of_date: date [View: no physical PK/FK]`

### reporting.vw_uc3_hba1c_trend

One patient with at least one result in the trend window. Contract draft; not observed.

`patient_id: text [View: no physical PK/FK]`  
`display_name: text [View: no physical PK/FK]`  
`n_results: integer [View: no physical PK/FK]`  
`first_test_date: date [View: no physical PK/FK]`  
`first_hba1c: numeric [View: no physical PK/FK]`  
`last_test_date: date [View: no physical PK/FK]`  
`last_hba1c: numeric [View: no physical PK/FK]`  
`change_mmol_mol: numeric [View: no physical PK/FK]`  
`trend_status: text [View: no physical PK/FK]`  
`best_pdc: numeric [View: no physical PK/FK]`  
`rising_despite_adherence: boolean [View: no physical PK/FK]`  
`as_of_date: date [View: no physical PK/FK]`

### reporting.vw_uc4_care_path_breaks

One missing-delivery event or overlapping pharmacy pair. Contract draft; not observed.

`patient_id: text [View: no physical PK/FK]`  
`display_name: text [View: no physical PK/FK]`  
`break_type: text [View: no physical PK/FK]`  
`detail: text [View: no physical PK/FK]`  
`event_date: date [View: no physical PK/FK]`

## Final model acceptance

D/E review the model and dictionary, C confirms RAW/source contracts, F confirms audit test output. Reconcile every field against the same frozen release after the two-run integration test. A diagram can be internally consistent while SQL is wrong; report discrepancies to the owner rather than silently changing their implementation.
