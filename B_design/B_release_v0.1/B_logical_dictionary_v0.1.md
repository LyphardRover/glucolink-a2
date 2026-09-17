# GlucoLink checkpoint logical dictionary

Owner: B / Zhihao Zhang. Version 0.1, 16 September 2026. Database: **glucolink_a2**.

**Status:** eight namespaces implemented; the business tables, views and constraints below are a B design proposal awaiting C/D/E review. No business DDL is executed by B_setup.sql. This dictionary and page 3 of B_design_v0.1 describe the same five-table checkpoint model. Only core columns appear inside the diagram boxes; this document adds supporting fields.

## 1 Notation and checkpoint assumptions

PK = primary key, identifies one row. FK = proposed enforced reference to another table's key. UQ = unique. NN = not null. NULL means absent/unknown; it is not a made-up value. PostgreSQL enforces constraints when actually created; they do not prove clinical correctness or identity accuracy.

This small model stores the **current released identity decision** for each source patient and one current analytical row per eligible event. It does not retain multiple concurrent identity/model versions in the same keys. run_id provides provenance, not a complete history key. Later history/versioning needs a revised model. Names, types, statuses and timestamp interpretation are proposals until D/E agree and implement them.

## 2 Sources and RAW contract for C review

| Input | Proposed source object | Proposed RAW object | One input row |
|---|---|---|---|
| gp_patients.csv | src_gp.patients | raw.gp_patients | One source GP patient record |
| lab_patients.csv | src_lab.patients | raw.lab_patients | One source pathology patient record |
| pharmacy_patients.csv | src_pharm.patients | raw.pharmacy_patients | One source pharmacy patient record |
| encounters.csv | src_gp.encounters | raw.encounters | One GP encounter record |
| dispenses.csv | src_pharm.dispenses | raw.dispenses | One pharmacy dispensing record |
| lab_results_raw_fhir.csv | src_lab.lab_results_raw_fhir | raw.lab_results_raw_fhir | One received lab record including JSON text |

Source namespaces exist; these table names are not yet deployed. C owns explicit table SQL and the real A2 sample. Use A1-compatible headers and record unused fields; previous header inspection is not approval of a new fixture. GP/PATH/PHARM are source labels; `src_lab` maps to PATH. Source-local patient IDs require the source label as well as the ID to identify a record.

Preserve received IDs, dates and raw_fhir_json as text. Proposed additional RAW columns are `_load_run_id text`, `_source_file text`, `_source_row_number bigint`; their combination identifies an ingestion occurrence. Preserve intentional duplicated input events for D/F to inspect; do not impose a business event key on RAW that silently discards them. C/D agree empty/null handling and batch rerun policy. Do not supply identity_truth or scenario answers to the matcher. Flat and JSON lab files are representations of the same events; this checkpoint loads only the JSON representation.

## 3 CLEANSED tables owned by D

### cleansed.patient_master

One row means one accepted unified patient identity.

| Column | Proposed PostgreSQL type | Constraint | Meaning |
|---|---|---|---|
| trusted_patient_id | text | PK, NN | D's stable accepted identity ID for this release |
| canonical_name | text | Nullable | Canonical display name if D can establish one |
| date_of_birth | date | Nullable | Validated canonical birth date; conflicting cases need resolution |
| run_id | text | NN | Producing run identifier |

The ID is an output of matching, not a truth label fed into the matcher. Display attributes are not a substitute for identity evidence.

### cleansed.patient_source_link

One row means one source-specific patient and the current resolution decision. A master may have zero or many source links; each link references zero or one master.

| Column | Proposed type | Constraint | Meaning |
|---|---|---|---|
| source_system | text | Composite PK, NN | GP, PATH or PHARM |
| source_patient_id | text | Composite PK, NN | Local ID within that source |
| trusted_patient_id | text | Nullable FK to patient_master | Present only for an accepted decision |
| match_status | text | NN | Proposed literals accepted / unresolved, subject to D/F confirmation |
| match_rule_id | text | Nullable | Which matching rule produced the decision, if one applied |
| run_id | text | NN | Producing run |

Proposed CHECK: accepted implies trusted_patient_id IS NOT NULL; unresolved implies trusted_patient_id IS NULL. Agree any additional statuses explicitly. With this two-state proposal, all other literals should be rejected after input validation. Multiple candidates do not create multiple accepted rows for the same composite key; keep evidence in a separate review output if needed.

### cleansed.lab_results_clean

One row means one reconciled pathology event and its extraction/quality outcome. RAW retains original occurrences; D must define how duplicate/conflicting events are reconciled.

| Column | Proposed type | Constraint | Meaning |
|---|---|---|---|
| source_system | text | Composite PK, NN | PATH for checkpoint lab events |
| result_id | text | Composite PK, NN | Source lab-event ID |
| source_patient_id | text | Nullable | Local pathology patient ID; use this name consistently at D-to-E handoff |
| collected_datetime | timestamptz | Nullable | Validated collection time |
| reported_datetime | timestamptz | Nullable | Validated reporting time |
| loinc_code | text | Nullable | Selected lab code from appropriate coding system |
| value | numeric | Nullable | Extracted measurement; no forced rounding scale here |
| unit | text | Nullable | Received/validated unit |
| source_result_status | text | Nullable | Source result status, including final |
| quality_status | text | NN | Proposed valid / rejected, subject to D/F agreement |
| quality_reason | text | Nullable | Explanation of exclusion; multiple reasons need an agreed representation |
| run_id | text | NN | Producing run |

Logical join to source_link uses **both** (source_system, source_patient_id). This is a left join with zero or one match; this draft does **not** require an enforced FK for that join, so unknown/missing patient references can remain visible as quality outcomes. Do not insert unknown patients solely to satisfy a foreign key.

For invalid or missing event IDs, keep the rejected occurrence in RAW/quality output; it cannot enter this event-keyed table without a deliberate key policy. Do not lose it from reconciliation. Invalid JSON must be handled before casting to jsonb. The diagram shows lab-event lineage, not a promise that every raw record is accepted.

## 4 CURATED tables owned by E

### curated.dim_patient

One row means one accepted patient represented in this checkpoint's analytical model. No slowly changing dimension history is implemented in this proposal.

| Column | Proposed type | Constraint | Meaning |
|---|---|---|---|
| patient_key | bigint generated by default as identity | PK, NN | Local warehouse surrogate key |
| trusted_patient_id | text | UQ, NN, FK to patient_master | Traceable accepted identity |
| canonical_name | text | Nullable | Display attribute copied from master if needed |
| date_of_birth | date | Nullable | Canonical attribute copied from master if needed |
| run_id | text | NN | Producing run |

Each dimension row has one master; a master has zero or one dimension row. Different laptops can produce different patient_key values; do not combine these numbers across machines.

### curated.fact_lab_result

One row means **one included reconciled lab event**, not one patient. Several tests for the same patient mean several fact rows. Proposed admission: accepted identity and valid final 4548-4 percent result; UC3 still applies its observation window explicitly. D/E must confirm this checkpoint admission rule.

| Column | Proposed type | Constraint | Meaning |
|---|---|---|---|
| fact_lab_key | bigint generated by default as identity | PK, NN | Local analytical event key |
| patient_key | bigint | NN, FK to dim_patient | Patient to which this event belongs |
| source_system | text | Composite UQ, NN | Event source |
| result_id | text | Composite UQ, NN | Event ID; pair with source identifies event |
| collected_datetime | timestamptz | NN | Valid collection time |
| reported_datetime | timestamptz | NN | Valid reporting time |
| loinc_code | text | NN | Validated code |
| value | numeric | NN | Comparable measured value |
| unit | text | NN | Percent for this checkpoint |
| run_id | text | NN | Producing run |

Proposed composite FK (source_system, result_id) references lab_results_clean. Each fact has one clean event; each clean event produces zero or one fact. Rejected/unresolved events must not acquire a fact merely to make counts match. These proposed FKs imply rebuild/deletion order must respect dependencies: facts before dimensions when clearing an agreed checkpoint snapshot; build parents before children. C/D/E own the actual controlled rerun implementation.

## 5 Reporting view owned by E and tested by F

`reporting.vw_uc3_hba1c_trend`: one accepted patient with at least one eligible result, for the fixed checkpoint observation date. A/E/F must agree whether zero-history patients appear in a separate output.

| Column | Proposed type | Meaning |
|---|---|---|
| trusted_patient_id | text | Patient represented by this output |
| first_result_date, last_result_date | date | Calendar dates in the agreed reporting timezone |
| first_value, last_value | numeric | First and last eligible measurements |
| unit | text | % |
| change_pp | numeric, nullable | Last minus first; NULL with only one eligible result |
| trend_status | text | increase / decrease / unchanged / insufficient_history; proposed literals |
| as_of_date | date | 2026-09-01 for the checkpoint |

Team-plan rule: collection dates 2026-07-01 through 2026-09-01 inclusive, reported by the observation date; accepted identities; valid final code 4548-4 and unit %. No unit conversion. Order by collected_datetime then documented result_id tie-breaker. One result has insufficient_history and NULL change; equal values have unchanged. The timezone for interpreting naive input and calendar-date boundaries is pending A/D/E confirmation. The observed server session timezone is not automatically the business timezone.

The view reads facts joined to patient dimension. Do not join every GP encounter or dispensing event directly to every lab result; that multiplies events. Three-source linkage is a separate demonstration based on patient_source_link.

## 6 Logical relationships matching page 3

| Relationship | Cardinality / constraint |
|---|---|
| source_link -> patient_master | Each link 0..1 master; each master 0..many links; nullable FK |
| lab_results_clean -> source_link | Each clean event 0..1 source link; each link 0..many events; logical composite left join only |
| dim_patient -> patient_master | Each dimension row 1 master; each master 0..1 dimension row; UQ + FK |
| fact_lab_result -> dim_patient | Each fact 1 patient dimension; each dimension 0..many facts; FK |
| fact_lab_result -> lab_results_clean | Each fact 1 clean event; each clean event 0..1 fact; composite FK + UQ |
| reporting view <- fact and dimension | Derived aggregation, not an FK relation |

## 7 Design rationale and remaining decisions

Separate source namespaces make the three simulated source boundaries explicit; raw preserves received evidence; cleansed separates identity/quality logic from curated analysis. Master/link normalisation prevents repeating the entire patient identity in every source link. The small star model makes event grain explicit and supports repeatable UC3 aggregation. These choices add stage copies and orchestration work; they do not establish a full commercial lakehouse.

The workbook's medallion pattern informs processing order; GlucoLink patient matching, JSON semantics and measurement rules require separate implementation. Audit is currently an empty namespace. A future pipeline_run design needs run IDs, step/file versions, counts/status/time and failure handling; no audit table or logging writer is part of this B release.

Before integration: C confirms the six input/RAW definitions; D/E confirm exact fields, key types, statuses and admission logic; A/D/E/F confirm timezone and expected UC3 examples. Record decisions in B_peer_check.md and release a consistent new version. No teammate approval is inferred from this document.
