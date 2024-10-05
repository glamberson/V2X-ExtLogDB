-- version 0.8.10


-- First, let's ensure the create_fulfillment_record function is up to date
CREATE OR REPLACE FUNCTION create_fulfillment_record(
    p_order_line_item_id INT, 
    p_created_by INT, 
    p_update_source TEXT
)
RETURNS VOID AS $$
DECLARE
    v_status_id INT;
BEGIN
    -- Get the 'NOT ORDERED' status ID
    SELECT status_id INTO v_status_id FROM statuses WHERE status_name = 'NOT ORDERED';

    INSERT INTO fulfillment_items (
        order_line_item_id, 
        created_by, 
        update_source, 
        created_at,
        status_id
    )
    VALUES (
        p_order_line_item_id, 
        p_created_by, 
        p_update_source, 
        CURRENT_TIMESTAMP,
        v_status_id
    );

    -- Log in audit trail
    PERFORM log_audit('INSERT', p_order_line_item_id, NULL, 'Fulfillment record created', p_update_source);
END;
$$ LANGUAGE plpgsql;

