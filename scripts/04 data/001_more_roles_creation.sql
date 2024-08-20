-- version 0.9.10

-- Create roles and grant permissions


-- Step 4: Grant EXECUTE on necessary functions to the "login" role
GRANT EXECUTE ON FUNCTION login_wrapper(p_username VARCHAR, p_password VARCHAR, p_duration INTERVAL) TO "login";
GRANT EXECUTE ON FUNCTION create_session(user_id INT, role_id INT, duration INTERVAL) TO "login";
GRANT EXECUTE ON FUNCTION log_user_activity(user_id INT, login_time TIMESTAMPTZ, logout_time TIMESTAMPTZ, activity TEXT) TO "login";
GRANT EXECUTE ON FUNCTION log_failed_login_attempt(username VARCHAR, reason TEXT) TO "login";
GRANT EXECUTE ON FUNCTION set_user_role(p_db_role_name VARCHAR) TO "login";


-- Step 11: Specifically for the audit_trail table's sequence
GRANT USAGE, SELECT ON SEQUENCE audit_trail_audit_id_seq TO "kppo_admin_user", "logistics_user", "report_viewer_user";

-- Step 12: For MRL_line_items table's sequence (if it exists)
GRANT USAGE, SELECT ON SEQUENCE mrl_line_items_order_line_item_id_seq TO "kppo_admin_user", "logistics_user";

-- Step 13: For fulfillment_items table's sequence (if it exists)
GRANT USAGE, SELECT ON SEQUENCE fulfillment_items_fulfillment_item_id_seq TO "kppo_admin_user", "logistics_user";
