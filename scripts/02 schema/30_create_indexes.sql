-- version 0.5.1


-- Indexes for performance improvement
CREATE INDEX idx_mrl_line_items_jcn ON MRL_line_items(jcn);
CREATE INDEX idx_mrl_line_items_twcode ON MRL_line_items(twcode);
CREATE INDEX idx_fulfillment_items_order_line_item_id ON fulfillment_items(order_line_item_id);

-- Indexes for commonly queried fields in audit trail
CREATE INDEX idx_audit_trail_order_line_item_id ON audit_trail(order_line_item_id);
CREATE INDEX idx_audit_trail_fulfillment_item_id ON audit_trail(fulfillment_item_id);
CREATE INDEX idx_audit_trail_changed_at ON audit_trail(changed_at);


