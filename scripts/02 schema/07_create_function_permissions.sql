-- Create Function permissions table

-- version 0.7.14.22


CREATE TABLE function_permissions (
    function_name TEXT PRIMARY KEY,
    min_role_id INT DEFAULT 9  -- Default to role 9 (lowest privilege) if not specified
);


