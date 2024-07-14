-- version 0.5.1


CREATE TABLE audit_trail (
    audit_id SERIAL PRIMARY KEY, -- Unique identifier for the audit record
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE, -- Foreign key to MRL line items
    action VARCHAR(100), -- Description of the action taken
    changed_by VARCHAR(50), -- User who made the change
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the change was made
    details TEXT, -- Detailed description of the change
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    user_id INT REFERENCES users(user_id) -- Foreign key to users table
);


