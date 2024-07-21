
-- version 0.6.5

-- user logout



CREATE OR REPLACE FUNCTION user_logout(
    p_user_id INT
)
RETURNS VOID AS $$
DECLARE
    v_username VARCHAR;
    v_role_id INT;
BEGIN
    -- Get the username and role ID
    SELECT username, role_id INTO v_username, v_role_id
    FROM users
    WHERE user_id = p_user_id;

    -- Log the logout activity
    PERFORM log_user_activity(p_user_id, 'logout', 'User logged out');

    -- Also log this activity into the audit trail
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        NULL, -- No specific line item ID for general user activity
        'logout',
        v_username,
        'User logged out',
        v_role_id,
        p_user_id
    );
END;
$$ LANGUAGE plpgsql;
