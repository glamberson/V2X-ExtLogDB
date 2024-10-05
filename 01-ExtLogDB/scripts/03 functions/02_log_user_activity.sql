-- version 0.7.6.2


CREATE OR REPLACE FUNCTION log_user_activity(
    p_user_id INT,
    p_login_time TIMESTAMPTZ,
    p_logout_time TIMESTAMPTZ,
    p_activity_details TEXT
)
RETURNS VOID AS $$
DECLARE
    v_activity_id INT;
BEGIN
    IF p_login_time IS NOT NULL THEN
        -- This is a login activity, insert a new record
        INSERT INTO user_activity (
            user_id,
            login_time,
            logout_time,
            activity_details
        )
        VALUES (
            p_user_id,
            p_login_time,
            p_logout_time,
            p_activity_details
        );
    ELSE
        -- This is a logout activity, update the existing record
        -- First, find the most recent login without a logout
        SELECT activity_id INTO v_activity_id
        FROM user_activity
        WHERE user_id = p_user_id
          AND logout_time IS NULL
        ORDER BY login_time DESC
        LIMIT 1;

        IF FOUND THEN
            -- Update the found record
            UPDATE user_activity
            SET logout_time = p_logout_time,
                activity_details = COALESCE(activity_details, '') || '; ' || p_activity_details
            WHERE activity_id = v_activity_id;
        ELSE
            -- If no record was found, insert a new record
            INSERT INTO user_activity (
                user_id,
                login_time,
                logout_time,
                activity_details
            )
            VALUES (
                p_user_id,
                CURRENT_TIMESTAMP, -- Assume login time is now as a fallback
                p_logout_time,
                'Logout without matching login; ' || p_activity_details
            );
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;