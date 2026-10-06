# B4 — prepared independent Metabase candidate

Owner: Zhihao Zhang. Prepared 2026-10-06 UTC. **Configuration prepared and validated; service not started.** No reporting account, public route or dashboard credential has been created by this preparation. This is B infrastructure, not F's dashboard content.

## Current readiness

Private candidate directory on the VM: `/opt/glucolink-a2/b-dashboard-candidate/`. It contains `compose.yaml`, a private empty `secrets/` directory and `Caddyfile.addition.review-only`. `docker compose ... config --quiet` returned exit 0. The existing proxy is unchanged. The official Metabase image was downloaded and its immutable digest recorded below. The PostgreSQL image is the already installed 15.19 image; existing containers are not upgraded.

The new Metabase service is limited to 1536 MiB and one CPU; its separate application database is limited to 256 MiB and half a CPU. These are limits, not reservations or successful load-test evidence. Initial read-only sampling showed 2812 MiB available out of 3908 MiB, no swap, and 20 GB free disk. Stop the candidate if it causes OOM events, sustained low memory or materially slower existing queries. Do not resize the VM without a separate decision.

## Prepared Compose configuration

```yaml
name: glucolink-b-dashboard
services:
  appdb:
    image: postgres@sha256:5d1d70e254e3c5d7d76847a9deebb18478cd518df37abf6b278d4bdb1fe5d96c
    pull_policy: never
    restart: unless-stopped
    mem_limit: 256m
    cpus: 0.5
    environment:
      POSTGRES_DB: metabaseappdb
      POSTGRES_USER: metabase_app
      POSTGRES_PASSWORD_FILE: /run/secrets/appdb_password
    command: [postgres, -c, shared_buffers=32MB, -c, max_connections=25]
    volumes:
      - appdata:/var/lib/postgresql/data
    secrets: [appdb_password]
    networks: [appnet]
    healthcheck:
      test: [CMD-SHELL, "pg_isready -U metabase_app -d metabaseappdb"]
      interval: 10s
      timeout: 5s
      retries: 12
  metabase:
    image: metabase/metabase@sha256:4655288d1368cd13eba4644f8b0776b7ab9f43f863de7f569c76da5330246f82
    restart: unless-stopped
    mem_limit: 1536m
    cpus: 1.0
    ports: ["127.0.0.1:3000:3000"]
    environment:
      MB_DB_TYPE: postgres
      MB_DB_HOST: appdb
      MB_DB_PORT: 5432
      MB_DB_DBNAME: metabaseappdb
      MB_DB_USER: metabase_app
      MB_DB_PASS_FILE: /run/secrets/appdb_password
      JAVA_TIMEZONE: Australia/Sydney
      JAVA_OPTS: -Xms256m -Xmx1024m
      MB_ANON_TRACKING_ENABLED: "false"
    secrets: [appdb_password]
    depends_on:
      appdb:
        condition: service_healthy
    networks:
      appnet: {}
      project:
        aliases: [b-metabase]
    healthcheck:
      test: [CMD-SHELL, "curl --fail --silent http://localhost:3000/api/health || exit 1"]
      interval: 20s
      timeout: 5s
      start_period: 180s
      retries: 12
volumes:
  appdata: {}
secrets:
  appdb_password:
    file: ./secrets/appdb_password.txt
networks:
  appnet:
    internal: true
  project:
    external: true
    name: glucolink-a2_default
```

The application database stores Metabase users, questions and dashboards; it is separate from the GlucoLink business database. The named volume survives service restarts. Do not use `down -v` as a routine rollback. The image digest is the deployment pin; `latest` is not used by the prepared service.

## Access and credential gate

The user must confirm the new reporting access and the proposed independent hostname before activation. Under the browser-operation credential rule, the user must enter and submit new passwords personally; no password belongs in this document, GitHub or Teams. Enter the application-database secret only in a protected terminal prompt, then complete the Metabase admin setup through the private preview. The public route must remain absent until admin setup is complete.

Proposed route for later validation (currently NOT applied):

```caddy
dashboard-glucolink-a2.34-40-230-129.sslip.io {
    reverse_proxy b-metabase:3000
}
```

Before applying, save the current Caddy configuration, check that the candidate network alias resolves, validate the combined Caddy configuration and reload it gracefully. Existing CloudBeaver route must continue to answer. Keep port 3000 loopback-only and PostgreSQL off public ports. If this step fails, restore only the prior proxy configuration and stop only the new service.

## Reporting role and rebuild behaviour

Create a dedicated login only after authorization. It must not inherit the team editor or administrator role. Check effective privileges including PUBLIC grants before describing it as read-only. Grant CONNECT to the project database, USAGE on reporting, and SELECT on exactly:

- reporting.vw_uc1_care_gaps
- reporting.vw_uc2_pdc
- reporting.vw_uc3_hba1c_trend
- reporting.vw_uc4_care_path_breaks

No direct grants to source, RAW, CLEANSED, CURATED or rule_parameter. Inspect each view's owner/options: an invoker-security view may require underlying privileges and must be coordinated with its owner rather than silently widening access. Do not revoke PUBLIC privileges globally or change team roles, because that would affect other members. Session-local TEMP privileges, if inherited from PUBLIC, must be disclosed separately from permanent-object write access.

After owner-run 08 recreates views, B runs an idempotent, exact-view GRANT step outside the teammates' files, then tests all four reads again as the actual dashboard login. This avoids broad default SELECT on every future reporting table. Missing views are a stop condition, not grounds to create dummy views.

## Acceptance sequence with F

1. User supplies protected application/admin credentials; start only this Compose project.
2. Check both service health, memory/CPU and existing CloudBeaver/database response.
3. Complete admin initialization over a private preview before HTTPS exposure.
4. Create the explicitly authorized read-only reporting login, verify effective access and save it only in Metabase.
5. F queries all four final views; check permanent-table writes, DDL and private-schema reads are denied using non-destructive transactions/probes.
6. Restart the new services and verify users/configuration persist. Existing services remain healthy.
7. After the owner reruns 08, regrant exactly those views and repeat actual-login reads. Record screenshots with query, results and database/commit.
8. Back up the Metabase application database as well as the project database before calling persistence/recovery complete. The existing project backup timer alone does not cover this new app volume.

F-3 decision is unchanged: if by Thursday evening the tutor has not refused an external tool and B has a working URL plus read-only login, use Metabase; otherwise use Excel charts from verified exported views. A new service merely starting is insufficient. Final resource, access and query tests are still pending.

Official source checked: [Metabase Docker deployment, production database and Docker secrets](https://www.metabase.com/docs/latest/installation-and-operation/running-metabase-on-docker). No service availability is claimed by this document.
