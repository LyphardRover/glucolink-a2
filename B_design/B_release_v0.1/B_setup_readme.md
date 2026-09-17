# GlucoLink B setup release 0.1

Owner: Zhihao Zhang. Date: 16 September 2026. Target: the existing course PostgreSQL 15 lab, database **glucolink_a2**. This release supplies B's runnable framework and checkpoint design. Business tables and data belong to C/D/E and are not built by this release.

## Status and handoff

- B's local first run, repeat run and wrong-database guard passed; see `evidence/B_local_validation.json` and actual output logs.
- Eight project schemas exist locally; `public` is an additional default schema. There are zero business tables/views at the B-only baseline.
- Diagrams and dictionary describe a **proposed** business model for D/E review. They do not assert that those tables or constraints exist.
- Another member's local reproduction, D/E review, and F's integrated run remain pending. Complete `B_peer_check.md` with actual evidence.
- Earlier `glucolink` and course `lab` databases are retained. New release scripts and new A2 connection use **glucolink_a2** consistently. Do not run old B_setup scripts for this release.

## 1 Prerequisites and folder location

Use the existing tutorial installation. Docker Desktop must be running, with the course PostgreSQL and CloudBeaver services. No reinstallation, reset, volume deletion or compose overwrite is part of this release.

Use your existing course `Lab_Resources` folder for Compose commands. In this repository the release is `B_design/B_release_v0.1`; open that folder for the setup commands below. These paths refer to your own checkout and lab installation.

From your own lab folder inspect services with:

```powershell
docker compose ps
```

If those existing services are stopped, start just the needed services from that folder:

```powershell
docker compose up -d postgres cloudbeaver
```

The default script assumes container `student-postgres` and the existing local course database role `student`. If your names differ, use your actual values through `-ContainerName` and `-DatabaseRole`. Credentials remain local and are never part of the release. A credential prompt/failure requires your own saved course credentials; do not request another person's password.

Unzip/copy the release into a normal writable folder. Use the full folder contents, including scripts, not just screenshots. SQL is streamed into the database container, so the release itself does not need to be in a mounted container folder.

## 2 Recommended Windows run

Open PowerShell **in this release folder** and run:

```powershell
.\B_run_setup.ps1
```

If the existing machine policy prevents running a local script, use the explicit commands below instead of changing machine policy. Run each command separately, checking the exit code/output before the next:

```powershell
Get-Content -LiteralPath '.\B_create_database.psql' -Raw | docker exec -i student-postgres psql -X -U student -d postgres -v ON_ERROR_STOP=1
```

This first step creates the database only if absent. It runs outside a transaction. The next command opens a **new connection to glucolink_a2**:

```powershell
Get-Content -LiteralPath '.\B_setup.sql' -Raw | docker exec -i student-postgres psql -X -U student -d glucolink_a2 -v ON_ERROR_STOP=1
```

```powershell
Get-Content -LiteralPath '.\B_verify_setup.sql' -Raw | docker exec -i student-postgres psql -X -U student -d glucolink_a2 -v ON_ERROR_STOP=1 -P pager=off
```

Success means the target database check and all eight schema rows say PASS. On a fresh B-only setup, user_tables_and_views is 0. Re-run the same setup and verification: existing-schema notices are expected; no objects should be removed or duplicated. Future C/D/E objects should survive a B setup rerun.

The setup creates namespaces as the executing local role. It does not change the existing network configuration, create login accounts, or grant access to teammates. If an existing namespace is not usable by that role, setup stops and reports it for inspection.

## 3 CloudBeaver connection and alternative SQL route

Open `http://localhost:8978/` and sign in with **your own local CloudBeaver account**. Its web login is separate from the PostgreSQL database login.

| Client location | Host | Port | Database |
|---|---|---|---|
| CloudBeaver in the supplied Compose network | postgres | 5432 | glucolink_a2 |
| Python in the supplied Compose network | postgres | 5432 | glucolink_a2 |
| A database client running directly on the laptop | localhost | 5432 in B's current lab; check your compose mapping | glucolink_a2 |

For a new/revised A2 connection, use label **A2 GlucoLink v0.1 - PostgreSQL** and the database above; use your own existing database credentials. Test connection, then expand Schemas. Expect `src_gp`, `src_lab`, `src_pharm`, `raw`, `cleansed`, `curated`, `reporting`, `audit`, plus default `public`.

If using CloudBeaver instead of the recommended script: connect to maintenance database `postgres`, check whether `glucolink_a2` already exists, and run `B_create_database.sql` only if absent with autocommit on. Then establish/select the A2 connection and execute the complete `B_setup.sql` script, followed by `B_verify_setup.sql`. A connection works in one database; PostgreSQL has no `USE DATABASE` command. Never paste `.psql` backslash commands into this SQL editor. After an SQL error inside the setup transaction, run `ROLLBACK;` before retrying with the correct connection.

## 4 Object locations and responsibilities

| Namespace | Framework owner | Business implementation owner | Planned content |
|---|---|---|---|
| src_gp | B | C | GP patients and encounters |
| src_lab | B | C | Pathology patients and raw lab JSON records |
| src_pharm | B | C | Pharmacy patients and dispenses |
| raw | B | C | Six input representations plus provenance |
| cleansed | B | D | Patient master, source links, clean lab results |
| curated | B | E | Patient dimension and lab-result fact |
| reporting | B | E; F verifies | UC3 view/result |
| audit | B | Logging design and writers to agree | Processing history, not automatically active |

`src_lab` is a schema name. `PATH` remains the pathology source label in data; do not silently replace it with `LAB`. Source schemas simulate distinct source systems inside one PostgreSQL instance, not three deployed external services. C's exact table names and fields must be reconciled against `B_logical_dictionary_v0.1.md` before release.

## 5 Files and container paths for later C to F integration

Each member's localhost is a **different computer**. Share versioned files and instructions, not credentials or a presumed live database. F chooses one working local integration machine; B supports its environment. Record the actual choice in `B_peer_check.md`.

The existing Python container on B mounts `Lab_Resources/workspace` to `/workspace`. A suggested later integrated folder is `Lab_Resources/workspace/glucolink_a2`, with `data`, `sql`, `python`, `docs`, `tests`. The equivalent container path is `/workspace/glucolink_a2`. This is a suggested F integration layout, not a claim that C/D/E files have arrived there. Each member records their actual host path.

Numbered release order: B setup -> C table definitions and sample load -> D cleaning and identity -> E dimensions, facts and UC3 view -> F read-only validation and demo. C/D/E supply their exact commands, required libraries, fixture versions and rerun policies. B's framework alone cannot run these missing steps. `B_release_checklist.md` records what is present and pending.

Do not merge independently generated patient surrogate numbers from different laptops. Rebuild downstream objects from the same released upstream files and inspect source-system/local-ID evidence.

## 6 Evidence and common failures

| Symptom | Action |
|---|---|
| Docker service/container unavailable | Check Docker Desktop and `docker compose ps` from the existing lab folder |
| Database does not exist | Run the separate create step against postgres, then reconnect |
| Wrong database exception | Select glucolink_a2; ROLLBACK first if the interactive session is in a failed transaction |
| Permission denied creating database/schema | Record current role and error; use your authorised course role or agree a documented fallback with B. Do not silently use lab/public |
| Schema already exists notice | Expected during rerun; inspect validation results rather than dropping it |
| CLI works, CloudBeaver does not | Check host postgres inside Compose, target database and your own database credentials |
| Fields/types differ from a teammate script | Record discrepancy and update one released contract with its owner; do not silently rename their objects |

The baseline can be recaptured read-only with `B_capture_baseline.sql`; JSON output is structure metadata, not a full backup or a record of every data edit. `audit` does not generate logs merely because its schema exists. No automatic monitoring is enabled.

## 7 References

Team authority: 16 September revised Team Action Guide section 7 and Two Day Work Plan section 3. Keep their source DOCX files outside the runnable release.

- [PostgreSQL 15 CREATE DATABASE](https://www.postgresql.org/docs/15/sql-createdatabase.html): separate creation outside a transaction.
- [PostgreSQL 15 CREATE SCHEMA](https://www.postgresql.org/docs/15/sql-createschema.html): namespaces and existing-schema behavior.
- [PostgreSQL 15 psql](https://www.postgresql.org/docs/15/app-psql.html): client commands and stop-on-error execution.

Use the installed course version; B observed 15.18. This release does not update the database software.
