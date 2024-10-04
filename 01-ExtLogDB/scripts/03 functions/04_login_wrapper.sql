
-- version 0.7.14.39

CREATE OR REPLACE FUNCTION login_wrapper(p_username VARCHAR, p_password VARCHAR, p_duration INTERVAL)
RETURNS TABLE (session_id UUID, login_user_id INT, login_role_id INT, login_db_role_name VARCHAR)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID;
    v_user_id INT;
    v_role_id INT;
    v_db_role_name VARCHAR;
BEGIN
    -- Call user_login function
    SELECT * INTO v_session_id, v_user_id, v_role_id 
    FROM user_login(p_username, p_password, p_duration);

    -- If login was successful
    IF v_session_id IS NOT NULL THEN
        -- Get the database role name
        SELECT r.db_role_name INTO v_db_role_name
        FROM roles r
        WHERE r.role_id = v_role_id;
    END IF;

    RETURN QUERY SELECT v_session_id, v_user_id, v_role_id, v_db_role_name;
END;
$$;