-- version 0.7.14.39 Adding more detailed logging and error handling

CREATE OR REPLACE FUNCTION log_audit(
    action TEXT,
    order_line_item_id INT,
    fulfillment_item_id INT,
    details TEXT,
    update_source TEXT
)
RETURNS VOID AS $$
DECLARE
    current_user_id INT;
    current_role_id INT;
BEGIN
    RAISE LOG 'log_audit function started';
    
    -- Detailed input logging
    RAISE LOG 'log_audit input: action=%, order_line_item_id=%, fulfillment_item_id=%, details=%, update_source=%',
                 action, order_line_item_id, fulfillment_item_id, details, update_source;

    -- Retrieve and log session variables
    BEGIN
        current_user_id := current_setting('myapp.user_id', true)::INT;
        current_role_id := current_setting('myapp.role_id', true)::INT;
        RAISE LOG 'Session variables retrieved: user_id=%, role_id=%', current_user_id, current_role_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE LOG 'Error retrieving session variables: %', SQLERRM;
        current_user_id := NULL;
        current_role_id := NULL;
    END;

    -- Detailed type checking
    RAISE LOG 'Data types: action=%, order_line_item_id=%, fulfillment_item_id=%, details=%, update_source=%',
                 pg_typeof(action), pg_typeof(order_line_item_id), pg_typeof(fulfillment_item_id), 
                 pg_typeof(details), pg_typeof(update_source);

    -- Attempt to insert into audit_trail with detailed error handling
    BEGIN
        RAISE LOG 'Attempting to insert into audit_trail';
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
            current_user_id,
            CURRENT_TIMESTAMP,
            details,
            update_source,
            current_role_id,
            current_user_id
        );
        RAISE LOG 'Successfully inserted into audit_trail';
    EXCEPTION WHEN OTHERS THEN
        RAISE LOG 'Error inserting into audit_trail: %, SQLSTATE: %', SQLERRM, SQLSTATE;
        RAISE LOG 'Problematic data: order_line_item_id=%, fulfillment_item_id=%, action=%, changed_by=%, details=%, update_source=%, role_id=%, user_id=%',
                     order_line_item_id, fulfillment_item_id, action, current_user_id, details, update_source, current_role_id, current_user_id;
    END;
    
    RAISE LOG 'log_audit function completed';
END;
$$ LANGUAGE plpgsql;




