-- Read-only. Can run on any connected PostgreSQL database.
SELECT current_database() AS database_name, current_user AS connected_role,
       current_setting('server_version') AS server_version,
       current_setting('TimeZone') AS session_timezone;
SELECT datname AS database_name
FROM pg_database WHERE NOT datistemplate ORDER BY datname;
SELECT n.nspname AS schema_name, pg_get_userbyid(n.nspowner) AS owner
FROM pg_namespace n
WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
ORDER BY n.nspname;
