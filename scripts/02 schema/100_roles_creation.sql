-- version 0.11.13

-- Create roles and grant permissions

-- Step 1: Create the "login" role with login capability and NOINHERIT
CREATE ROLE "login" WITH LOGIN PASSWORD 'FOTS-Egypt' NOINHERIT;

-- Create other roles without login capability and with NOINHERIT
CREATE ROLE "kppo_admin_user" NOLOGIN NOINHERIT;
CREATE ROLE "logistics_user" NOLOGIN NOINHERIT;
CREATE ROLE "report_viewer_user" NOLOGIN NOINHERIT;

-- Step 2: Set Default Privileges
-- For Tables and Views
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO "report_viewer_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "logistics_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL PRIVILEGES ON TABLES TO "kppo_admin_user";

-- For Sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT ON SEQUENCES TO "kppo_admin_user", "logistics_user", "report_viewer_user";

-- For Functions (Stored Procedures)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT EXECUTE ON FUNCTIONS TO "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Step 3: Grant SELECT on the users table to validate credentials
GRANT SELECT ON users TO "login";

-- Step 5: Grant database connection privilege
GRANT CONNECT ON DATABASE "ExtLogDB" TO "login", "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Step 6: Grant usage on schema
GRANT USAGE ON SCHEMA public TO "login", "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Step 7: Grant the ability to switch roles
GRANT "kppo_admin_user" TO "login";
GRANT "logistics_user" TO "login";
GRANT "report_viewer_user" TO "login";

-- Step 8: Grant specific privileges to each role
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "logistics_user";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "kppo_admin_user";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "report_viewer_user";

-- Step 9: Grant usage on sequences to roles
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO "kppo_admin_user", "logistics_user", "report_viewer_user";
