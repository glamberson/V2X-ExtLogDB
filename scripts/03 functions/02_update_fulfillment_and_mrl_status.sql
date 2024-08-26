
-- version 0.9.40
-- Trigger function to update status and log changes

CREATE OR REPLACE FUNCTION update_fulfillment_and_mrl_status()
RETURNS TRIGGER AS $$
DECLARE
    v_old_status_id INT;
    v_new_status_id INT;
    v_status_name TEXT;
    v_mrl_status_id INT;
    v_mrl_old_status_id INT;
BEGIN
    RAISE LOG 'Trigger fired for fulfillment_item_id: %, order_line_item_id: %', NEW.fulfillment_item_id, NEW.order_line_item_id;
    
    -- Store the old status
    v_old_status_id := OLD.status_id;
    RAISE LOG 'Old status_id: %', v_old_status_id;

    -- Determine the new status based on the updated fulfillment item
    IF NEW.lsc_on_hand_date IS NOT NULL THEN
        v_new_status_id := (SELECT status_id FROM statuses WHERE status_name = 'ON HAND EGYPT');
    ELSIF NEW.arr_lsc_egypt IS NOT NULL THEN
        v_new_status_id := (SELECT status_id FROM statuses WHERE status_name = 'ARR EGYPT');
    ELSIF NEW.sail_date IS NOT NULL AND NEW.sail_date <= CURRENT_DATE THEN
        v_new_status_id := (SELECT status_id FROM statuses WHERE status_name = 'EN ROUTE TO EGYPT');
    ELSIF NEW.sail_date IS NOT NULL AND NEW.sail_date > CURRENT_DATE THEN
        v_new_status_id := (SELECT status_id FROM statuses WHERE status_name = 'FREIGHT FORWARDER');
    ELSIF NEW.shipdoc_tcn IS NOT NULL OR NEW.v2x_ship_no IS NOT NULL OR NEW.booking IS NOT NULL OR NEW.vessel IS NOT NULL OR NEW.container IS NOT NULL THEN
        v_new_status_id := (SELECT status_id FROM statuses WHERE status_name = 'READY TO SHIP');
    ELSIF NEW.lot_id IS NOT NULL AND NEW.triwall IS NOT NULL THEN
        v_new_status_id := (SELECT status_id FROM statuses WHERE status_name = 'PROC CHES WH');
    ELSIF NEW.rcd_v2x_date IS NOT NULL THEN
        v_new_status_id := (SELECT status_id FROM statuses WHERE status_name = 'RCD CHES WH');
    ELSIF NEW.edd_to_ches IS NOT NULL THEN
        v_new_status_id := (SELECT status_id FROM statuses WHERE status_name = 'ON ORDER');
    ELSIF NEW.milstrip_req_no IS NOT NULL THEN
        v_new_status_id := (SELECT status_id FROM statuses WHERE status_name = 'INIT PROCESS');
    ELSE
        v_new_status_id := (SELECT status_id FROM statuses WHERE status_name = 'NOT ORDERED');
    END IF;
    RAISE LOG 'Determined new status_id: %', v_new_status_id;

    -- Update the fulfillment item status if it has changed
    IF v_new_status_id != v_old_status_id THEN
        NEW.status_id := v_new_status_id;
        RAISE LOG 'Updating fulfillment item status from % to %', v_old_status_id, v_new_status_id;
        
        -- Get the status name for logging
        SELECT status_name INTO v_status_name FROM statuses WHERE status_id = v_new_status_id;
        RAISE LOG 'New status name: %', v_status_name;

        -- Log the status change for the fulfillment item
        PERFORM log_audit(
            'UPDATE'::TEXT, 
            NEW.order_line_item_id, 
            NEW.fulfillment_item_id,
            format('Fulfillment item status updated from %s to %s', 
                   (SELECT status_name FROM statuses WHERE status_id = v_old_status_id),
                   v_status_name)::TEXT,
            NEW.update_source
        );
    ELSE
        RAISE LOG 'Fulfillment item status not changed. Remains at %', v_old_status_id;
    END IF;

    -- Update the associated MRL line item status
    SELECT status_id INTO v_mrl_old_status_id
    FROM MRL_line_items
    WHERE order_line_item_id = NEW.order_line_item_id;
    RAISE LOG 'Current MRL line item status_id: %', v_mrl_old_status_id;

    SELECT MAX(status_id) INTO v_mrl_status_id
    FROM fulfillment_items
    WHERE order_line_item_id = NEW.order_line_item_id;
    RAISE LOG 'Determined new MRL line item status_id: %', v_mrl_status_id;

    IF v_mrl_status_id != v_mrl_old_status_id THEN
        UPDATE MRL_line_items
        SET status_id = v_mrl_status_id
        WHERE order_line_item_id = NEW.order_line_item_id;
        RAISE LOG 'Updated MRL line item status from % to %', v_mrl_old_status_id, v_mrl_status_id;

        -- Log the status change for the MRL line item
        PERFORM log_audit(
            'UPDATE'::TEXT, 
            NEW.order_line_item_id, 
            NULL,
            format('MRL line item status updated from %s to %s', 
                   (SELECT status_name FROM statuses WHERE status_id = v_mrl_old_status_id),
                   (SELECT status_name FROM statuses WHERE status_id = v_mrl_status_id))::TEXT,
            NEW.update_source
        );
    ELSE
        RAISE LOG 'MRL line item status not changed. Remains at %', v_mrl_old_status_id;
    END IF;

    RAISE LOG 'Trigger function completed for fulfillment_item_id: %', NEW.fulfillment_item_id;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Error in trigger function for fulfillment_item_id %: %', NEW.fulfillment_item_id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

