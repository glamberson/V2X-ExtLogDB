# models/data_models.py

from dataclasses import dataclass
from typing import Optional, List, Dict, Any
from datetime import date, datetime

@dataclass
class StagedRecord:
    staged_id: Optional[int] = None
    preprocessed_id: Optional[int] = None
    raw_data_id: Optional[int] = None

    # Identifier fields
    report_name: Optional[str] = ""
    report_date: Optional[date] = None
    sheet_name: Optional[str] = ""
    original_line: Optional[int] = 0
    system_identifier_code: Optional[str] = ""

    # MRL-related fields
    jcn: Optional[str] = ""
    twcode: Optional[str] = ""
    nomenclature: Optional[str] = ""
    cog: Optional[str] = ""
    fsc: Optional[str] = ""
    niin: Optional[str] = ""
    part_no: Optional[str] = ""
    qty: Optional[int] = 0
    ui: Optional[str] = ""
    market_research_up: Optional[float] = 0.0
    market_research_ep: Optional[float] = 0.0
    availability_identifier: Optional[int] = 0
    request_date: Optional[date] = None
    rdd: Optional[date] = None
    pri: Optional[str] = ""
    swlin: Optional[str] = ""
    hull_or_shop: Optional[str] = ""
    suggested_source: Optional[str] = ""
    mfg_cage: Optional[str] = ""
    apl: Optional[str] = ""
    nha_equipment_system: Optional[str] = ""
    nha_model: Optional[str] = ""
    nha_serial: Optional[str] = ""
    techmanual: Optional[str] = ""
    dwg_pc: Optional[str] = ""
    requestor_remarks: Optional[str] = ""

    # Fulfillment-related fields
    shipdoc_tcn: Optional[str] = ""
    v2x_ship_no: Optional[str] = ""
    booking: Optional[str] = ""
    vessel: Optional[str] = ""
    container: Optional[str] = ""
    carrier: Optional[str] = ""
    sail_date: Optional[date] = None
    edd_to_ches: Optional[date] = None
    edd_egypt: Optional[date] = None
    rcd_v2x_date: Optional[date] = None
    lot_id: Optional[str] = ""
    triwall: Optional[str] = ""
    lsc_on_hand_date: Optional[date] = None
    arr_lsc_egypt: Optional[date] = None
    milstrip_req_no: Optional[str] = ""

    # Additional fields and metadata
    additional_data: Optional[Dict[str, Any]] = None
    overall_quality_score: Optional[float] = 0.0
    flags: Optional[Dict[str, Any]] = None
    data_integrity_score: Optional[float] = 0.0
    consistency_score: Optional[float] = 0.0
    completeness_score: Optional[float] = 0.0
    check_details: Optional[Dict[str, Any]] = None
    mrl_matched: Optional[bool] = False
    fulfillment_matched: Optional[bool] = False
    processing_completed: Optional[bool] = False
    processing_category: Optional[str] = ""
    mapped_fields: Optional[List[str]] = None
    import_timestamp: Optional[datetime] = None

    # User and tracking fields
    created_by: Optional[int] = None
    created_at: Optional[datetime] = None
    updated_by: Optional[int] = None
    updated_at: Optional[datetime] = None
    update_source: Optional[str] = ""
    status_id: Optional[int] = None
    received_quantity: Optional[int] = 0
    inquiry_status: Optional[bool] = False
    has_comments: Optional[bool] = False
    multiple_fulfillments: Optional[bool] = False

@dataclass
class MRLRecord:
    order_line_item_id: Optional[int] = None
    jcn: Optional[str] = ""
    twcode: Optional[str] = ""
    nomenclature: Optional[str] = ""
    cog: Optional[str] = ""
    fsc: Optional[str] = ""
    niin: Optional[str] = ""
    part_no: Optional[str] = ""
    qty: Optional[int] = 0
    ui: Optional[str] = ""
    availability_identifier: Optional[int] = 0
    request_date: Optional[date] = None
    rdd: Optional[date] = None
    pri: Optional[str] = ""
    swlin: Optional[str] = ""
    hull_or_shop: Optional[str] = ""
    suggested_source: Optional[str] = ""
    mfg_cage: Optional[str] = ""
    apl: Optional[str] = ""
    nha_equipment_system: Optional[str] = ""
    nha_model: Optional[str] = ""
    nha_serial: Optional[str] = ""
    techmanual: Optional[str] = ""
    dwg_pc: Optional[str] = ""
    requestor_remarks: Optional[str] = ""
    created_by: Optional[int] = None
    created_at: Optional[datetime] = None
    updated_by: Optional[int] = None
    updated_at: Optional[datetime] = None
    update_source: Optional[str] = ""
    status_id: Optional[int] = None
    received_quantity: Optional[int] = 0
    inquiry_status: Optional[bool] = False
    has_comments: Optional[bool] = False
    multiple_fulfillments: Optional[bool] = False

@dataclass
class FulfillmentRecord:
    created_by: Optional[int] = None
    created_at: Optional[datetime] = None
    updated_by: Optional[int] = None
    updated_at: Optional[datetime] = None
    update_source: Optional[str] = ""
    status_id: Optional[int] = None
    shipdoc_tcn: Optional[str] = ""
    v2x_ship_no: Optional[str] = ""
    booking: Optional[str] = ""
    vessel: Optional[str] = ""
    container: Optional[str] = ""
    carrier: Optional[str] = ""
    sail_date: Optional[date] = None
    edd_to_ches: Optional[date] = None
    edd_egypt: Optional[date] = None  # Estimated Delivery Date to Egypt
    rcd_v2x_date: Optional[date] = None
    lot_id: Optional[str] = ""  # Lot ID
    triwall: Optional[str] = ""  # Triwall number
    lsc_on_hand_date: Optional[date] = None  # LSC on-hand date
    arr_lsc_egypt: Optional[date] = None  # Arrival at LSC Egypt date
    milstrip_req_no: Optional[str] = ""  # Requisition or MILSTRIP number
    comments: Optional[str] = ""  # Comments regarding the fulfillment item
    fulfillment_item_id: Optional[int] = None
    order_line_item_id: Optional[int] = None  # Foreign key to MRL_line_items(order_line_item_id)
    inquiry_status: Optional[bool] = False  # Flag set when review of the fulfillment item is requested

@dataclass
class Match:
    search_record: Optional[StagedRecord] = None
    mrl_record: Optional[MRLRecord] = None
    score: Optional[float] = 0.0
    field_scores: Optional[Dict[str, float]] = None