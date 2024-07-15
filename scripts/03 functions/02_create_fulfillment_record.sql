-- version 0.6.3

-- create_fulfillment_record


CREATE OR REPLACE FUNCTION create_fulfillment_record(order_line_item_id INT, created_by INT, update_source TEXT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO fulfillment_items (order_line_item_id, created_by, update_source, created_at)
    VALUES (order_line_item_id, created_by, update_source, CURRENT_TIMESTAMP);

    -- Log in audit trail
    PERFORM log_audit('INSERT', order_line_item_id, NULL, created_by, 'Fulfillment record created');
END;
$$ LANGUAGE plpgsql;
