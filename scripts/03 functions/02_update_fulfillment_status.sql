-- version 0.6.3

-- update fulfillment status


CREATE OR REPLACE FUNCTION update_fulfillment_status(order_line_item_id INT, fulfillment_item_id INT, status_id INT, updated_by INT, update_source TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE fulfillment_items
    SET status_id = status_id, updated_by = updated_by, update_source = update_source, updated_at = CURRENT_TIMESTAMP
    WHERE fulfillment_item_id = fulfillment_item_id;

    -- Log status change in audit trail
    PERFORM log_audit('UPDATE', order_line_item_id, fulfillment_item_id, updated_by, 'Fulfillment status updated');

    -- Cascade status to MRL line item
    PERFORM cascade_status_to_mrl(order_line_item_id);
END;
$$ LANGUAGE plpgsql;


