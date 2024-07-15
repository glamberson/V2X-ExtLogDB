-- version 0.6.01


CREATE OR REPLACE FUNCTION combined_status_audit_update()
RETURNS TRIGGER AS $$
DECLARE
    v_status_id INT;
BEGIN
    -- Handle MRL line item insert
    IF (TG_OP = 'INSERT' AND TG_TABLE_NAME = 'MRL_line_items') THEN
        INSERT INTO fulfillment_items (order_line_item_id, created_by, status_id)
        VALUES (NEW.order_line_item_id, NEW.created_by, NEW.status_id);
    END IF;

    -- Handle fulfillment item status update
    IF TG_TABLE_NAME = 'fulfillment_items' THEN
        IF NEW.lsc_on_hand_date IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ON HAND EGYPT');
        ELSIF NEW.arr_lsc_egypt IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ARR EGYPT');
        ELSIF NEW.sail_date IS NOT NULL AND NEW.sail_date <= CURRENT_DATE THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'EN ROUTE TO EGYPT');
        ELSIF NEW.sail_date IS NOT NULL AND NEW.sail_date > CURRENT_DATE THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'FREIGHT FORWARDER');
        ELSIF NEW.shipdoc_tcn IS NOT NULL OR NEW.v2x_ship_no IS NOT NULL OR NEW.booking IS NOT NULL OR NEW.vessel IS NOT NULL OR NEW.container IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'READY TO SHIP');
        ELSIF NEW.lot_id IS NOT NULL AND NEW.triwall IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'PROC CHES WH');
        ELSIF NEW.rcd_v2x_date IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'RCD CHES WH');
        ELSIF NEW.edd_to_ches IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ON ORDER');
        ELSIF NEW.milstrip_req_no IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'INIT PROCESS');
        ELSE
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'NOT ORDERED');
        END IF;
    END IF;

    -- Update MRL line item status based on fulfillment status
    SELECT MAX(status_id) INTO v_status_id
    FROM fulfillment_items
    WHERE order_line_item_id = NEW.order_line_item_id;

    UPDATE MRL_line_items
    SET status_id = v_status_id
    WHERE order_line_item_id = NEW.order_line_item_id;

    -- Insert into audit trail
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
    )
    VALUES (
        NEW.order_line_item_id, 
        NEW.fulfillment_item_id, 
        'Status Updated', 
        NEW.updated_by, 
        CURRENT_TIMESTAMP, 
        'Status: ' || (SELECT status_name FROM statuses WHERE status_id = NEW.status_id), 
        NEW.update_source, 
        NEW.role_id, 
        NEW.user_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Triggers for the combined function
CREATE TRIGGER trg_combined_status_audit_update
AFTER INSERT OR UPDATE ON fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();

CREATE TRIGGER trg_create_fulfillment_on_mrl_insert
AFTER INSERT ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();


CREATE OR REPLACE FUNCTION combined_status_audit_update()
RETURNS TRIGGER AS $$
DECLARE
    v_status_id INT;
BEGIN
    -- Handle MRL line item insert
    IF (TG_OP = 'INSERT' AND TG_TABLE_NAME = 'MRL_line_items') THEN
        INSERT INTO fulfillment_items (order_line_item_id, created_by, status_id)
        VALUES (NEW.order_line_item_id, NEW.created_by, NEW.status_id);
    END IF;

    -- Handle fulfillment item status update
    IF TG_TABLE_NAME = 'fulfillment_items' THEN
        IF NEW.lsc_on_hand_date IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ON HAND EGYPT');
        ELSIF NEW.arr_lsc_egypt IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ARR EGYPT');
        ELSIF NEW.sail_date IS NOT NULL AND NEW.sail_date <= CURRENT_DATE THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'EN ROUTE TO EGYPT');
        ELSIF NEW.sail_date IS NOT NULL AND NEW.sail_date > CURRENT_DATE THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'FREIGHT FORWARDER');
        ELSIF NEW.shipdoc_tcn IS NOT NULL OR NEW.v2x_ship_no IS NOT NULL OR NEW.booking IS NOT NULL OR NEW.vessel IS NOT NULL OR NEW.container IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'READY TO SHIP');
        ELSIF NEW.lot_id IS NOT NULL AND NEW.triwall IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'PROC CHES WH');
        ELSIF NEW.rcd_v2x_date IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'RCD CHES WH');
        ELSIF NEW.edd_to_ches IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'ON ORDER');
        ELSIF NEW.milstrip_req_no IS NOT NULL THEN
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'INIT PROCESS');
        ELSE
            NEW.status_id := (SELECT status_id FROM statuses WHERE status_name = 'NOT ORDERED');
        END IF;
    END IF;

    -- Update MRL line item status based on fulfillment status
    SELECT MAX(status_id) INTO v_status_id
    FROM fulfillment_items
    WHERE order_line_item_id = NEW.order_line_item_id;

    UPDATE MRL_line_items
    SET status_id = v_status_id
    WHERE order_line_item_id = NEW.order_line_item_id;

    -- Insert into audit trail
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
    )
    VALUES (
        NEW.order_line_item_id, 
        NEW.fulfillment_item_id, 
        'Status Updated', 
        NEW.updated_by, 
        CURRENT_TIMESTAMP, 
        'Status: ' || (SELECT status_name FROM statuses WHERE status_id = NEW.status_id), 
        NEW.update_source, 
        NEW.role_id, 
        NEW.user_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Triggers for the combined function
CREATE TRIGGER trg_combined_status_audit_update
AFTER INSERT OR UPDATE ON fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();

CREATE TRIGGER trg_create_fulfillment_on_mrl_insert
AFTER INSERT ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();

