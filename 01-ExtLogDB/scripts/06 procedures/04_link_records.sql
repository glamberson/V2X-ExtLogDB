CREATE OR REPLACE PROCEDURE link_records(
    IN p_staged_ids INT[],
    IN p_user_id INT,
    IN p_role_id INT,
    IN p_update_source TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Temporary table to hold processing data
    CREATE TEMP TABLE temp_processing_data AS
    SELECT s.*
    FROM staged_egypt_weekly_data s
    WHERE s.staged_id = ANY(p_staged_ids);

    -- Link records
    WITH records_to_link AS (
        SELECT
            t.staged_id,
            t.raw_data_id,
            t.system_identifier_code,
            t.jcn,
            t.twcode,
            fi.fulfillment_item_id,
            fi.order_line_item_id
        FROM temp_processing_data t
        JOIN MRL_line_items mli ON LOWER(TRIM(mli.jcn)) = LOWER(TRIM(t.jcn)) AND LOWER(TRIM(mli.twcode)) = LOWER(TRIM(t.twcode))
        JOIN fulfillment_items fi ON fi.order_line_item_id = mli.order_line_item_id
    )
    INSERT INTO record_links (
        staged_id,
        fulfillment_item_id,
        raw_data_id,
        system_identifier_code,
        created_at,
        notes
    )
    SELECT 
        r.staged_id,
        r.fulfillment_item_id,
        r.raw_data_id,
        r.system_identifier_code,
        NOW(),
        'Linked via link_records procedure'
    FROM records_to_link r;

    -- Mark staged records as processed
    UPDATE staged_egypt_weekly_data
    SET processing_completed = TRUE
    WHERE staged_id = ANY(p_staged_ids);

    -- Insert audit trail entries
    INSERT INTO audit_trail (
        staged_id,
        fulfillment_item_id,
        action,
        changed_by,
        changed_at,
        details,
        update_source,
        role_id,
        user_id
    )
    SELECT
        r.staged_id,
        r.fulfillment_item_id,
        'Link Records',
        p_user_id,
        NOW(),
        jsonb_build_object(
            'action', 'Linked staged record to fulfillment_item via jcn and twcode',
            'raw_data_id', r.raw_data_id,
            'system_identifier_code', r.system_identifier_code,
            'jcn', r.jcn,
            'twcode', r.twcode,
            'original_line', s.original_line,
            'report_name', s.report_name,
            'sheet_name', s.sheet_name,
            'report_date', s.report_date
        ),
        p_update_source,
        p_role_id,
        p_user_id
    FROM records_to_link r
    JOIN staged_egypt_weekly_data s ON s.staged_id = r.staged_id;
END;
$$;
