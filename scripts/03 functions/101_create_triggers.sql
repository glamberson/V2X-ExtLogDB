-- version 0.5.1



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




