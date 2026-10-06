# B release, environment and integration handover

Prepared 2026-10-06 by B (Zhihao Zhang), with AI assistance. Evidence-backed status, not a statement that teammates accepted this handover. No teammate files or shared task cards are modified by this package. Team communication below is a draft for Zhihao to send.

## Current environment evidence

|Item|Observed result|Meaning|
|---|---|---|
|Database|glucolink_a2 on shared Google Cloud VM|Team connections target a shared database, not synchronised copies|
|PostgreSQL|15.19 (Debian 15.19-1.pgdg12+2), 64-bit|Pin this environment in reproduction notes|
|SHOW timezone|Etc/UTC|Clinical dates explicitly use Australia/Sydney; no server-wide timezone change|
|glucolink_admin|Superuser and CREATEDB|Administrator can create isolated test databases|
|a2_team_editor and inspected member roles|No superuser or CREATEDB|Do not promise members can create databases|
|postgres_fdw|Available version 1.1; not installed|Availability is not installation permission; administrator approval/execution required for an untrusted extension|
|VM memory|3908 MiB total; 2789 MiB available at inspection; no swap|Snapshot, not a sustained capacity guarantee|
|VM disk|29 GiB filesystem; about 20 GiB available|Recheck before backup/new service|
|Existing services|PostgreSQL healthy; CloudBeaver and HTTPS proxy running|No existing image upgrade or restart performed for this documentation work|

### Repeatable read-only capability evidence

```sql
SELECT current_database(), current_user, version();
SHOW timezone;
SELECT rolname, rolsuper, rolcreatedb FROM pg_roles
WHERE rolname IN (current_user, 'glucolink_admin', 'a2_team_editor');
SELECT name, default_version, installed_version
FROM pg_available_extensions WHERE name = 'postgres_fdw';
```

Do not install postgres_fdw merely to produce a screenshot in the shared database. If an actual installation probe is required, an administrator can test it in an explicitly disposable isolated database, record the result and remove only that test database through the agreed process.

## Releases already available

- PR #3: 00_setup.sql. Shared deployment used b4b5f50 on 2026-10-06 12:36:35 UTC (20:36:35 China; 23:36:35 Sydney). Later d254f1b changes a comment link only; no rerun is needed for that comment.
- Private backup: /opt/glucolink-a2/b-v3-20261006/backups/before_00_20261006T123635Z.dump, with checksum sidecar. This particular backup was restored before that deployment. New backups require their own verification.
- 00 evidence: evidence/B_00_shared_parameters_20261006.png and evidence/B_00_shared_schemas_20261006.png (capture date retained in filenames).
- PR #4: 02b_src_lab_messages.sql at ddc3e806. Component tests passed; shared release is pending C.
- PR #5: architecture/conceptual diagrams and B design documents. D/E review remains open; draft models are not approved physical DDL.
- Component test evidence: twelve isolated scenarios passed (see PR #4). Full 00–10 integration is not yet complete.

## 02b release gate — C then B then C/D/E/F

1. C confirms its final 02 source load is complete and agrees not to reset the lab tables during the release.
2. B records current main and release commit, actual source schema/columns/keys/ownership, 28 encounters, 68 dispenses and 48 identity_truth rows; confirms all fixture patient/lab/clinic references exist. Counts alone do not prove content.
3. If those prerequisites or the agreed source contract differ, stop. The latest inspected shared encounter/dispense counts were zero and identity_truth was absent; do not load around missing prerequisites.
4. Coordinate a 5–10 minute affected-write pause in the team's explicitly agreed timezone. Check active transactions; never terminate teammate sessions to obtain a lock.
5. Take a new private pg_dump, record timestamp and checksum, and verify a restore in an isolated database. Also preserve the two target tables' definitions, owners, grants and content. Do not upload credentials or backups to GitHub.
6. Run the exact reviewed file with stop-on-error. The script handles one transaction, 5s lock timeout and 60s statement timeout, paired TRUNCATE without CASCADE, inserts and pre-commit assertions. Never rerun C's 01/02 on the shared database on B's behalf.
7. Independently recheck all 36 messages and 34 deliveries against the fixture, not just counts. Only MSG0010 and MSG0032 lack delivery. Preserve MSG0032/OBS0031 duplicate, OBS0022 empty unit and OBS0025 future date. Check JSON IDs/LOINC/unit/time strings and all references.
8. Hand off to C to rerun RAW 03, D 04/05 and its reporting work, E 06/07 and its reporting work, then F tests/dashboard. Old downstream results are stale until their owners refresh them. Do not perform those shared operations without coordination.

### Scoped recovery

Before commit, any check/error/lock timeout rolls back. After commit, pause affected downstream work, compare any newer legitimate changes and validate targeted restoration in a copy. Restore only B's affected objects when appropriate; do not restore the entire shared database over teammates' new work. A Git correction uses a new B revert commit and preserves history.

## B4 dashboard decision and prepared path

Metabase is a candidate, not a deployed or course-approved service. Four final reporting views are not yet present. B provides environment/connectivity; F owns dashboard contents.

- Recheck sustained memory/CPU, disk, existing proxy and Docker networks.
- Use an independently version-pinned official Metabase image and a separate persistent PostgreSQL application database; do not use embedded H2 for the shared service.
- Set explicit service memory limits and leave headroom for the existing database; test startup/restart before exposing the service. Do not upgrade existing PostgreSQL or CloudBeaver.
- New dashboard role gets CONNECT plus reporting USAGE and SELECT on exactly the four approved views, no source/raw/cleansed tables, no writes or DDL. Do not assume all reporting objects are safe to expose because parameters also live there.
- Confirm actual view owners before deciding how grants survive 08. A rerunnable exact-view grant step after 08 avoids broad default SELECT on every future reporting object. Validate access after owner-run 08 rebuild.
- Use a separate HTTPS hostname and existing proxy only after configuration validation. Database port stays private. Capture old proxy configuration and roll back only the new route/service if needed.
- New persistent credentials/security access require the user's confirmation at the actual access step. Never put credentials in GitHub or channel posts. User completes new-password entry when required.
- A confirms the course permits the dashboard route; F verifies four queries, read-only restrictions and persistence after restart. By Oct 8 21:00 in the agreed team timezone, choose Excel if these checks are not satisfied. No emergency VM upgrade or public database port.

### Excel fallback — ready-to-use procedure

F exports each final reporting view from CloudBeaver after 08 and acceptance tests, including column headers, database name, frozen Git commit, extraction timestamp and as_of_date in the evidence notes. Use UTF-8 CSV and import identifiers as text; inspect date/numeric types. Create one sheet per UC and charts appropriate to that UC. Record that the export is a snapshot; refresh by re-exporting the same verified views. A/B may inspect exported data but should not overwrite F's workbook. No fabricated data can stand in for absent views.

## B6 full integration runbook with F

Prerequisites: merged/reviewed B PRs, all 00–10 scripts present at one frozen commit, confirmed run order, consistent source fixtures and final owner handoffs. An open PR passing component tests does not meet this gate.

1. Administrator provisions a uniquely named empty test database and object-owner role; verify server and database identity externally. Keep it out of normal team connection lists.
2. Record exact Git commit, PostgreSQL version, timezone, role and test-database name. Use all files from the same commit.
3. Execute 00 → 01 → 02 → 02b → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10, adjusting only if the agreed repository runbook defines a different numbered responsibility. Stop at the first error; save the failing file/line and hand it to its owner.
4. Run Appendix C tests: all pass, at least the task-card-required test set; verify 48 source identities; 17 masters; 46/1/1 LINKED/REVIEW/UNMATCHED; 36/34 lab source counts; 28/32/65 facts; UC expected counts 8/11/16/2. These are targets and must be verified against the final frozen contract.
5. Confirm each execution of 03 adds exactly one run log. Preserve earlier run IDs. Re-run the same full sequence in the same isolated database to test rebuild and repeatability, comparing content, grants and required view availability.
6. Capture query + results + database context, test_result failures = 0, version and commit. Verify reporting reader still accesses the four views after 08. Keep all evidence tied to this commit.
7. A/F decide code freeze after owners fix remaining defects. Do not mark B6 complete until both runs pass. Later changes require a new version and affected revalidation.

## Review / communication draft (not sent)

My B setup script has passed isolated repeat-run and restore-copy checks and has been verified in the shared database. I have added the setup evidence, lab-message loader, architecture/conceptual diagrams, and a full logical dictionary/report draft in B branches/PRs. I have not changed C/D/E/F files or rerun their shared scripts. The shared 02b load needs C's final 02 handoff (28 encounters, 68 dispenses, 48 truth rows and parent references). D/E please confirm the marked model/dictionary fields; F and I can run the complete frozen 00–10 pipeline when all scripts are ready. Dashboard deployment remains subject to the course/access/query checks, with Excel export as the fallback.

## Open dependency register

|Dependency|Owner|B action ready|Status|
|---|---|---|---|
|Final source load and lab-column contract|C|Reviewed 02b, scoped release procedure|Waiting|
|CLEANSED/fact/view exact definitions|D/E|47-object dictionary and logical draft|Waiting for review|
|Course dashboard condition|A|Resource inspection and fallback procedure|Unconfirmed|
|Four reporting views and 08 rebuild|D/E|Least-privilege grant/validation design|Not yet testable|
|Complete frozen SQL and tests|All/F|Two-run integration procedure|Waiting|
|Contribution hours and personal practice|Zhihao|Evidence and tutoring notes|User supplies actual hours|

The group guide's dates for D's early checks versus C's later RAW handoff should be clarified by A as draft-code testing versus integrated acceptance; B does not silently change teammates' deadlines.
