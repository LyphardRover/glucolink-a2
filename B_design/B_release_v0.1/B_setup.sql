-- GlucoLink B release 0.1 | Framework only; C/D/E own business-table DDL.
-- Prerequisite: create glucolink_a2 separately, then reconnect to it.
-- Execute the whole script. After an error in an interactive client, ROLLBACK.
BEGIN;

-- Stop before any changes if this client is connected to the wrong database.
DO $$
BEGIN
    IF current_database() <> 'glucolink_a2' THEN
        RAISE EXCEPTION 'Wrong database: connect to glucolink_a2 before B_setup.sql';
    END IF;
    IF current_setting('server_version_num')::int < 150000 THEN
        RAISE EXCEPTION 'This release requires PostgreSQL 15 or newer';
    END IF;
    IF NOT has_database_privilege(current_user, current_database(), 'CREATE') THEN
        RAISE EXCEPTION 'Current role needs CREATE privilege on glucolink_a2';
    END IF;
END
$$;

-- Three simulated source areas; src_lab is the namespace, PATH the source label.
CREATE SCHEMA IF NOT EXISTS src_gp;
CREATE SCHEMA IF NOT EXISTS src_lab;
CREATE SCHEMA IF NOT EXISTS src_pharm;

-- Integrated warehouse stages; each name is deliberately lowercase/unquoted.
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS cleansed;
CREATE SCHEMA IF NOT EXISTS curated;
CREATE SCHEMA IF NOT EXISTS reporting;
CREATE SCHEMA IF NOT EXISTS audit;

-- Detect pre-existing namespaces that the setup role cannot use/create within.
-- IF NOT EXISTS alone would otherwise conceal an unusable existing schema.
DO $$
DECLARE
    n text;
BEGIN
    FOREACH n IN ARRAY ARRAY['src_gp','src_lab','src_pharm','raw',
                             'cleansed','curated','reporting','audit']
    LOOP
        IF NOT has_schema_privilege(current_user, n, 'USAGE')
           OR NOT has_schema_privilege(current_user, n, 'CREATE') THEN
            RAISE EXCEPTION 'Role cannot use/create in schema %; inspect its owner and grants', n;
        END IF;
    END LOOP;
END
$$;
COMMIT;
-- No tables, data, login roles, network rules or automated logging are created.
-- Re-running adds only missing schemas; it never drops or replaces objects.
