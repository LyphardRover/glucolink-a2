# Week 8 local deployment record — Package B

**Owner:** Zhihao Zhang · **Deployment evidence:** 16 September 2026 · **Compiled:** 17 September 2026

## 1. Outcome and purpose

B recovered the existing workshop environment, configured the browser database interface, created an isolated A2 database and supplied reproducible setup files. This gives C/D/E agreed locations for their later source, cleaning and reporting objects, and gives another member a concrete setup to reproduce.

| Item | Recorded local result |
|---|---|
| Runtime | Existing Docker Desktop/course Compose environment |
| Database service | `student-postgres`, PostgreSQL 15.18 |
| Browser interface | `student-cloudbeaver`, CloudBeaver Community at `http://localhost:8978/` |
| Current project database | `glucolink_a2` |
| Project schemas | `src_gp`, `src_lab`, `src_pharm`, `raw`, `cleansed`, `curated`, `reporting`, `audit` |
| Default schema | `public`, additional to the eight project schemas |
| Business tables/views | 0 at the B-only baseline |
| Preserved databases | Course `lab` and earlier prototype `glucolink` |
| Reproduction status | Two successful runs on B's machine; second member still pending |

The platform follows the coordinator's clarification to use the workshop lab environment. Snowflake is unavailable for this task. These results establish B's local framework, not completion of the business pipeline or team-wide access.

## 2. Actual operations, in order

### A. Inspect and recover the existing lab

1. Inspected the existing course configuration, containers and persistent storage before creating A2 objects.
2. Found Docker's Linux engine unavailable: the `dockerDesktopLinuxEngine` pipe was missing. Startup logs pointed to inaccessible temporary communication files under `%LOCALAPPDATA%/Docker/run/dockerInference` and `%LOCALAPPDATA%/docker-secrets-engine/engine.sock`.
3. Stopped Docker Desktop and confirmed its processes had stopped. Renamed the affected temporary runtime directories to preserve them, then restarted Docker. A repeated failure required handling the remaining runtime directory while Docker was stopped.
4. Started the existing PostgreSQL and CloudBeaver containers. PostgreSQL completed its startup recovery, then accepted connections.
5. Used read-only SQL to verify PostgreSQL 15.18 and the existing course tables: `lab.public.inventory` had 4 rows and `lab.public.shops` had 3 rows. CloudBeaver returned HTTP 200.

This recovery procedure did not delete the database storage or replace the course Compose file. The underlying reason those communication files became inaccessible was not established. Temporary runtime-directory preservation is not a database backup. Historical Docker troubleshooting is **not a required setup step for a teammate whose Docker already works**.

Existing storage locations, relative to the member's course lab folder:

| Host folder | Container folder | Purpose |
|---|---|---|
| `Lab_Resources/data/postgres` | `/var/lib/postgresql/data` | PostgreSQL persistent data |
| `Lab_Resources/data/cloudbeaver` | `/opt/cloudbeaver/workspace` | CloudBeaver configuration/workspace |
| `Lab_Resources/workspace` | `/workspace` in the course Python container | Later integration files |

The Python mount was identified; this deployment does not claim a Python business pipeline was run. Port publication was inherited from the course configuration. Internet access, teammate access and firewall protections were not verified by the local connection tests.

### B. Configure CloudBeaver

1. Opened the local CloudBeaver initial configuration page.
2. Set the server label to `GlucoLink A2 Lab` and disabled anonymous access. The user created their own local administrator login; credentials are not included in this repository.
3. Established a course connection to `lab`, using host `postgres` and port `5432` from inside the Compose network.
4. Established the initial A2 connection, then updated it to the revised release target in step D below.

The CloudBeaver website login and PostgreSQL database login serve different purposes. Each member uses their own local credentials.

### C. Create the initial isolated prototype

The first local prototype used database `glucolink` with five project schemas: `raw`, `cleansed`, `curated`, `reporting` and `audit`. It had no business tables. It demonstrated the isolated project structure before the revised team naming and source areas were applied.

This earlier database was retained. The current setup does **not** rename it or require teammates to reproduce that intermediate step. New work uses `glucolink_a2`.

### D. Apply the revised team plan and release the current setup

1. Created **a separate database**, `glucolink_a2`, using [B_create_database.psql](B_release_v0.1/B_create_database.psql). Creation is skipped when the database already exists.
2. Opened a new connection to that database before executing [B_setup.sql](B_release_v0.1/B_setup.sql).
3. The setup checks the target database, PostgreSQL version and relevant privileges, then creates the eight project schemas using `CREATE SCHEMA IF NOT EXISTS` inside a transaction.
4. It checks that the executing role can use and create objects inside each schema. It creates no business tables, new login accounts or teammate access grants.
5. Added the [PowerShell runner](B_release_v0.1/B_run_setup.ps1), [verification queries](B_release_v0.1/B_verify_setup.sql), [baseline capture](B_release_v0.1/B_capture_baseline.sql), setup guide and handoff records.
6. Updated the existing A2 CloudBeaver connection to **A2 GlucoLink v0.1 - PostgreSQL**, targeting `glucolink_a2` at `postgres:5432`.
7. Tested the browser connection successfully and expanded its schema tree to confirm all eight project schemas plus `public`.

The database-creation step is separate because PostgreSQL `CREATE DATABASE` cannot run inside a transaction block. PostgreSQL connections select one database; reconnecting is necessary rather than issuing a `USE DATABASE` command.

| Schema | Purpose / implementation handoff |
|---|---|
| `src_gp`, `src_lab`, `src_pharm` | Separate simulated source areas; C supplies source tables/data |
| `raw` | Integrated raw input area; C |
| `cleansed` | Cleaned records and identity matching; D |
| `curated` | Dimensions and facts for analysis; E |
| `reporting` | Report views/results, including UC3; E, verified by F |
| `audit` | Reserved for agreed processing records; logging is not automatically enabled |

`src_lab` is a schema name; `PATH` remains the pathology source label in the proposed data contract.

### E. Verify the setup and preserve evidence

| Check actually performed | Result | Repository evidence |
|---|---|---|
| First complete setup run | PASS | [first_run.txt](B_release_v0.1/evidence/first_run.txt) |
| Repeated setup run | PASS | [second_run.txt](B_release_v0.1/evidence/second_run.txt) |
| Compare structures after first/repeat runs | Same metadata, excluding capture times | [B_local_validation.json](B_release_v0.1/evidence/B_local_validation.json) |
| Execute setup against wrong database `lab` | Rejected; lab metadata unchanged | [wrong_database_guard.txt](B_release_v0.1/evidence/wrong_database_guard.txt) |
| Check earlier `glucolink` | Metadata unchanged | [B_local_validation.json](B_release_v0.1/evidence/B_local_validation.json) |
| Check existing course table counts | inventory 4; shops 3 | [B_local_validation.json](B_release_v0.1/evidence/B_local_validation.json) |
| Capture A2 structure | Eight project schemas; no business tables/views | [glucolink_a2_baseline.json](B_release_v0.1/evidence/glucolink_a2_baseline.json) |
| CloudBeaver connection and schema tree | Connection established; expected tree shown | [B_browser_connection_check.md](B_release_v0.1/evidence/B_browser_connection_check.md) |

These are the recorded September 16 local results. Metadata and row-count checks do not prove every historical cell value is unchanged. The baseline is neither a complete data backup nor continuous monitoring.

### F. Prepare the supporting design and handoff

Prepared a three-page architecture/conceptual/logical design in [PDF](B_release_v0.1/B_design_v0.1.pdf), editable drawio and PNG formats, plus a logical dictionary and peer/integration checklists. The proposed five-table business model awaits D/E review and has not been applied as business DDL. Design preparation is separate from the verified creation of the database and schemas.

## 3. How a teammate reproduces the current result

Use the full [setup guide](B_release_v0.1/B_setup_readme.md). The normal route is:

1. Start the existing course Docker environment. In the course Compose folder, inspect with `docker compose ps`; if needed, start the existing services with `docker compose up -d postgres cloudbeaver`.
2. Open PowerShell in this repository's `B_design/B_release_v0.1` folder.
3. Run `./B_run_setup.ps1`. The defaults are container `student-postgres` and the member's existing course role `student`. If local names differ, supply `-ContainerName` and `-DatabaseRole`. If local script execution is blocked, use the guide's individual commands without changing machine policy.
4. Confirm the database check and all eight schema checks report `PASS`. Zero business tables/views is the expected **fresh B-only** state; later C/D/E objects must not be deleted merely to reproduce that count.
5. In the local CloudBeaver, connect to `postgres:5432`, database `glucolink_a2`, using that member's own database credentials. Test and inspect Schemas.
6. Repeat setup, retain actual outputs and complete [B_peer_check.md](B_release_v0.1/B_peer_check.md). Record failures as observed; do not mark the peer test passed in advance.

The runner creates the database on a maintenance connection, reconnects for schema setup, then runs environment and verification queries. SQL is streamed into the container, so this repository folder need not be mounted inside it.

## 4. What remains to complete

- Another member independently runs this release on their own local machine and records evidence.
- C/D/E reconcile their source fields, tables and processing interfaces with the proposed model.
- F confirms the integration machine and tests the assembled C/D/E pipeline after B setup.
- The group plans to rent a cloud server; no server purchase, cloud deployment or shared remote connection is established by this package.
- Automatic change monitoring and processing audit records still need an implemented mechanism and verified access.

GitHub shares scripts, documentation and revision history. Uploading this package does not copy a running database or make one member's `localhost` accessible to everyone. A later cloud deployment is a separate operation.

## 5. 中文：你本周到底做了什么

整个过程是：**检查旧环境 → 修复 Docker 启动 → 启动 PostgreSQL 和 CloudBeaver → 配置网页连接 → 建初版项目库 → 根据新版规划建立 `glucolink_a2` 和八个 schema → 重复运行与错误连接测试 → 保存证据、设计图和队友复现说明。**

- **Docker** 负责运行软件；**PostgreSQL** 真正管理数据库；**CloudBeaver** 是你用浏览器操作数据库的界面。
- **database 像文件柜，schema 像抽屉，table 像登记表，row 是一条记录。** 你现在建好了项目文件柜和八个抽屉，登记表与患者记录还要由后续业务脚本建立。
- 最初的 `glucolink` 是旧文件柜。新版另建 `glucolink_a2`，旧库和课堂练习库 `lab` 都保留了；不是把旧库改名。
- **脚本**把搭建动作写下来，让同学能按相同步骤建立自己的环境；**证据**记录你本机真的跑过、结果是什么。再跑一次没有重复建对象，是已经验证过的结果。
- 错误数据库保护相当于先检查文件柜名称：误连 `lab` 就停止，避免把项目抽屉建进课堂练习库。
- 图里的患者主表、维度表和事实表是待评审设计。图画好了，不代表表已创建，也不代表业务数据已处理。
- 本次 GitHub 交付让组员拿到相同版本的文件，便于复现、检查差异和后续整合。它本身不会自动搭建云服务器。

**实际用处：** C/D/E 有了统一的存放位置和环境基础；队友可以复现；F 有明确的集成起点；汇报时能用运行结果支撑“环境搭建成功”，同时准确说明业务处理仍待整合。

### 简短英文汇报

I prepared a reproducible local PostgreSQL environment using the workshop lab. I created the glucolink_a2 database and eight project schemas, configured the CloudBeaver connection, and checked the first run, repeated run and wrong-database protection. I preserved the existing course database and recorded the results. The business model is proposed for review; business tables and the integrated pipeline are still pending. The next acceptance step is another member reproducing the setup independently.

### 理解检查 / likely presentation questions

1. PostgreSQL、CloudBeaver 和 GitHub 各自负责什么？为什么上传 GitHub 不等于共享了实时数据库？
2. 为什么需要 `glucolink_a2`，还要在里面建八个 schema？它们与 table 有什么区别？
3. 本机重复运行成功，和另一位组员复现成功，分别证明什么？目前哪一项还没有证据？

Learning status: explanations supplied; independent explanation and operation remain to be demonstrated by the student.
