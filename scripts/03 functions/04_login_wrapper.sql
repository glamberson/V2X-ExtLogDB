
-- version 0.7.5

-- user login wrapper (use this to log in while maintaining minimal "login" permissions)

CREATE OR REPLACE FUNCTION login_wrapper(p_username VARCHAR, p_password VARCHAR, p_duration INTERVAL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result UUID;
BEGIN
    v_result := user_login(p_username, p_password, p_duration);
    RETURN v_result;
END;
$$;