# Package B — environment evidence and deployment readiness

Owner: Zhihao Zhang. Inspected 2026-10-06 UTC. This file records B checks only; no teammate SQL, source data or application objects were edited. These are point-in-time observations.

## Database capability checks

Database: glucolink_a2. PostgreSQL: 15.19 (Debian 15.19-1.pgdg12+2), x86_64, GCC 12.2.0. `SHOW timezone;` returned `Etc/UTC`. Business-date rules still explicitly use Australia/Sydney.

The capability test used an administrator connection with `SET ROLE a2_team_editor`; PostgreSQL reported `session_user=glucolink_admin` and `current_user=a2_team_editor`. It tests the effective database role, not a newly claimed CloudBeaver login. Individual member-role flags inspected earlier were also non-superuser/no-CREATEDB; web account identity and database role identity are distinct. A final CloudBeaver evidence screenshot should include current_user/session_user for the actual selected connection.

```sql
SET ROLE a2_team_editor;
SELECT current_database(), session_user, current_user;
CREATE DATABASE glucolink_a2_test;
-- ERROR: permission denied to create database
```

In a separate session, the extension check was enclosed in a transaction and aborted on error; no extension was installed:

```sql
BEGIN;
SET LOCAL ROLE a2_team_editor;
CREATE EXTENSION postgres_fdw;
-- ERROR: permission denied to create extension "postgres_fdw"
-- HINT: Must be superuser to create this extension.
ROLLBACK;
```

`pg_available_extensions` lists postgres_fdw, but installed_version is NULL. The administrator can provision isolated tests; the ordinary effective team role cannot be assumed to do so.

## Backup evidence

A new private custom-format backup was created at 2026-10-06 14:07:18 UTC:

- Filename: `B_snapshot_20261006T140718Z.dump`
- Private directory: `/opt/glucolink-a2/b-v3-20261006/backups/`
- Size: 49,523 bytes
- SHA-256: `df75a1453a83fed64e5360c677173218b8750b48e3046dd082ae0bd5796378fb`
- Archive listing: succeeded, 142 listing lines.
- **This new snapshot has not been restoration-tested.** The earlier before_00_20261006T123635Z.dump has its own restoration evidence; that evidence must not be transferred to this snapshot.

No dump or credentials are committed to GitHub. `glucolink-backup.timer` is active in the timer list: last trigger 2026-10-05 17:01:48 UTC; next trigger 2026-10-06 17:02:34 UTC at inspection. A timer entry alone is not proof that every scheduled backup succeeds; inspect service status and a resulting archive before reporting the next run.

## B4 resource observation

- VM RAM: 3,908 MiB total, 2,812 MiB available; no swap.
- Root disk: 29 GB total, 20 GB available.
- Existing containers: edge approximately 24 MiB; CloudBeaver approximately 359 MiB; PostgreSQL approximately 42 MiB in this single sample.
- Existing HTTPS route: glucolink-a2.34-40-230-129.sslip.io → cloudbeaver:8978.

These samples justify preparing a separately limited Metabase candidate, but do not prove performance under concurrent team workload. Existing services are not upgraded. The planned new service needs its own persistent PostgreSQL application database, fixed image digest, finite memory allowance, private database networking and an independently validated HTTPS route. B supplies infrastructure; F supplies dashboard content.

Official reference checked: [Metabase Docker installation and production application database](https://www.metabase.com/docs/latest/installation-and-operation/running-metabase-on-docker). Follow production persistence guidance rather than relying on a disposable embedded H2 database. No new dashboard access or credentials are claimed as configured by this evidence file.

## Remaining verification boundaries

1. C final 02 handoff and prerequisites before B 02b live release.
2. D/E review of the 27 contract objects and final SQL comparison.
3. Metabase credentials/access and subsequent four-view/read-only/restart tests with F, or F-3 Excel fallback.
4. F/B whole-pipeline two-run integration at one frozen commit.
5. User sends Teams evidence and provides actual contribution hours; no human acknowledgement or hours are invented.
