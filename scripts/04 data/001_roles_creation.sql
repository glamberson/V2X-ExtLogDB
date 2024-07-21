-- version 0.7

-- create roles and grant pemissions




-- Create KPPO Admin role with full access
CREATE ROLE kppo_admin_user WITH LOGIN PASSWORD 'admin_password';
GRANT ALL PRIVILEGES ON DATABASE "Beta_003" TO kppo_admin_user;

-- Create logistics role for Chesapeake Warehouse, NAVSUP, and LSC
CREATE ROLE logistics_user WITH LOGIN PASSWORD 'logistics_password';
GRANT CONNECT ON DATABASE "Beta_003" TO logistics_user;
GRANT USAGE ON SCHEMA public TO logistics_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO logistics_user;
GRANT INSERT, UPDATE ON TABLE fulfillment_items TO logistics_user;
GRANT INSERT, UPDATE ON TABLE line_item_comments TO logistics_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO logistics_user;

-- Create role for Report Viewer with specific permissions
CREATE ROLE report_viewer_user WITH LOGIN PASSWORD 'report_password';
GRANT CONNECT ON DATABASE "Beta_003" TO report_viewer_user;
GRANT USAGE ON SCHEMA public TO report_viewer_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO report_viewer_user;
GRANT INSERT, UPDATE ON TABLE line_item_comments TO report_viewer_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO report_viewer_user;