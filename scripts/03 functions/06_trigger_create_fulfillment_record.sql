-- version 0.8.10

CREATE OR REPLACE FUNCTION trigger_create_fulfillment_record()
RETURNS TRIGGER AS $$
BEGIN
    -- Here you can add any additional logic, error handling, or checks specific to the trigger
    IF NEW.order_line_item_id IS NULL THEN
        RAISE EXCEPTION 'Cannot create fulfillment record: order_line_item_id is NULL';
    END IF;

    PERFORM create_fulfillment_record(
        NEW.order_line_item_id, 
        NEW.created_by, 
        COALESCE(NEW.update_source, 'Initial MRL creation')
    );

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error and re-raise
        RAISE NOTICE 'Error in trigger_create_fulfillment_record: %', SQLERRM;
        RAISE;
END;
$$ LANGUAGE plpgsql;

