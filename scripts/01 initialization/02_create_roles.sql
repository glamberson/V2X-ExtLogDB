-- Create roles table and predefined roles
-- version 0.7.9

CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY, -- Unique identifier for the role
    role_name VARCHAR(100), UNIQUE NOT NULL -- Name of the role, must be unique
    db_role_name VARCHAR(100)
);


-- Insert predefined roles
INSERT INTO roles (role_name) VALUES
    ('KPPO Admin', 'kppo_admin_user'),
    ('Chesapeake Warehouse', 'logistics_user'),
    ('NAVSUP', 'logistics_user'),
    ('Logistics Service Center (LSC)', 'logistics_user'),
    ('Report Viewer', 'report_viewer_user');

