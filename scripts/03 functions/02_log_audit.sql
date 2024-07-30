-- version 0.7.13

-- log audit

CREATE OR REPLACE FUNCTION log_audit(
    action TEXT,
    order_line_item_id INT,
    fulfillment_item_id INT,
    details TEXT,
    update_source TEXT
)
RETURNS VOID AS $$
DECLARE
    v_changed_by_username VARCHAR;
BEGIN
    -- Look up the username associated with the current user_id
    SELECT username INTO v_changed_by_username
    FROM users
    WHERE user_id = current_setting('myapp.user_id')::INT;

    -- Insert into the audit trail
    INSERT INTO audit_trail (
        order_line_item_id, 
        fulfillment_item_id, 
        action, 
        changed_by, 
        changed_at, 
        details, 
        update_source, 
        role_id, 
        user_id
    ) VALUES (
        order_line_item_id, 
        fulfillment_item_id, 
        action, 
        v_changed_by_username, 
        CURRENT_TIMESTAMP, 
        details, 
        update_source, 
        current_setting('myapp.role_id')::INT, 
        current_setting('myapp.user_id')::INT
    );
END;
$$ LANGUAGE plpgsql;
