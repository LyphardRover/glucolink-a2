-- Read-only checks. A row labelled PASS proves only its stated setup condition.
SELECT 'target_database' AS check_name,
       CASE WHEN current_database() = 'glucolink_a2' THEN 'PASS' ELSE 'FAIL' END AS status,
       current_database() AS actual;
WITH expected(schema_name) AS (
    VALUES ('src_gp'),('src_lab'),('src_pharm'),('raw'),
           ('cleansed'),('curated'),('reporting'),('audit')
)
SELECT e.schema_name,
       CASE WHEN n.oid IS NOT NULL
                 AND has_schema_privilege(current_user, n.oid, 'USAGE')
                 AND has_schema_privilege(current_user, n.oid, 'CREATE')
            THEN 'PASS' ELSE 'FAIL' END AS status,
       pg_get_userbyid(n.nspowner) AS owner
FROM expected e LEFT JOIN pg_namespace n ON n.nspname = e.schema_name
ORDER BY e.schema_name;
-- Zero immediately after a fresh B-only setup; later C/D/E tables are expected.
SELECT count(*) AS user_tables_and_views
FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema','pg_catalog');
-- Harmless deterministic check, independent of machine-specific object OIDs.
SELECT 'B_RELEASE_0.1' AS release_id, current_database() AS database_name,
       string_agg(nspname, ',' ORDER BY nspname) AS project_schemas
FROM pg_namespace WHERE nspname IN
('src_gp','src_lab','src_pharm','raw','cleansed','curated','reporting','audit');
