-- version 0.9

-- create roles and grant pemissions



-- Create the "login" role with login capability and NOINHERIT
CREATE ROLE "login" WITH LOGIN PASSWORD 'FOTS-Egypt' NOINHERIT;

-- Create other roles without login capability and with NOINHERIT
CREATE ROLE "kppo_admin_user" NOLOGIN NOINHERIT;
CREATE ROLE "logistics_user" NOLOGIN NOINHERIT;
CREATE ROLE "report_viewer_user" NOLOGIN NOINHERIT;


-- Grant SELECT on the users table to validate credentials
GRANT SELECT ON users TO "login";

-- Grant EXECUTE on necessary functions to the "login" role
GRANT EXECUTE ON FUNCTION login_wrapper(p_username VARCHAR, p_password VARCHAR, p_duration INTERVAL) TO "login";
GRANT EXECUTE ON FUNCTION create_session(user_id INT, role_id INT, duration INTERVAL) TO "login";
GRANT EXECUTE ON FUNCTION log_user_activity(user_id INT, login_time TIMESTAMPTZ, logout_time TIMESTAMPTZ, activity TEXT) TO "login";
GRANT EXECUTE ON FUNCTION log_failed_login_attempt(username VARCHAR, reason TEXT) TO "login";
GRANT EXECUTE ON FUNCTION set_user_role(p_db_role_name VARCHAR) TO "login";

-- Grant database connection privilege
GRANT CONNECT ON DATABASE "Beta_004" TO "login", "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO "login", "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Grant the ability to switch roles
GRANT "kppo_admin_user" TO "login";
GRANT "logistics_user" TO "login";
GRANT "report_viewer_user" TO "login";

-- Grant specific privileges to each role
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "logistics_user";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "kppo_admin_user";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "report_viewer_user";

-- Grant usage on sequences to roles
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO kppo_admin_user, logistics_user, report_viewer_user;

-- Grant select on sequences to roles (needed for some operations)
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO kppo_admin_user, logistics_user, report_viewer_user;

-- Specifically for the audit_trail table's sequence
GRANT USAGE, SELECT ON SEQUENCE audit_trail_audit_id_seq TO kppo_admin_user, logistics_user, report_viewer_user;

-- For MRL_line_items table's sequence (if it exists)
GRANT USAGE, SELECT ON SEQUENCE mrl_line_items_order_line_item_id_seq TO kppo_admin_user, logistics_user;

-- For fulfillment_items table's sequence (if it exists)
GRANT USAGE, SELECT ON SEQUENCE fulfillment_items_fulfillment_item_id_seq TO kppo_admin_user, logistics_user;




