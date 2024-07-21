-- version 0.7


CREATE OR REPLACE VIEW availability_events_view AS
SELECT 
    ae.availability_event_id,
    ae.availability_name,
    ae.start_date,
    ae.end_date,
    ae.description,
    ae.created_at,
    u.username AS created_by
FROM 
    availability_events ae
JOIN 
    users u ON ae.created_by = u.user_id;


CREATE OR REPLACE VIEW line_item_inquiry_view AS
SELECT 
    li.inquiry_id,
    li.order_line_item_id,
    m.jcn,
    m.twcode,
    li.inquiry_status,
    li.updated_by,
    li.updated_at,
    r.role_name
FROM 
    line_item_inquiry li
JOIN 
    MRL_line_items m ON li.order_line_item_id = m.order_line_item_id
JOIN 
    roles r ON li.role_id = r.role_id;


CREATE OR REPLACE VIEW inquiry_status_items_view AS
SELECT 
    m.order_line_item_id,
    m.jcn,
    m.twcode,
    m.nomenclature,
    m.cog,
    m.fsc,
    m.niin,
    m.part_no,
    m.qty,
    m.ui,
    m.market_research_up,
    m.market_research_ep,
    m.availability_identifier, -- Updated field name
    m.request_date,
    m.rdd,
    m.pri,
    m.swlin,
    m.hull_or_shop,
    m.suggested_source,
    m.mfg_cage,
    m.apl,
    m.nha_equipment_system,
    m.nha_model,
    m.nha_serial,
    m.techmanual,
    m.dwg_pc,
    m.requestor_remarks,
    m.inquiry_status,
    m.created_by,
    m.created_at,
    m.status_id,
    m.received_quantity,
    m.has_comments,
    m.multiple_fulfillments, -- Updated field name
    li.inquiry_status AS current_inquiry_status,
    li.updated_by AS inquiry_updated_by,
    li.updated_at AS inquiry_updated_at
FROM 
    MRL_line_items m
JOIN 
    line_item_inquiry li ON m.order_line_item_id = li.order_line_item_id
WHERE 
    li.inquiry_status = TRUE
ORDER BY 
    li.updated_at DESC;


-- View to show all line items with their current status
CREATE OR REPLACE VIEW line_items_with_status_view AS
SELECT 
    l.order_line_item_id,
    l.jcn,
    l.twcode,
    l.nomenclature,
    l.cog,
    l.fsc,
    l.niin,
    l.part_no,
    l.qty,
    l.ui,
    l.market_research_up,
    l.market_research_ep,
    l.availability_identifier,
    l.request_date,
    l.rdd,
    l.pri,
    l.swlin,
    l.hull_or_shop,
    l.suggested_source,
    l.mfg_cage,
    l.apl,
    l.nha_equipment_system,
    l.nha_model,
    l.nha_serial,
    l.techmanual,
    l.dwg_pc,
    l.requestor_remarks,
    l.inquiry_status,
    l.created_by,
    l.created_at,
    s.status_name AS current_status,
    l.received_quantity,
    l.has_comments,
    l.multiple_fulfillments
FROM MRL_line_items l
JOIN statuses s ON l.status_id = s.status_id;

-- View to show all fulfillment items with their current status
CREATE OR REPLACE VIEW fulfillment_items_with_status_view AS
SELECT 
    f.fulfillment_item_id,
    f.order_line_item_id,
    f.created_at,
    f.updated_at,
    f.milstrip_req_no,
    f.edd_to_ches,
    f.rcd_v2x_date,
    f.lot_id,
    f.triwall,
    f.shipdoc_tcn,
    f.v2x_ship_no,
    f.booking,
    f.vessel,
    f.container,
    f.sail_date,
    f.edd_to_egypt,
    f.arr_lsc_egypt,
    f.lsc_on_hand_date,
    f.carrier,
    s.status_name AS current_status,
    f.created_by,
    f.updated_by,
    f.update_source,
    f.has_comments,
    f.inquiry_status
FROM fulfillment_items f
JOIN statuses s ON f.status_id = s.status_id;

CREATE OR REPLACE VIEW combined_line_items_fulfillments_view AS
SELECT
    m.order_line_item_id,
    m.jcn,
    m.twcode,
    m.nomenclature,
    m.cog,
    m.fsc,
    m.niin,
    m.part_no,
    m.qty,
    m.ui,
    m.market_research_up,
    m.market_research_ep,
    m.availability_identifier,
    m.request_date,
    m.rdd,
    m.pri,
    m.swlin,
    m.hull_or_shop,
    m.suggested_source,
    m.mfg_cage,
    m.apl,
    m.nha_equipment_system,
    m.nha_model,
    m.nha_serial,
    m.techmanual,
    m.dwg_pc,
    m.requestor_remarks,
    m.inquiry_status,
    m.created_by AS mrl_created_by,
    m.created_at AS mrl_created_at,
    m.updated_by AS mrl_updated_by,
    m.updated_at AS mrl_updated_at,
    m.update_source AS mrl_update_source,
    m.status_id AS mrl_status_id,
    m.received_quantity,
    m.has_comments,
    m.multiple_fulfillments,
    f.fulfillment_item_id,
    f.created_by AS fulfillment_created_by,
    f.created_at AS fulfillment_created_at,
    f.updated_by AS fulfillment_updated_by,
    f.updated_at AS fulfillment_updated_at,
    f.update_source AS fulfillment_update_source,
    f.status_id AS fulfillment_status_id,
    f.shipdoc_tcn,
    f.v2x_ship_no,
    f.booking,
    f.vessel,
    f.container,
    f.sail_date,
    f.edd_to_ches,
    f.rcd_v2x_date,
    f.lot_id,
    f.triwall,
    f.lsc_on_hand_date,
    f.arr_lsc_egypt,
    f.milstrip_req_no,
    f.inquiry_status AS fulfillment_inquiry_status,
    f.comments AS fulfillment_comments
FROM
    MRL_line_items m
LEFT JOIN
    fulfillment_items f
ON
    m.order_line_item_id = f.order_line_item_id;


