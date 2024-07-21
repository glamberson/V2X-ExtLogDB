-- Create roles table and predefined roles
-- version 0.7

CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY, -- Unique identifier for the role
    role_name VARCHAR(100) UNIQUE NOT NULL -- Name of the role, must be unique
);


-- Insert predefined roles
INSERT INTO roles (role_name) VALUES
    ('KPPO Admin'),
    ('Chesapeake Warehouse'),
    ('NAVSUP'),
    ('Logistics Service Center (LSC)')
    ('Report Viewer');

