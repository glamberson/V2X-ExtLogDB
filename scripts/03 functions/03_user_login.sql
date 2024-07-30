
-- version 0.7.13.4

-- user login (database session version)


CREATE OR REPLACE FUNCTION user_login(
    p_username VARCHAR,
    p_password VARCHAR,
    p_duration INTERVAL
)
RETURNS UUID AS $$
DECLARE
    v_user_id INT;
    v_role_id INT;
    v_password_hash VARCHAR;
    v_session_id UUID;
BEGIN
    -- Check if the user exists and get the password hash
    SELECT user_id, role_id, password_hash INTO v_user_id, v_role_id, v_password_hash
    FROM users
    WHERE username = p_username;

    -- Verify the password
    IF FOUND AND crypt(p_password, v_password_hash) = v_password_hash THEN
        -- Create a session
        v_session_id := create_session(v_user_id, v_role_id, p_duration);

        -- Set user_id and role_id for the current session
        PERFORM set_config('myapp.user_id', v_user_id::TEXT, TRUE);
        PERFORM set_config('myapp.role_id', v_role_id::TEXT, TRUE);

        -- Log the login activity
        PERFORM log_user_activity(v_user_id, CURRENT_TIMESTAMP, NULL, 'User logged in');

        RETURN v_session_id;
    ELSE
        -- Log the failed login attempt
        PERFORM log_failed_login_attempt(p_username, 'Incorrect password');

        RETURN NULL;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Log the failed login attempt
        PERFORM log_failed_login_attempt(p_username, 'User not found');

        RETURN NULL;
END;
$$ LANGUAGE plpgsql;


