-- version 0.6.5

-- functions included are: audit_fulfillment_update, update_mrl_status, log_inquiry_status_change, add_line_item_comment, 
--                         log_line_item_comment, update_mrl_line_item, update_fulfillment_item,
--                         view_line_item_history, process_bulk_update


CREATE OR REPLACE FUNCTION audit_fulfillment_update()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trail (
        order_line_item_id, 
        fulfillment_item_id, 
        action, 
        changed_by, 
        details, 
        update_source, 
        changed_at
    )
    VALUES (
        NEW.order_line_item_id, 
        NEW.fulfillment_item_id, 
        'Update', 
        NEW.updated_by, 
        'Fulfillment record updated', 
        NEW.update_source, 
        NOW()
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

CREATE OR REPLACE FUNCTION log_inquiry_status_change()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        NEW.order_line_item_id,
        'Inquiry Status Updated',
        NEW.updated_by,
        'Inquiry Status '  NEW.inquiry_status,
        NEW.role_id,
        (SELECT user_id FROM users WHERE username = NEW.updated_by)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION add_line_item_comment (
    p_order_line_item_id INT,
    p_fulfillment_item_id INT,
    p_comment TEXT,
    p_commented_by VARCHAR,
    p_role_id INT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO line_item_comments (order_line_item_id, fulfillment_item_id, comment, commented_by, commented_at, role_id)
    VALUES (p_order_line_item_id, p_fulfillment_item_id, p_comment, p_commented_by, CURRENT_TIMESTAMP AT TIME ZONE 'UTC', p_role_id);

    -- Update the has_comments field in MRL_line_items or fulfillment_items
    IF p_order_line_item_id IS NOT NULL THEN
        UPDATE MRL_line_items
        SET has_comments = TRUE
        WHERE order_line_item_id = p_order_line_item_id;
    ELSE
        UPDATE fulfillment_items
        SET has_comments = TRUE
        WHERE fulfillment_item_id = p_fulfillment_item_id;
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION log_line_item_comment()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        NEW.order_line_item_id,
        'Comment Added',
        NEW.commented_by,
        'Comment: ' || NEW.comment,
        NEW.role_id,
        (SELECT user_id FROM users WHERE username = NEW.commented_by)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_mrl_line_item(
    p_order_line_item_id INT,
    p_field_name VARCHAR,
    p_new_value TEXT,
    p_updated_by VARCHAR,
    p_role_id INT
)
RETURNS VOID AS $$
BEGIN
    -- Construct dynamic SQL to update the specified field
    EXECUTE 'UPDATE MRL_line_items SET ' || p_field_name || ' = $1 WHERE order_line_item_id = $2'
    USING p_new_value, p_order_line_item_id;

    -- Log the update in the audit trail
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        p_order_line_item_id,
        'Update',
        p_updated_by,
        'Updated ' || p_field_name || ' to ' || p_new_value,
        p_role_id,
        (SELECT user_id FROM users WHERE username = p_updated_by)
    );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_fulfillment_item(
    p_fulfillment_item_id INT,
    p_field_name VARCHAR,
    p_new_value TEXT,
    p_updated_by VARCHAR,
    p_update_source VARCHAR,
    p_role_id INT
)
RETURNS VOID AS $$
BEGIN
    -- Construct dynamic SQL to update the specified field
    EXECUTE 'UPDATE fulfillment_items SET ' || p_field_name || ' = $1, updated_by = $2, updated_at = CURRENT_TIMESTAMP WHERE fulfillment_item_id = $3'
    USING p_new_value, p_updated_by, p_fulfillment_item_id;

    -- Log the update in the audit trail
    INSERT INTO audit_trail (order_line_item_id, action, changed_by, details, role_id, user_id)
    VALUES (
        (SELECT order_line_item_id FROM fulfillment_items WHERE fulfillment_item_id = p_fulfillment_item_id),
        'Update',
        p_updated_by,
        'Updated ' || p_field_name || ' to ' || p_new_value,
        p_role_id,
        (SELECT user_id FROM users WHERE username = p_updated_by)
    );
END;
$$ LANGUAGE plpgsql;




CREATE OR REPLACE FUNCTION view_line_item_history(p_order_line_item_id INT)
RETURNS TABLE (
    action_time TIMESTAMPTZ,
    action VARCHAR,
    changed_by VARCHAR,
    details TEXT,
    role_name VARCHAR,
    comment TEXT,
    comment_by VARCHAR,
    comment_time TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        at.changed_at AS action_time,
        at.action,
        at.changed_by,
        at.details,
        r.role_name,
        lc.comment,
        lc.commented_by AS comment_by,
        lc.commented_at AS comment_time
    FROM
        audit_trail at
    LEFT JOIN
        line_item_comments lc ON at.order_line_item_id = lc.order_line_item_id
    LEFT JOIN
        roles r ON at.role_id = r.role_id
    WHERE
        at.order_line_item_id = p_order_line_item_id
    ORDER BY
        at.changed_at, lc.commented_at;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_bulk_update()
RETURNS VOID AS $$
BEGIN
    -- Update fulfillment items based on temp_bulk_update data
    UPDATE fulfillment_items fi
    SET 
        fi.edd_to_ches = tbu.edd_to_ches,
        fi.carrier = tbu.carrier,
        -- Add other columns as necessary
        fi.updated_at = NOW(),
        fi.updated_by = 'bulk_update',
        fi.update_source = tbu.update_source
    FROM temp_bulk_update tbu
    WHERE 
        tbu.order_line_item_id = fi.order_line_item_id 
        AND tbu.fulfillment_item_id = fi.fulfillment_item_id;

    -- Log the update in the audit trail
    INSERT INTO audit_trail (
        order_line_item_id, 
        fulfillment_item_id, 
        action, 
        changed_by, 
        details, 
        update_source, 
        changed_at
    )
    SELECT 
        tbu.order_line_item_id, 
        tbu.fulfillment_item_id, 
        'Bulk Update', 
        'admin_user', 
        tbu.reason, 
        tbu.update_source, 
        NOW()
    FROM temp_bulk_update tbu;

    -- Flag records with multiple fulfillment items
    UPDATE temp_bulk_update tbu
    SET flag_for_review = TRUE
    WHERE (
        SELECT COUNT(*) 
        FROM fulfillment_items fi 
        WHERE fi.order_line_item_id = tbu.order_line_item_id
    ) > 1;
END;
$$ LANGUAGE plpgsql;



