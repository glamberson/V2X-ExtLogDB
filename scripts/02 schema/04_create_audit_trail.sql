-- version 0.7


-- Create audit_trail table (added fields)


CREATE TABLE audit_trail (
    audit_id SERIAL PRIMARY KEY, -- Unique identifier for the audit trail entry
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE, -- Foreign key to MRL line items table
    fulfillment_item_id INT REFERENCES fulfillment_items(fulfillment_item_id) ON DELETE CASCADE, -- Foreign key to fulfillment items table
    action VARCHAR(100), -- Action performed (e.g., 'Status Updated')
    changed_by VARCHAR(100), -- Username of the person who performed the action
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the action was performed
    details TEXT, -- Details of the action performed
    update_source TEXT, -- Source of the update
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    user_id INT REFERENCES users(user_id) -- Foreign key to users table
);


