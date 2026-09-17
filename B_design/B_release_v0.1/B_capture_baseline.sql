-- Read-only structure snapshot. Not a data backup or real-time monitoring.
SELECT json_build_object(
    'captured_at', clock_timestamp(),
    'release_id', 'B_RELEASE_0.1',
    'database', current_database(),
    'server_version', current_setting('server_version'),
    'session_timezone', current_setting('TimeZone'),
    'schemas', (SELECT json_agg(s ORDER BY s.name) FROM (
        SELECT nspname AS name, pg_get_userbyid(nspowner) AS owner, nspacl::text AS acl
        FROM pg_namespace WHERE nspname NOT LIKE 'pg_%' AND nspname <> 'information_schema'
    ) s),
    'relations', COALESCE((SELECT json_agg(r ORDER BY r.schema_name, r.name) FROM (
        SELECT n.nspname AS schema_name, c.relname AS name, c.relkind AS kind
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
          AND c.relkind IN ('r','p','v','m','S','f')
    ) r), '[]'::json),
    'columns', COALESCE((SELECT json_agg(x ORDER BY x.table_schema,x.table_name,x.ordinal_position)
        FROM (SELECT table_schema,table_name,column_name,ordinal_position,data_type,is_nullable,column_default
              FROM information_schema.columns WHERE table_schema NOT IN ('pg_catalog','information_schema')) x), '[]'::json),
    'constraints', COALESCE((SELECT json_agg(x ORDER BY x.schema_name,x.name) FROM (
        SELECT n.nspname AS schema_name, c.conname AS name,
               pg_get_constraintdef(c.oid) AS definition
        FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
        WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
    ) x), '[]'::json)
);
