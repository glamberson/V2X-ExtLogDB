-- version 0.6.3

-- cascade_status_to_mrl


CREATE OR REPLACE FUNCTION cascade_status_to_mrl(order_line_item_id INT)
RETURNS VOID AS $$
DECLARE
    new_status_id INT;
BEGIN
    SELECT MIN(status_id) INTO new_status_id
    FROM fulfillment_items
    WHERE order_line_item_id = order_line_item_id;

    UPDATE MRL_line_items
    SET status_id = new_status_id, updated_at = CURRENT_TIMESTAMP
    WHERE order_line_item_id = order_line_item_id;

    -- Log status change in audit trail
    PERFORM log_audit('UPDATE', order_line_item_id, NULL, current_setting('user.id')::INT, 'MRL status updated based on fulfillment');
END;
$$ LANGUAGE plpgsql;



