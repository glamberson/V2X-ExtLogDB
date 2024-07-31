-- version 0.7.14.9 debug

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
    v_user_id INT;
BEGIN
   -- Debug logging
    RAISE NOTICE 'log_audit input: action=%, order_line_item_id=%, fulfillment_item_id=%, details=%, update_source=%',
                 action, order_line_item_id, fulfillment_item_id, details, update_source;
    RAISE NOTICE 'Current settings: user_id=%, role_id=%',
                 current_setting('myapp.user_id', true), current_setting('myapp.role_id', true);
 

   -- Retrieve the session user_id
    v_user_id := current_setting('myapp.user_id')::INT;

    -- Check if user_id is correctly set
    IF v_user_id IS NULL OR v_user_id = 0 THEN
        RAISE EXCEPTION 'Invalid user_id: %', v_user_id;
    END IF;

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
        v_user_id,
        CURRENT_TIMESTAMP,
        details,
        update_source,
        current_setting('myapp.role_id')::INT,
        v_user_id
    );
END;
$$ LANGUAGE plpgsql;
