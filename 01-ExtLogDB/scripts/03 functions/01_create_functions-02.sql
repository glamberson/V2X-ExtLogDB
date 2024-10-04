-- version 0.6

-- functions included: bulk_update_fulfillment_items,
--                     audit_line_item_update, log_status_change,
--                     update_mrl_status,




-- Function to perform bulk update of fulfillment items
CREATE OR REPLACE FUNCTION bulk_update_fulfillment_items()
RETURNS VOID AS $$
DECLARE
    record RECORD;
BEGIN
    -- Loop through each record in the temp_bulk_update table
    FOR record IN SELECT * FROM temp_bulk_update LOOP
        -- Check if the fulfillment item exists
        IF EXISTS (SELECT 1 FROM fulfillment_items WHERE fulfillment_item_id = record.fulfillment_item_id) THEN
            -- Update the fulfillment item
            PERFORM update_fulfillment_item(
                record.fulfillment_item_id,
                record.order_line_item_id,
                record.milstrip_req_no,
                record.edd_to_ches,
                record.rcd_v2x_date,
                record.lot_id,
                record.triwall,
                record.shipdoc_tcn,
                record.v2x_ship_no,
                record.booking,
                record.vessel,
                record.container,
                record.sail_date,
                record.edd_to_egypt,
                record.arr_lsc_egypt,
                record.lsc_on_hand_date,
                record.carrier,
                record.status_id,
                'Bulk Update',
                record.reason
            );
        ELSE
            -- Flag the record for manual review if the fulfillment item does not exist
            UPDATE temp_bulk_update
            SET flag_for_review = TRUE
            WHERE fulfillment_item_id = record.fulfillment_item_id;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION audit_line_item_update()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        NEW.order_line_item_id,
        'Update',
        NEW.updated_by,
        'Updated record',
        NEW.role_id,
        (SELECT user_id FROM users WHERE username = NEW.updated_by)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION log_status_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        NEW.order_line_item_id,
        'Status Updated',
        NEW.updated_by,
        'Status changed to ' || (SELECT status_name FROM statuses WHERE status_id = NEW.status_id),
        NEW.role_id,
        NEW.user_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_mrl_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Update MRL line item status based on fulfillment records
    UPDATE MRL_line_items
    SET status_id = (
        SELECT MIN(s.status_value)
        FROM fulfillment_items fi
        JOIN statuses s ON fi.status_id = s.status_id
        WHERE fi.order_line_item_id = NEW.order_line_item_id
    ),
    multiple_fulfillments = (
        SELECT COUNT(*) > 1
        FROM fulfillment_items fi
        WHERE fi.order_line_item_id = NEW.order_line_item_id
    )
    WHERE order_line_item_id = NEW.order_line_item_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;



