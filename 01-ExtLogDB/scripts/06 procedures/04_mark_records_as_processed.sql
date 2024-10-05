CREATE OR REPLACE PROCEDURE mark_records_as_processed(
    IN p_staged_ids INT[],
    IN p_user_id INT,
    IN p_role_id INT,
    IN p_update_source TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE staged_egypt_weekly_data
    SET processing_completed = TRUE
    WHERE staged_id = ANY(p_staged_ids);

    -- Insert audit trail entries
    INSERT INTO audit_trail (
        staged_id,
        action,
        changed_by,
        changed_at,
        details,
        update_source,
        role_id,
        user_id
    )
    SELECT
        s.staged_id,
        'Mark as Processed',
        p_user_id,
        NOW(),
        jsonb_build_object(
            'action', 'Marked as processed with no further action',
            'raw_data_id', s.raw_data_id,
            'original_line', s.original_line,
            'report_name', s.report_name,
            'sheet_name', s.sheet_name,
            'report_date', s.report_date
        ),
        p_update_source,
        p_role_id,
        p_user_id
    FROM staged_egypt_weekly_data s
    WHERE s.staged_id = ANY(p_staged_ids);
END;
$$;
