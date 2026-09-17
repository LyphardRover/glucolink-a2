# Checkpoint release checklist

Owner: B / Zhihao Zhang. This is a B-only release ready for local reproduction and design review. It is not the complete integrated group release.

| Run order | Owner | Required handoff | Status in this package |
|---|---|---|---|
| 0 | A | Scope and UC3 rule v0.1 | Team-plan rule referenced; owner confirmation pending |
| 1 | B | B_create_database.psql or SQL alternative, B_setup.sql, verification, readme | Included and locally checked |
| 2 | C | Six CSVs, manifest, source/RAW table SQL and loader/commands | Not received in this release |
| 3 | D | D_clean_and_link_sample.sql, readme and quality/link output | Not received in this release |
| 4 | E | E_curated_and_UC3_sample.sql, field dictionary, actual result | Not received in this release |
| 5 | F | Independent tests, evidence and demo order | Not received in this release |

## B release contents

- B_setup.sql: eight namespaces in a guarded transaction.
- B_create_database.psql: rerunnable psql database creation step; B_create_database.sql is an alternative for a SQL editor.
- B_run_setup.ps1: convenience runner using distinct connections for create/setup.
- 00_environment_check.sql, B_verify_setup.sql, B_capture_baseline.sql: read-only inspection.
- B_setup_readme.md: prerequisites, local/Compose addresses, run order and recovery.
- B_design_v0.1.pdf, B_design_v0.1.drawio and diagram PNGs: architecture, conceptual model and small logical model. Business objects are proposals, not deployed tables.
- B_logical_dictionary_v0.1.md: object grain, columns/types/keys and review points.
- B_peer_check.md: pending second-member reproduction and D/E/F decisions.
- B_teaching_CN.md: beginner explanation and presentation preparation.
- evidence/: actual B local runs, baseline and validation status.
- B_release_manifest.csv: SHA-256 inventory of release files except the manifest itself.

## Release gates

- B local first and repeated setup: PASS (see evidence).
- Wrong-database protection: PASS (expected rejection recorded).
- Diagrams/dictionary internal alignment: checked during B authoring; D/E agreement pending.
- Second member local reproduction: NOT RUN.
- C/D/E code and fixture freeze: PENDING.
- F full integration and UC3 tests: NOT RUN.

Update version and manifest after any file changes. The shared folder location and integration machine must be recorded by the team; this package has not been uploaded or sent to anyone.
