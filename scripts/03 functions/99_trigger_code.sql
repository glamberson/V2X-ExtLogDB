-- version 0.8.31


CREATE TRIGGER trg_create_fulfillment_on_mrl_insert
AFTER INSERT ON MRL_line_items
FOR EACH ROW
EXECUTE FUNCTION trigger_create_fulfillment_record();


