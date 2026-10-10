# GlucoLink logical model

Database: glucolink_a2. Maintainer: Zhihao Zhang (B). Updated 9 October 2026.

The overview lists all 47 objects across the eight schemas. The editable drawio file contains this overview and eight detailed pages with all 339 columns, keys, nullability and 24 crow-foot relationships. UC3 also shows its dependency on UC2.

## Definition and validation status

The 8 October catalog at 3f7e03e verified 35 table definitions. The published 04 d4ed184 adds four CLEANSED definitions; 07 833d05d adds three fact definitions. B reviewed those seven definitions as code on 9 October. They are not included in the earlier 00–06 runtime proof.

Five objects remain planned: audit.test_result and reporting.vw_uc1_care_gaps, vw_uc2_pdc, vw_uc3_hba1c_trend and vw_uc4_care_path_breaks. Planned PK / Planned FK means a design constraint awaiting SQL. Views have no primary key. TBD means physical nullability is not yet defined.

Solid relationships are FKs in the cited SQL/catalog. Eleven were observed in the earlier catalog, and twelve fact-to-dimension FKs are now declared by 07 but await runtime acceptance. The patient_source_link.patient_id relationship remains dashed because 05 dcc53c6 has no declared FK. That version still includes patient_master.postcode. D owns both pending changes.

## Pages

- Overview: eight schema boxes containing every table and view, with layer dependencies.
- src_gp, src_lab, src_pharm: source entities and declared source FKs.
- raw: eleven source copies and their four provenance fields; no inherited source FKs.
- cleansed: identity records, lab results, typed event tables and dq_issue.rule. No encounter/dispense FK back to source tables.
- curated: seven dimensions and three fact tables, with keys declared in 06/07.
- reporting: rule_parameter and four planned views; UC3 reads UC2 for PDC.
- audit: pipeline_run, identity_truth and planned test_result.

The architecture diagram shows the shared environment and Excel output. The conceptual diagram explains the ten business entities. This logical model provides their table and column design. See data_dictionary_v1.md for each object’s grain, owner and definition status.
