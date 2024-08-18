-- version 0.9

CREATE OR REPLACE PROCEDURE insert_fulfillment_items(
    IN json_data JSONB,
    IN update_source TEXT,
    OUT summary TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    -- Declare necessary variables
    record JSONB;
    record_summary TEXT;
    error_log TEXT DEFAULT '';
    total_count INT DEFAULT 0;
    success_count INT DEFAULT 0;
    duplicate_count INT DEFAULT 0;
    error_count INT DEFAULT 0;
    fulfillment_item_id INT;
BEGIN
    -- Start processing the JSON data
    FOR record IN SELECT * FROM jsonb_array_elements(json_data)
    LOOP
        BEGIN
            -- Validate the record
            -- (Implement specific validation logic as needed)
            IF record->>'order_line_item_id' IS NULL THEN
                RAISE EXCEPTION 'Missing order_line_item_id in record: %', record;
            END IF;
            
            -- Process the record (e.g., insert or update fulfillment items)
            -- Check if the fulfillment item already exists
            SELECT fulfillment_item_id INTO fulfillment_item_id
            FROM fulfillment_items
            WHERE order_line_item_id = (record->>'order_line_item_id')::INT
              AND (record->>'status_id')::INT = status_id;

            IF NOT FOUND THEN
                -- Insert new fulfillment item
                INSERT INTO fulfillment_items (
                    order_line_item_id,
                    status_id,
                    edd_to_ches,
                    carrier,
                    has_comments,
                    status_value
                )
                VALUES (
                    (record->>'order_line_item_id')::INT,
                    (record->>'status_id')::INT,
                    (record->>'edd_to_ches')::DATE,
                    record->>'carrier',
                    (record->>'has_comments')::BOOLEAN,
                    (record->>'status_value')::INT
                );
                success_count := success_count + 1;
            ELSE
                -- Handle duplicate
                duplicate_count := duplicate_count + 1;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                -- Handle any errors and log them
                error_log := error_log || 'Error processing record: ' || SQLERRM || E'\n';
                error_count := error_count + 1;
        END;
        total_count := total_count + 1;
    END LOOP;

    -- Prepare the summary output
    summary := 'Total: ' || total_count || ', Success: ' || success_count || 
               ', Duplicates: ' || duplicate_count || ', Errors: ' || error_count;

END;
$$;

