-- version 0.7.9

-- create roles and grant pemissions



-- Create the "login" role with login capability and NOINHERIT
CREATE ROLE "login" WITH LOGIN PASSWORD 'FOTS-Egypt' NOINHERIT;

-- Grant SELECT on the users table to validate credentials
GRANT SELECT ON users TO "login";

-- Grant EXECUTE on necessary functions to the "login" role
GRANT EXECUTE ON FUNCTION login_wrapper(p_username VARCHAR, p_password VARCHAR, p_duration INTERVAL) TO "login";
GRANT EXECUTE ON FUNCTION create_session(user_id INT, role_id INT, duration INTERVAL) TO "login";
GRANT EXECUTE ON FUNCTION log_user_activity(user_id INT, login_time TIMESTAMPTZ, logout_time TIMESTAMPTZ, activity TEXT) TO "login";
GRANT EXECUTE ON FUNCTION log_failed_login_attempt(username TEXT, reason TEXT) TO "login";


-- Create other roles without login capability and with NOINHERIT
CREATE ROLE "kppo_admin_user" NOLOGIN NOINHERIT;
CREATE ROLE "logistics_user" NOLOGIN NOINHERIT;
CREATE ROLE "report_viewer_user" NOLOGIN NOINHERIT;

-- Grant database connection privilege
GRANT CONNECT ON DATABASE "Beta_003" TO "login", "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO "login", "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Grant specific privileges to each role
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "logistics_user";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "kppo_admin_user";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "report_viewer_user";

