-- Alternative for a SQL client such as CloudBeaver. Not part of B_setup.sql.
-- Connect to postgres with a role allowed to CREATE DATABASE; enable autocommit.
-- First run: SELECT datname FROM pg_database WHERE datname = 'glucolink_a2';
-- If the database already exists, skip CREATE and reconnect to it.
-- Execute the following statement on its own, outside BEGIN/COMMIT.
CREATE DATABASE glucolink_a2 TEMPLATE template0;
-- Now connect to glucolink_a2 before running B_setup.sql.
