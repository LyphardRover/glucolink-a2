# Package B — design and SQL report draft

Owner: Zhihao Zhang. Date: 2026-10-06. AI-assisted draft for human review. Maps to report (v)a–e and (vi)c; final report headings and word limits must be checked by A. E reviews design; F reviews SQL explanation. This document describes the agreed target design and separately identifies observed implementation. It does not claim the final pipeline or dashboards passed.

## (v)a. Requirements and scope

GlucoLink integrates three synthetic operational sources: GP registrations/encounters, laboratory FHIR Observation messages and delivery evidence, and pharmacy dispensing records. The prototype supports four rule-based outputs: care gaps, proportion of days covered (PDC), HbA1c trends, and care-path breaks. Its fixed analysis date is 2026-09-01. These are educational decision-support rules, not evidence of clinical benefit or actual medicine ingestion.

The target contains 48 source identity records and 17 canonical GP-anchored people. A source registration is not automatically a unique person: Sarah has duplicate GP records, one laboratory identity is ambiguous, and one pharmacy identity has no GP master. These cases justify explicit linkage decisions instead of joining systems on names alone. Expected counts are acceptance targets, not evidence of current shared data.

## (v)b. Architecture and operation

One Google Cloud VM hosts PostgreSQL and CloudBeaver behind the existing HTTPS proxy. Team members use their own web accounts to reach the same shared project database. A connection entry is a route to a database; six connection entries do not imply six independent copies. Committed changes are shared, but an already-open query result is a snapshot and does not itself prove automatic screen refresh.

Eight schemas separate responsibilities: src_gp/src_lab/src_pharm (C, with B lab fixtures); raw (C); cleansed (D); curated (E); reporting (A/B parameters, D UC2/UC4, E UC1/UC3); audit (B/C run log, C identity truth, F test results). RAW retains source payload plus _source_system, _source_table, _pipeline_run_id and _loaded_at. CLEANSED standardises representations, records quality outcomes and resolves identities. CURATED provides conformed dimensions and event facts. Per v3 D8, CURATED may read both RAW references and CLEANSED clinical/identity data; home clinic comes from the lowest GP registration ID, not a recent-visit guess.

Three audit tables have different jobs. pipeline_run records one explicit pipeline execution; it is not a record of every user's SQL edit. identity_truth is an evaluation answer key and must never feed identity matching. test_result records acceptance comparisons. Reporting views feed the four business outputs. Metabase remains a candidate until resource, access, course and query checks pass; Excel export is the defined fallback. No final dashboard deployment is claimed here.

## (v)c. Conceptual relationships

The ten conceptual entity types are Patient, Source Patient Record, Clinic, Encounter, Laboratory, Observation/Result, Result Delivery, Pharmacy, Medication and Dispense. A canonical patient can have multiple source records, but a source record can remain unresolved. Encounters belong to a GP registration and clinic. Messages refer to laboratory patients and laboratories. A result can have zero or multiple delivery records; absence is meaningful. Dispenses connect pharmacy registrations, pharmacies and medication items. Use LAB consistently as the laboratory source label.

Optionality matters: an unresolved laboratory identity must remain visible for review; forcing it into a patient would create false longitudinal results. Similarly, a missing delivery row must not be manufactured simply to make a relationship mandatory. A message ID identifies receipt; an Observation ID identifies the clinical observation and supports duplicate detection.

## (v)d. Logical model and data dictionary

The accompanying data_dictionary_v1.xlsx (with a Markdown companion) covers 47 objects and 338 fields. It reports twenty observed table definitions and marks the remaining objects as contract/design drafts. Types, keys, nullability and defaults are not interchangeable: a PK identifies a row, an FK checks a reference, NOT NULL requires a value, and a default supplies one when omitted. The draft documents actual source nullability rather than claiming stronger constraints than PostgreSQL enforces.

Source tables preserve operational keys. RAW intentionally avoids copying source constraints so that defects remain inspectable. CLEANSED keeps per-message DQ outcomes and per-source linkage status. CURATED uses seven conformed dimensions (patient, date, clinic, lab, pharmacy, medication, test) and three event-grain facts. Date plays multiple roles for laboratory collection and reporting. Surrogate dimension keys separate warehouse joins from source identifiers while retained source event IDs support reconciliation.

Each fact has a precise grain: one linked encounter, one linked VALID laboratory message, or one linked dispensing event. Joining all three facts directly on patient multiplies rows (for example two tests times three fills gives six join rows). Aggregate each fact to the required reporting grain before combining results. Dictionary proposals for unfinished D/E objects require their review and must be reconciled with the frozen SQL before submission.

## (v)e. Decisions, alternatives and limits

|Decision|Reason|Tradeoff / limit|
|---|---|---|
|Schemas in one PostgreSQL database|Practical isolated namespaces and shared access for the workshop prototype|Not independent security or server boundaries by themselves|
|Preserve original JSON in source/RAW|Traceable reprocessing and explicit malformed/mismatched cases|Parsing and unit validation remain necessary|
|Deterministic R1/R2 identity rules plus REVIEW|Avoid guessing when candidate identity is ambiguous|Some events stay outside patient facts until resolved|
|Common mmol/mol result representation|Makes longitudinal comparison meaningful|Reject incompatible/empty units; do not convert blindly|
|Australia/Sydney calendar interpretation|Clinical day follows the project timezone|UTC and Sydney dates can differ; cast timestamp before date|
|One text-valued parameter interface|All views use one agreed nine-value rule set|Each consumer must cast and validate types|
|Full refresh for small synthetic inputs|Simple reproducibility and clear test expectations|Requires coordinated load order and a short write pause|
|Transactions, finite lock waits and scoped restore|Protect concurrent work and avoid partial replacement|A successful commit still needs a separate-session check|
|Read-only reporting connector|Limits dashboard access to agreed outputs|View recreation requires rechecking grants|

Percent HbA1c converts as (% − 2.15) × 10.929, rounded to one decimal under the project contract. Rejected-unit values remain NULL. Duplicate, future-date and empty-unit cases are intentional acceptance fixtures. PDC counts distinct covered days clipped to the agreed window; overlapping supply is not double-counted. A high PDC measures supplied coverage, not consumption. Trend logic and tie-breaking must follow D/E's final views and the project rules; B does not change those implementations.


### Additional comparisons required by Task Cards v3

- **Three source schemas versus three databases and postgres_fdw.** The prototype keeps src_gp, src_lab and src_pharm in one database so the team can demonstrate different source contracts and joins without provisioning three independently administered servers. A separate-database design with foreign tables would better demonstrate network and credential boundaries, but adds connection, grant and availability dependencies. Namespace separation alone does not simulate those boundaries. The team role cannot be assumed to create databases or install extensions; capability evidence must state the tested identity.
- **Eighteen designed people versus A1's 10,000-record files.** The smaller fixture intentionally exposes duplicate registration, ambiguous linkage, missing delivery and invalid laboratory values with hand-checkable expected results. Forty-eight source identities and seventeen expected GP-anchored masters are different counts from eighteen designed people. This improves traceability of correctness tests, but provides no evidence of throughput or scalability at A1 volume. Larger-volume performance testing would be separate work.
- **UC4 SQL versus a graph database.** UC4 has a fixed set of relationships and time-window checks available in the shared PostgreSQL pipeline. SQL keeps its output reproducible in the same 00–10 run and accessible to the reporting tools. A graph representation could make exploratory paths more explicit, but would introduce another data store and synchronisation step. The choice is suitable for the bounded assignment query; it is not a claim that SQL is always preferable for graph analysis.
- **GP-only masters and conservative linkage.** GP anchoring supplies the agreed master population and home-clinic rule. REVIEW and UNMATCHED records remain explicit rather than inventing a match. This sacrifices apparent linkage completeness to avoid contaminating facts with uncertain people, and means the prototype is not a universal identity registry.
- **PDC overlap simplification versus a full PQA specification.** The assignment uses its agreed fixed window and distinct covered-day calculation. Overlapping supply is counted once under that contract. The report must not describe this as a validated implementation of every PQA eligibility, stockpiling, inpatient or medication-switch rule. Those additional measure specifications require separate definition and validation; F/A should cite any external specification actually used.
- **Shared VM and dashboard choice.** One small VM makes collaboration and a common database straightforward, but it is a single availability/resource boundary. The text-valued parameter table centralises the nine rules while requiring explicit casts. Metabase would offer reusable interactive questions; Excel export avoids a second always-on application but creates snapshots that must be re-exported after a pipeline update. F-3 chooses Metabase only if, by Thursday evening, the tutor has not refused an external tool and B supplies a working URL plus read-only login; otherwise the agreed Excel route starts Friday. No affirmative tutor approval is invented here.

## (vi)c. SQL blocks and design traceability

|File/block|Purpose|Evidence and failure behaviour|
|---|---|---|
|00 header and transaction|Records owner, sources, dependencies and rerun behaviour; limits lock wait to 5s and statements to 60s|Portable database name; object-owner role chosen outside SQL|
|Eight CREATE SCHEMA IF NOT EXISTS + comments|Creates/document namespaces without replacing teammate objects|Eight comments checked in shared database|
|audit.pipeline_run IF NOT EXISTS|Creates run-log interface with identity run_id, start/status defaults and checks|Preserves prior rows and sequence; incompatible existing structures must be reviewed before deployment|
|reporting.rule_parameter IF NOT EXISTS|Creates typed-at-read configuration interface|Preserves table identity and dependent views|
|TRUNCATE + INSERT + assertion|Atomically replaces all nine named parameters and validates their exact values/descriptions|Any error rolls back the transaction|
|02b preflight|Checks existing source-table structure, parent identities/institutions and C handoff counts|Fails before clearing when prerequisites are incomplete|
|02b paired TRUNCATE and INSERT|Replaces only observation_message and result_delivery in one transaction, without CASCADE|36 messages / 34 deliveries; unrelated FK prevents replacement instead of expanding deletion|
|02b final comparisons|Checks fixture content, references and intended exceptions before commit|No CREATE TABLE, DROP TABLE or downstream pipeline rerun|

00 was deployed on 2026-10-06 at 12:36:35 UTC after backup and restoration testing. The deployed code was b4b5f50; the later d254f1b change only corrects its design-document link. Eight schema comments and all nine parameter values were checked; nineteen non-target table contents and associated metadata were unchanged in that release comparison. The twelve isolated component scenarios passed. This is not a claim that the full 00–10 integration passed.

02b is in PR #4 at ddc3e806. Its isolated tests passed, but the shared load remains blocked by C's final source-data handoff: encounter and dispense tables were still empty at the latest inspection and identity_truth was absent. Loading now would give invalid evidence. B should release only after the agreed counts, IDs and structures are verified and C confirms 02 will not immediately be rerun.


### Full reproducible run order (implementation owners retain their files)

The order below is the v3 contract. Run all files from one frozen GitHub commit in a fresh database, then repeat the whole order. The current component checks do not substitute for this integration test. The exact 04 filename and any split 08 contributions must be taken from the frozen repository; do not invent a filename or silently omit a stage.

|Stage|Owner|Purpose / dependency|
|---|---|---|
|00_setup.sql|B|Create eight namespaces, run-log interface and nine parameters|
|01_src_tables.sql|C|Create eleven operational source tables and keys|
|02_src_data.sql|C|Load reference data, patients, 28 encounters, 68 dispenses and 48 truth rows|
|02b_src_lab_messages.sql|B|Load the complete 36 laboratory messages and 34 deliveries after C's final 02|
|03_raw_extract.sql|C|Copy eleven sources with provenance; add exactly one pipeline_run per execution|
|04 cleansing stage (repository filename)|D|Normalise RAW patients/events; validate laboratory messages and preserve DQ outcomes|
|05_identity_resolution.sql|D|Build GP-anchored masters and MATCHED / REVIEW / UNMATCHED links without using identity_truth|
|06_curated_dimensions.sql|E|Build seven conformed dimensions, including linked patients|
|07_curated_facts.sql|E|Load encounter, valid laboratory and dispensing facts using current dimension keys|
|08_reporting_views.sql|D/E|Create four reporting views; UC2 precedes dependent UC3; read curated plus parameters|
|09_tests.sql|F|Persist Appendix C acceptance comparisons in audit.test_result; zero failures required|
|10_demo_queries.sql|F|Run commented demonstration queries used in the video/dashboard evidence|

Code links: [00 and setup evidence (PR #3)](https://github.com/LyphardRover/glucolink-a2/pull/3), [02b and component tests (PR #4)](https://github.com/LyphardRover/glucolink-a2/pull/4), [B design/dictionary/report (PR #5)](https://github.com/LyphardRover/glucolink-a2/pull/5). Final submission must replace moving PR references with the actual frozen commit. The integration handover describes stop conditions, backup, rerun hazards and release evidence.

## Finalisation checklist

- [ ] D/E confirm logical model, nullability and view contracts against final SQL.
- [ ] C completes final 02; B performs coordinated, backed-up 02b release.
- [ ] F and B run one frozen commit through 00–10 twice in a new empty database; all Appendix C tests pass.
- [ ] Capture final query/result/database screenshots and same-commit report/video references.
- [ ] Resolve Metabase course/access conditions or document Excel fallback by the agreed deadline.
- [ ] Replace draft limitations with verified results; retain honest AI disclosure and actual personal hours.

References are the team's Build Plan v2 (sections 5, 6, 8 and appendices), Task Cards v3 D1/D8/B1–B6, current schema inspection, and linked B PRs #3/#4/#5. No external clinical validation is claimed.
