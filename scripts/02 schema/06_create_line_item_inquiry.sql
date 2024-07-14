-- version 0.5.1



CREATE TABLE line_item_inquiry (
    inquiry_id SERIAL PRIMARY KEY, -- Unique identifier for the inquiry record
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE, -- Foreign key to MRL line items
    inquiry_status BOOLEAN, -- Status of the inquiry (e.g., TRUE for active inquiry, FALSE for resolved)
    updated_by VARCHAR(50), -- User who updated the inquiry status
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the inquiry status was updated
    role_id INT REFERENCES roles(role_id) -- Foreign key to roles table
);

