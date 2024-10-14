-- Procedure for MRL-only bulk accept of staged records
CREATE OR REPLACE PROCEDURE bulk_accept_staged_mrl_only_match(
    IN p_staged_ids INT[],
    IN p_order_line_item_ids INT[],
    IN p_match_scores DECIMAL[],
    IN p_match_grades TEXT[],
    IN p_matched_fields TEXT[],
    IN p_mismatched_fields TEXT[],
    IN p_report_name TEXT,
    IN p_report_date DATE,
    IN p_sheet_name TEXT,
    IN p_user_id INT,
    IN p_role_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_update_source TEXT;
    idx INT;

    -- Variables to hold data from staged_egypt_weekly_data
    v_raw_data_id INT;
    v_system_identifier_code VARCHAR(50);
    v_original_line INT;
BEGIN
    v_update_source := p_report_name || ' | ' || p_report_date::TEXT || ' | ' || p_sheet_name;

    -- Loop through the arrays and insert into potential_matches
    FOR idx IN 1 .. array_length(p_staged_ids, 1) LOOP
        BEGIN
            INSERT INTO potential_matches (
                staged_id,
                order_line_item_id,
                match_score,
                match_grade,
                matched_fields,
                mismatched_fields,
                processed,
                decision,
                created_at,
                updated_at
            ) VALUES (
                p_staged_ids[idx],
                p_order_line_item_ids[idx],
                p_match_scores[idx],
                p_match_grades[idx],
                p_matched_fields[idx]::TEXT[],
                p_mismatched_fields[idx]::TEXT[],
                FALSE,
                'Accepted',
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            );
        EXCEPTION WHEN unique_violation THEN
            -- Handle the unique violation by skipping this record
            RAISE NOTICE 'Unique violation in potential_matches for staged_id %; skipping record.', p_staged_ids[idx];
        END;
    END LOOP;

     -- Loop through the arrays and insert into report_record_links
    FOR idx IN 1 .. array_length(p_staged_ids, 1) LOOP
        BEGIN
            -- Fetch the required fields from staged_egypt_weekly_data
            SELECT s.raw_data_id, s.system_identifier_code, s.original_line
            INTO v_raw_data_id, v_system_identifier_code, v_original_line
            FROM staged_egypt_weekly_data s
            WHERE s.staged_id = p_staged_ids[idx];

            -- Perform the insert into report_record_links
            INSERT INTO report_record_links (
                staged_id,
                order_line_item_id,
                raw_data_id,
                system_identifier_code,
                original_line,
                report_name,
                report_date,
                sheet_name,
                link_type,
                linked_by,
                linked_at,
                update_source
            ) VALUES (
                p_staged_ids[idx],
                p_order_line_item_ids[idx],
                v_raw_data_id,
                v_system_identifier_code,
                v_original_line,
                p_report_name,
                p_report_date,
                p_sheet_name,
                'bulk_staged_mrl_only_match',
                p_user_id,
                CURRENT_TIMESTAMP,
                v_update_source
            );
        EXCEPTION WHEN unique_violation THEN
            -- Handle the unique violation by skipping this record
            RAISE NOTICE 'Unique violation in report_record_links for raw_data_id %, system_identifier_code %; skipping record.', v_raw_data_id, v_system_identifier_code;
        END;
    END LOOP;

    -- Loop through the arrays and insert into audit_trail
    FOR idx IN 1 .. array_length(p_staged_ids, 1) LOOP
        BEGIN
            INSERT INTO audit_trail (
                order_line_item_id,
                action,
                changed_by,
                details,
                update_source,
                role_id,
                user_id,
                changed_at
            ) VALUES (
                p_order_line_item_ids[idx],
                'Bulk Staged MRL Only Match',
                p_user_id,
                'Bulk accepted staged record to MRL match via matching interface',
                v_update_source,
                p_role_id,
                p_user_id,
                CURRENT_TIMESTAMP
            );
        EXCEPTION WHEN unique_violation THEN
            -- Handle the unique violation by skipping this record
            RAISE NOTICE 'Unique violation in audit_trail for order_line_item_id %; skipping record.', p_order_line_item_ids[idx];
        END;
    END LOOP;

    -- Update staged table
    UPDATE staged_egypt_weekly_data
    SET mrl_matched = TRUE
    WHERE staged_id = ANY(p_staged_ids);
END;
$$;
