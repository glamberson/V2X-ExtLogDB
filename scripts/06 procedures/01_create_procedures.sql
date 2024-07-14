-- version 0.5.1



CREATE OR REPLACE PROCEDURE batch_update_statuses(updates JSONB)
LANGUAGE plpgsql
AS $$
DECLARE
    update_item JSONB; -- Variable to hold each update item from the JSONB array
    record_id INT; -- Variable to hold the order_line_item_id from the update item
    new_status VARCHAR; -- Variable to hold the new status_name from the update item
BEGIN
    -- Loop through each item in the updates JSONB array
    FOR update_item IN SELECT * FROM jsonb_array_elements(updates)
    LOOP
        -- Extract the order_line_item_id and status_name from the update item
        record_id := (update_item->>'order_line_item_id')::INT;
        new_status := update_item->>'status_name';
        
        -- Update the status_id of the fulfillment item based on the new status_name
        UPDATE fulfillment_items
        SET status_id = (SELECT status_id FROM statuses WHERE status_name = new_status)
        WHERE order_line_item_id = record_id;

        -- Perform the MRL status update to reflect the changes
        PERFORM update_mrl_status();
    END LOOP;
END;
$$;

