-- version 0.7

-- unconfirmed or implemented



CREATE TRIGGER trigger_audit_fulfillment_item_updates
AFTER UPDATE ON fulfillment_items
FOR EACH ROW EXECUTE FUNCTION audit_fulfillment_item_updates();


CREATE TRIGGER trigger_audit_fulfillment_updates
AFTER UPDATE ON fulfillment_items
FOR EACH ROW EXECUTE FUNCTION audit_fulfillment_updates();


-- Trigger for auditing line item updates
CREATE TRIGGER trigger_audit_line_item_update
AFTER UPDATE ON MRL_line_items
FOR EACH ROW EXECUTE FUNCTION audit_line_item_update();

-- Trigger for logging inquiry status changes
CREATE TRIGGER trigger_log_inquiry_status_change
AFTER INSERT OR UPDATE ON line_item_inquiry
FOR EACH ROW EXECUTE FUNCTION log_inquiry_status_change();

-- Trigger for logging line item comments
CREATE TRIGGER trigger_log_line_item_comment
AFTER INSERT ON line_item_comments
FOR EACH ROW EXECUTE FUNCTION log_line_item_comment();

-- Trigger for logging status changes
CREATE TRIGGER trigger_log_status_change
AFTER UPDATE ON fulfillment_items
FOR EACH ROW EXECUTE FUNCTION log_status_change();

-- Trigger for updating fulfillment status
CREATE TRIGGER trigger_update_fulfillment_status
BEFORE INSERT OR UPDATE ON fulfillment_items
FOR EACH ROW EXECUTE FUNCTION update_fulfillment_status();

-- Trigger for updating MRL status
CREATE TRIGGER trigger_update_mrl_status
AFTER INSERT OR UPDATE ON fulfillment_items
FOR EACH ROW EXECUTE FUNCTION update_mrl_status();

-- Trigger to log user login activity
CREATE TRIGGER trg_log_user_login
AFTER INSERT ON user_activity
FOR EACH ROW
WHEN (NEW.activity_type = 'login')
EXECUTE PROCEDURE log_user_activity();

-- Trigger to log user logout activity
CREATE TRIGGER trg_log_user_logout
AFTER INSERT ON user_activity
FOR EACH ROW
WHEN (NEW.activity_type = 'logout')
EXECUTE PROCEDURE log_user_activity();

CREATE TRIGGER trg_log_user_login
AFTER INSERT ON user_activity
FOR EACH ROW
EXECUTE FUNCTION log_user_login();

CREATE TRIGGER trg_log_user_logout
AFTER UPDATE ON user_activity
FOR EACH ROW
EXECUTE FUNCTION log_user_logout();

-- Trigger to invoke the archive_line_item function
CREATE OR REPLACE FUNCTION trg_archive_line_item()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM archive_line_item(
        NEW.order_line_item_id,
        NEW.archived_by,
        NEW.archive_reason,
        NEW.role_id,
        NEW.user_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for archiving line items
CREATE TRIGGER trg_archive_line_item
AFTER UPDATE OF archived_by ON MRL_line_items
FOR EACH ROW
WHEN (NEW.archived_by IS NOT NULL)
EXECUTE FUNCTION trg_archive_line_item();


-- Trigger to invoke the archive_fulfillment_item function
CREATE OR REPLACE FUNCTION trg_archive_fulfillment_item()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM archive_fulfillment_item(
        NEW.fulfillment_item_id,
        NEW.archived_by,
        NEW.archive_reason,
        NEW.role_id,
        NEW.user_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for archiving fulfillment items
CREATE TRIGGER trg_archive_fulfillment_item
AFTER UPDATE OF archived_by ON fulfillment_items
FOR EACH ROW
WHEN (NEW.archived_by IS NOT NULL)
EXECUTE FUNCTION trg_archive_fulfillment_item();

-- Create triggers to log changes on relevant tables
CREATE TRIGGER trg_log_all_changes_mrl
AFTER INSERT OR UPDATE OR DELETE ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION log_all_changes();

CREATE TRIGGER trg_log_all_changes_fulfillment
AFTER INSERT OR UPDATE OR DELETE ON fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION log_all_changes();



-- Triggers for the combined function
CREATE TRIGGER trg_combined_status_audit_update
AFTER INSERT OR UPDATE ON fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();

CREATE TRIGGER trg_create_fulfillment_on_mrl_insert
AFTER INSERT ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION combined_status_audit_update();


-- Trigger for MRL_line_items
CREATE TRIGGER trg_audit_mrl_changes
AFTER INSERT OR UPDATE OR DELETE ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION log_all_changes();

-- Trigger for fulfillment_items
CREATE TRIGGER trg_audit_fulfillment_changes
AFTER INSERT OR UPDATE OR DELETE ON fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION log_all_changes();


