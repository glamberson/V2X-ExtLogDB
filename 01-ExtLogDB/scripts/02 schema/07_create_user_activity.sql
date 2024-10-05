-- version 0.6


-- Create user activity table (unifying log activity with one record)

CREATE TABLE user_activity (
    activity_id SERIAL PRIMARY KEY, -- Unique identifier for the activity
    user_id INT REFERENCES users(user_id), -- Foreign key to users table
    login_time TIMESTAMPTZ, -- Timestamp of the login
    logout_time TIMESTAMPTZ, -- Timestamp of the logout
    activity_details TEXT -- Details of the activity performed
);


