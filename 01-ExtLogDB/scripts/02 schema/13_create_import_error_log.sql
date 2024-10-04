-- version 0.9.41
-- create import error log table


-- Create the import_error_log table
CREATE TABLE import_error_log (
    error_id SERIAL PRIMARY KEY,
    batch_id UUID NOT NULL,
    operation_type TEXT NOT NULL CHECK (operation_type IN ('MRL_INSERT', 'FULFILLMENT_UPDATE')),
    source_file_line_number INT,
    jcn TEXT,
    twcode TEXT,
    order_line_item_id INT,
    fulfillment_item_id INT,
    error_type TEXT NOT NULL CHECK (error_type IN ('ERROR', 'WARNING')),
    error_message TEXT,
    record_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by INT REFERENCES users(user_id)
);
-- Add a comment to the table for documentation
COMMENT ON TABLE import_error_log IS 'Stores detailed error and warning information for MRL and fulfillment import operations';