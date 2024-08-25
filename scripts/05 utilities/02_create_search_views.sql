-- version 0.9.24		Doc

-- Creat Combined line items fulfillments for Search View


CREATE OR REPLACE VIEW combined_line_items_fulfillments_Search_view AS
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
    m.dwg_pc
FROM
    MRL_line_items m
LEFT JOIN
    fulfillment_items f
ON
    m.order_line_item_id = f.order_line_item_id;

