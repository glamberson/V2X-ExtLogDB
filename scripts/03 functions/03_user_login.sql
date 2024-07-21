
-- version 0.6.5

-- user login



CREATE OR REPLACE FUNCTION user_login(
    p_username VARCHAR,
    p_password VARCHAR
)
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id INT;
    v_role_id INT;
    v_password_hash VARCHAR;
    v_login_successful BOOLEAN := FALSE;
BEGIN
    -- Check if the user exists and get the password hash
    SELECT user_id, role_id, password_hash INTO v_user_id, v_role_id, v_password_hash
    FROM users
    WHERE username = p_username;

    -- Verify the password
    IF crypt(p_password, v_password_hash) = v_password_hash THEN
        v_login_successful := TRUE;

        -- Log the login activity
        PERFORM log_user_activity(v_user_id, 'login', 'User logged in');

        -- Also log this activity into the audit trail
        INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
        VALUES (
            NULL, -- No specific line item ID for general user activity
            'login',
            p_username,
            'User logged in',
            v_role_id,
            v_user_id
        );
    ELSE
        -- Log the failed login attempt
        PERFORM log_failed_login_attempt(p_username, 'Incorrect password');

        -- Also log this activity into the audit trail
        INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
        VALUES (
            NULL, -- No specific line item ID for general user activity
            'failed_login',
            p_username,
            'Incorrect password',
            NULL, -- No specific role for general user activity
            NULL -- No specific user ID for failed login
        );
    END IF;

    RETURN v_login_successful;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Log the failed login attempt
        PERFORM log_failed_login_attempt(p_username, 'User not found');

        -- Also log this activity into the audit trail
        INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
        VALUES (
            NULL, -- No specific line item ID for general user activity
            'failed_login',
            p_username,
            'User not found',
            NULL, -- No specific role for general user activity
            NULL -- No specific user ID for failed login
        );

        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;