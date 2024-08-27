-- version 0.9.41


-- Indexes for performance improvement
CREATE INDEX idx_mrl_line_items_jcn ON MRL_line_items(jcn);
CREATE INDEX idx_mrl_line_items_twcode ON MRL_line_items(twcode);
CREATE INDEX idx_fulfillment_items_order_line_item_id ON fulfillment_items(order_line_item_id);

-- Indexes for commonly queried fields in audit trail
CREATE INDEX idx_audit_trail_order_line_item_id ON audit_trail(order_line_item_id);
CREATE INDEX idx_audit_trail_fulfillment_item_id ON audit_trail(fulfillment_item_id);
CREATE INDEX idx_audit_trail_changed_at ON audit_trail(changed_at);


-- Create indices for efficient querying
CREATE INDEX idx_import_error_log_batch_id ON import_error_log(batch_id);
CREATE INDEX idx_import_error_log_operation_type ON import_error_log(operation_type);
CREATE INDEX idx_import_error_log_jcn ON import_error_log(jcn);
CREATE INDEX idx_import_error_log_twcode ON import_error_log(twcode);
CREATE INDEX idx_import_error_log_order_line_item_id ON import_error_log(order_line_item_id);
CREATE INDEX idx_import_error_log_fulfillment_item_id ON import_error_log(fulfillment_item_id);
CREATE INDEX idx_import_error_log_error_type ON import_error_log(error_type);
CREATE INDEX idx_import_error_log_created_at ON import_error_log(created_at);
CREATE INDEX idx_import_error_log_resolved ON import_error_log(resolved);

-- Create a composite index for common query patterns
CREATE INDEX idx_import_error_log_composite ON import_error_log(batch_id, operation_type, error_type);

-- Create a GIN index for efficient querying of the JSONB data
CREATE INDEX idx_import_error_log_record_data ON import_error_log USING GIN (record_data);
