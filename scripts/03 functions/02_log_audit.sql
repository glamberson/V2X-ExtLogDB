-- version 0.7.14.10 enhanced debug

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
    v_role_id INT;
BEGIN
    -- Detailed input logging
    RAISE NOTICE 'log_audit input: action=%, order_line_item_id=%, fulfillment_item_id=%, details=%, update_source=%',
                 action, order_line_item_id, fulfillment_item_id, details, update_source;

    -- Retrieve and log session variables
    BEGIN
        v_user_id := current_setting('myapp.user_id')::INT;
        v_role_id := current_setting('myapp.role_id')::INT;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error retrieving session variables: %', SQLERRM;
        v_user_id := NULL;
        v_role_id := NULL;
    END;

    RAISE NOTICE 'Session variables: user_id=%, role_id=%', v_user_id, v_role_id;

    -- Detailed type checking
    RAISE NOTICE 'Data types: action=%, order_line_item_id=%, fulfillment_item_id=%, details=%, update_source=%',
                 pg_typeof(action), pg_typeof(order_line_item_id), pg_typeof(fulfillment_item_id), 
                 pg_typeof(details), pg_typeof(update_source);

    -- Attempt to insert into audit_trail with detailed error handling
    BEGIN
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
            v_role_id,
            v_user_id
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error inserting into audit_trail: %, SQLSTATE: %', SQLERRM, SQLSTATE;
        RAISE NOTICE 'Problematic data: order_line_item_id=%, fulfillment_item_id=%, action=%, changed_by=%, details=%, update_source=%, role_id=%, user_id=%',
                     order_line_item_id, fulfillment_item_id, action, v_user_id, details, update_source, v_role_id, v_user_id;
    END;
END;
$$ LANGUAGE plpgsql;

