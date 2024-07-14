-- version 0.5.1



CREATE TABLE user_activity (
    activity_id SERIAL PRIMARY KEY, -- Unique identifier for the activity record
    user_id INT REFERENCES users(user_id) ON DELETE CASCADE, -- Foreign key to users table
    activity_type VARCHAR(50) NOT NULL, -- Type of activity (e.g., 'login', 'logout', 'failed_login')
    activity_time TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the activity occurred
    activity_details TEXT -- Additional details about the activity
);

