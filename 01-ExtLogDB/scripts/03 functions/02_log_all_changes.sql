-- version 0.6


CREATE OR REPLACE FUNCTION log_all_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert log for updates
    IF TG_OP = 'UPDATE' THEN
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
            'UPDATE',
            COALESCE(NEW.updated_by, OLD.updated_by),
            CURRENT_TIMESTAMP,
            'Updated Fields: ' || hstore(OLD.*) - hstore(NEW.*),
            NEW.update_source,
            COALESCE(NEW.role_id, OLD.role_id),
            COALESCE(NEW.user_id, OLD.user_id)
        );
    END IF;

    -- Insert log for inserts
    IF TG_OP = 'INSERT' THEN
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
            'INSERT',
            NEW.updated_by,
            CURRENT_TIMESTAMP,
            'New Record Created',
            NEW.update_source,
            NEW.role_id,
            NEW.user_id
        );
    END IF;

    -- Insert log for deletes
    IF TG_OP = 'DELETE' THEN
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
            OLD.order_line_item_id,
            OLD.fulfillment_item_id,
            'DELETE',
            OLD.updated_by,
            CURRENT_TIMESTAMP,
            'Record Deleted',
            OLD.update_source,
            OLD.role_id,
            OLD.user_id
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

