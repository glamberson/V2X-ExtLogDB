-- version 0.5.1

-- functions included: view_items_in_inquiry_status, view_line_item_history_including_comments, bulk_update_fulfillment_items,
--                     archive_line_item, log_failed_login, audit_line_item_update, log_status_change, update_fulfillment_status,
--                     update_mrl_status,


-- Function to view all items in inquiry status
CREATE OR REPLACE FUNCTION view_items_in_inquiry_status()
RETURNS TABLE(
    order_line_item_id INT,
    inquiry_status BOOLEAN,
    updated_by VARCHAR(50),
    updated_at TIMESTAMPTZ,
    role_id INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        order_line_item_id,
        inquiry_status,
        updated_by,
        updated_at,
        role_id
    FROM line_item_inquiry
    WHERE inquiry_status = TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to view line item history including comments
CREATE OR REPLACE FUNCTION view_line_item_history(p_order_line_item_id INT)
RETURNS TABLE(
    fulfillment_item_id INT,
    action VARCHAR(100),
    changed_by VARCHAR(50),
    changed_at TIMESTAMPTZ,
    details TEXT,
    update_source VARCHAR(50),
    comment TEXT,
    commented_by VARCHAR(100),
    commented_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.fulfillment_item_id,
        a.action,
        a.changed_by,
        a.changed_at,
        a.details,
        a.update_source,
        c.comment,
        c.commented_by,
        c.commented_at
    FROM audit_trail a
    LEFT JOIN line_item_comments c ON a.order_line_item_id = c.order_line_item_id
    WHERE a.order_line_item_id = p_order_line_item_id;
END;
$$ LANGUAGE plpgsql;


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

-- Function to archive a line item and its associated fulfillment items
CREATE OR REPLACE FUNCTION archive_line_item(
    p_order_line_item_id INT,
    p_archived_by VARCHAR(50)
)
RETURNS VOID AS $$
BEGIN
    -- Insert into audit trail before archiving
    INSERT INTO audit_trail (
        order_line_item_id, 
        action, 
        changed_by, 
        changed_at, 
        details, 
        update_source, 
        role_id, 
        user_id
    )
    VALUES (
        p_order_line_item_id, 
        'Archived', 
        p_archived_by, 
        CURRENT_TIMESTAMP, 
        'Line item and associated fulfillment items archived', 
        'Archive Process', 
        (SELECT role_id FROM users WHERE username = p_archived_by), 
        (SELECT user_id FROM users WHERE username = p_archived_by)
    );

    -- Archive fulfillment items
    UPDATE fulfillment_items
    SET status_id = (SELECT status_id FROM statuses WHERE status_name = 'ARCHIVED')
    WHERE order_line_item_id = p_order_line_item_id;

    -- Archive MRL line item
    UPDATE MRL_line_items
    SET status_id = (SELECT status_id FROM statuses WHERE status_name = 'ARCHIVED')
    WHERE order_line_item_id = p_order_line_item_id;
END;
$$ LANGUAGE plpgsql;

-- Function to log failed login attempts
CREATE OR REPLACE FUNCTION log_failed_login(
    p_username VARCHAR(100),
    p_reason TEXT
)
RETURNS VOID AS $$
DECLARE
    v_user_id INT;
BEGIN
    -- Get user ID if the username exists
    SELECT user_id INTO v_user_id
    FROM users
    WHERE username = p_username;

    -- Insert failed login activity
    INSERT INTO user_activity (
        user_id,
        activity_type,
        activity_time,
        activity_details
    )
    VALUES (
        v_user_id,
        'failed_login',
        CURRENT_TIMESTAMP,
        p_reason
    );
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

CREATE OR REPLACE FUNCTION update_fulfillment_status()
RETURNS TRIGGER AS $$
BEGIN
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



