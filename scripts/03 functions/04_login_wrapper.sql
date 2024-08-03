
-- version 0.7.14.20

-- user login wrapper (use this to log in while maintaining minimal "login" permissions)

CREATE OR REPLACE FUNCTION login_wrapper(p_username VARCHAR, p_password VARCHAR, p_duration INTERVAL)
RETURNS TABLE (session_id UUID, login_user_id INT, login_role_id INT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY SELECT * FROM user_login(p_username, p_password, p_duration);
END;
$$;

