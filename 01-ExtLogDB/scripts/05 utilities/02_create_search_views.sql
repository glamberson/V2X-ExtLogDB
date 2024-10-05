CREATE OR REPLACE VIEW combined_line_items_fulfillments_search_view AS
SELECT
    m.order_line_item_id,
    f.fulfillment_item_id,
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
    ae.availability_name AS availability_event,
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
    r.system_identifier_code
FROM
    MRL_line_items m
LEFT JOIN
    fulfillment_items f
    ON m.order_line_item_id = f.order_line_item_id
LEFT JOIN
    availability_events ae
    ON m.availability_identifier = ae.availability_identifier
LEFT JOIN
    report_record_links rr
    ON m.order_line_item_id = rr.order_line_item_id
LEFT JOIN
    staged_egypt_weekly_data r
    ON rr.staged_id = r.staged_id;
