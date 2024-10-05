-- version 0.9.39


CREATE TRIGGER trg_create_fulfillment_on_mrl_insert
AFTER INSERT ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION trigger_create_fulfillment_record();


-- Create the trigger on the fulfillment_items table
CREATE TRIGGER trg_update_fulfillment_and_mrl_status
BEFORE UPDATE ON fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION update_fulfillment_and_mrl_status();

