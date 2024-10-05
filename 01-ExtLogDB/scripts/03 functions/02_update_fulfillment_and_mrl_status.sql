-- version 0.10.22
-- Updated Trigger Function to Set MRL_line_items.status_id to MIN(status_id)

CREATE OR REPLACE FUNCTION update_fulfillment_and_mrl_status()
RETURNS TRIGGER AS $$
DECLARE
    v_old_status_id INT;
    v_new_status_id INT;
    v_status_name TEXT;
    v_mrl_status_id INT;
    v_mrl_old_status_id INT;
BEGIN
    -- Logging the trigger invocation
    RAISE LOG 'Trigger fired for fulfillment_item_id: %, order_line_item_id: %', NEW.fulfillment_item_id, NEW.order_line_item_id;
    
    -- Store the old status
    v_old_status_id := OLD.status_id;
    RAISE LOG 'Old fulfillment_item status_id: %', v_old_status_id;

    -- Determine the new status based on the updated fulfillment item using CASE for clarity
    SELECT status_id INTO v_new_status_id
    FROM statuses
    WHERE status_name = CASE
        WHEN NEW.lsc_on_hand_date IS NOT NULL THEN 'ON HAND EGYPT'
        WHEN NEW.arr_lsc_egypt IS NOT NULL THEN 'ARR EGYPT'
        WHEN NEW.sail_date IS NOT NULL AND NEW.sail_date <= CURRENT_DATE THEN 'EN ROUTE TO EGYPT'
        WHEN NEW.sail_date IS NOT NULL AND NEW.sail_date > CURRENT_DATE THEN 'FREIGHT FORWARDER'
        WHEN NEW.shipdoc_tcn IS NOT NULL OR NEW.v2x_ship_no IS NOT NULL OR NEW.booking IS NOT NULL OR NEW.vessel IS NOT NULL OR NEW.container IS NOT NULL THEN 'READY TO SHIP'
        WHEN NEW.lot_id IS NOT NULL AND NEW.triwall IS NOT NULL THEN 'PROC CHES WH'
        WHEN NEW.rcd_v2x_date IS NOT NULL THEN 'RCD CHES WH'
        WHEN NEW.edd_to_ches IS NOT NULL THEN 'ON ORDER'
        WHEN NEW.milstrip_req_no IS NOT NULL THEN 'INIT PROCESS'
        ELSE 'NOT ORDERED'
    END;

    RAISE LOG 'Determined new fulfillment_item status_id: %', v_new_status_id;

    -- Update the fulfillment item status if it has changed
    IF v_new_status_id != v_old_status_id THEN
        NEW.status_id := v_new_status_id;
        RAISE LOG 'Updating fulfillment item status from % to %', v_old_status_id, v_new_status_id;
        
        -- Get the status name for logging
        SELECT status_name INTO v_status_name FROM statuses WHERE status_id = v_new_status_id;
        RAISE LOG 'New fulfillment_item status name: %', v_status_name;

        -- Log the status change for the fulfillment item
        PERFORM log_audit(
            'UPDATE'::TEXT, 
            NEW.order_line_item_id, 
            NEW.fulfillment_item_id,
            format(
                'Fulfillment item status updated from %s to %s', 
                (SELECT status_name FROM statuses WHERE status_id = v_old_status_id),
                v_status_name
            ),
            NEW.update_source
        );
    ELSE
        RAISE LOG 'Fulfillment item status not changed. Remains at status_id: %', v_old_status_id;
    END IF;

    -- Update the associated MRL line item status to the MIN(status_id) among related fulfillment_items
    SELECT status_id INTO v_mrl_old_status_id
    FROM MRL_line_items
    WHERE order_line_item_id = NEW.order_line_item_id;
    RAISE LOG 'Current MRL_line_item status_id: %', v_mrl_old_status_id;

    -- Determine the new MRL_line_item status_id as the MIN of associated fulfillment_items.status_id
    SELECT MIN(fi.status_id) INTO v_mrl_status_id
    FROM fulfillment_items fi
    WHERE fi.order_line_item_id = NEW.order_line_item_id;

    RAISE LOG 'Determined new MRL_line_item status_id: %', v_mrl_status_id;

    -- Update MRL_line_items.status_id if it has changed
    IF v_mrl_status_id != v_mrl_old_status_id THEN
        UPDATE MRL_line_items
        SET status_id = v_mrl_status_id
        WHERE order_line_item_id = NEW.order_line_item_id;
        RAISE LOG 'Updated MRL_line_item status_id from % to %', v_mrl_old_status_id, v_mrl_status_id;

        -- Get the new status name for logging
        SELECT status_name INTO v_status_name FROM statuses WHERE status_id = v_mrl_status_id;
        RAISE LOG 'New MRL_line_item status name: %', v_status_name;

        -- Log the status change for the MRL line item
        PERFORM log_audit(
            'UPDATE'::TEXT, 
            NEW.order_line_item_id, 
            NULL, -- fulfillment_item_id is not applicable here
            format(
                'MRL line item status updated from %s to %s', 
                (SELECT status_name FROM statuses WHERE status_id = v_mrl_old_status_id),
                v_status_name
            ),
            NEW.update_source
        );
    ELSE
        RAISE LOG 'MRL_line_item status not changed. Remains at status_id: %', v_mrl_old_status_id;
    END IF;

    RAISE LOG 'Trigger function completed for fulfillment_item_id: %', NEW.fulfillment_item_id;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Error in trigger function for fulfillment_item_id %: %', NEW.fulfillment_item_id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
