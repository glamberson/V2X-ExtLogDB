-- version 0.6


-- Create inquiry status table (cleanup and added fulfillment reference)

CREATE TABLE line_item_inquiry (
    inquiry_id SERIAL PRIMARY KEY, -- Unique identifier for the inquiry
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE, -- Foreign key to MRL line items table
    fulfillment_item_id INT REFERENCES fulfillment_items(fulfillment_item_id) ON DELETE CASCADE, -- Foreign key to fulfillment items table
    inquiry_status BOOLEAN, -- Inquiry status
    updated_by VARCHAR(100), -- Username of the person who updated the inquiry status
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the inquiry status was updated
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    user_id INT REFERENCES users(user_id) -- Foreign key to users table
);

