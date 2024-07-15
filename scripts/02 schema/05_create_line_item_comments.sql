-- version 0.6


-- Create comments table (cleanup from previous experiments)


CREATE TABLE line_item_comments (
    comment_id SERIAL PRIMARY KEY, -- Unique identifier for the comment
    order_line_item_id INT REFERENCES MRL_line_items(order_line_item_id) ON DELETE CASCADE, -- Foreign key to MRL line items table
    fulfillment_item_id INT REFERENCES fulfillment_items(fulfillment_item_id) ON DELETE CASCADE, -- Foreign key to fulfillment items table
    comment TEXT, -- The comment text
    commented_by VARCHAR(100), -- Username of the person who made the comment
    commented_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, -- Timestamp when the comment was made
    role_id INT REFERENCES roles(role_id), -- Foreign key to roles table
    user_id INT REFERENCES users(user_id) -- Foreign key to users table
);

