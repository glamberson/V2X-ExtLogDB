-- version 0.5.1
-- create users table and initial users with assigned roles


CREATE TABLE users (
    user_id SERIAL PRIMARY KEY, -- Unique identifier for the user
    username VARCHAR(100) UNIQUE NOT NULL, -- Username, must be unique
    password_hash VARCHAR(255) NOT NULL, -- Hashed password for the user
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP -- Timestamp when the user was created
);


-- Insert sample users with hashed passwords and role IDs
INSERT INTO users (username, password_hash, role_id) VALUES
    ('admin', crypt('admin_password', gen_salt('bf')), 1),
    ('chesapeake_user', crypt('chesapeake_password', gen_salt('bf')), 2),
    ('navsup_user', crypt('navsup_password', gen_salt('bf')), 3),
    ('lsc_user', crypt('lsc_password', gen_salt('bf')), 4);


