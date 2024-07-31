
-- version 0.7.14.15

-- user login wrapper (use this to log in while maintaining minimal "login" permissions)

CREATE OR REPLACE FUNCTION login_wrapper(p_username VARCHAR, p_password VARCHAR, p_duration INTERVAL)
RETURNS TABLE (session_id UUID, user_id INT, role_id INT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID;
    v_user_id INT;
    v_role_id INT;
BEGIN
    SELECT * INTO v_session_id, v_user_id, v_role_id 
    FROM user_login(p_username, p_password, p_duration);
    
    RETURN QUERY SELECT v_session_id, v_user_id, v_role_id;
END;
$$;