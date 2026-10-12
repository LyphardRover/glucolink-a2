# GlucoLink logical model

Database: glucolink_a2. Maintainer: Zhihao Zhang (Package B). Updated 11 October 2026.

The model covers 47 implemented objects (43 tables and four views), 338 columns and 24 enforced foreign-key relationships across eight schemas. Definitions were read from the rebuilt glucolink_a2_test catalog at main 9a499ce4c1564dfdc06e5a521d714d6728337332 after both full 00–09 runs passed 46/46 tests.

## Definition and validation status

All modeled objects are now implemented. The test database began empty for round 1; round 2 repeated the same 11 scripts in the same database. Both rounds passed, and audit.pipeline_run contains exactly two SUCCESS rows. The separate read-only 10_demo_queries.sql is outside this run.

patient_master.postcode has been removed. patient_source_link.patient_id is a nullable, enforced FK to patient_master.patient_id. The 12 fact-to-dimension FKs, four reporting views and audit.test_result were verified in the rebuilt catalog.

PK = primary key; FK = foreign key; UQ = unique. Solid crow-foot lines show enforced FKs. A circle means zero, a bar means one and a crow foot means many. Views have no PK/FK constraints. View nullability is the database catalog declaration; it does not mean every row contains NULL. The dashed UC2→UC3 arrow is a query dependency.

## Model pages

- [Overview: all eight schemas and 47 objects](logical_model_v1.png)
- [GP source tables](logical_model_detail_src_gp.png)
- [Laboratory source tables](logical_model_detail_src_lab.png)
- [Pharmacy source tables](logical_model_detail_src_pharm.png)
- [RAW source copies and provenance](logical_model_detail_raw.png)
- [CLEANSED records and patient identity](logical_model_detail_cleansed.png)
- [CURATED dimensions and facts](logical_model_detail_curated.png)
- [Reporting parameters and four use-case views](logical_model_detail_reporting.png)
- [Audit run history, truth data and test results](logical_model_detail_audit.png)

## Layer boundaries

Sources feed RAW, then CLEANSED. CURATED reads RAW reference data and CLEANSED records. Reporting reads CURATED and shared parameters; UC3 also reads UC2 for best PDC. CLEANSED and reporting results feed audit checks. audit.identity_truth is an evaluation answer key and is not used to assign patient identities. Excel charts use exported reporting-view results.

See [data dictionary](data_dictionary_v1.md) for each field, default, constraint, owner and grain; see [full rebuild evidence](../tests/B_00_09_rebuild_20261011.md) for the runtime record.
