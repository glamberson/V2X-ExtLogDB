# models/data_models.py

from dataclasses import dataclass
from typing import Optional, List, Dict, Any
from datetime import date, datetime

@dataclass
class StagedRecord:
    # IDs and identifiers
    staged_id: Optional[int] = None
    preprocessed_id: Optional[int] = None
    raw_data_id: Optional[int] = None

    # Identifier fields
    report_name: Optional[str] = None
    report_date: Optional[date] = None
    sheet_name: Optional[str] = None
    original_line: Optional[int] = None
    system_identifier_code: Optional[str] = None

    # MRL-related fields
    jcn: Optional[str] = None
    twcode: Optional[str] = None
    nomenclature: Optional[str] = None
    cog: Optional[str] = None
    fsc: Optional[str] = None
    niin: Optional[str] = None
    part_no: Optional[str] = None
    qty: Optional[int] = None
    ui: Optional[str] = None
    market_research_up: Optional[float] = None
    market_research_ep: Optional[float] = None
    availability_identifier: Optional[int] = None
    request_date: Optional[date] = None
    rdd: Optional[date] = None
    pri: Optional[str] = None
    swlin: Optional[str] = None
    hull_or_shop: Optional[str] = None
    suggested_source: Optional[str] = None
    mfg_cage: Optional[str] = None
    apl: Optional[str] = None
    nha_equipment_system: Optional[str] = None
    nha_model: Optional[str] = None
    nha_serial: Optional[str] = None
    techmanual: Optional[str] = None
    dwg_pc: Optional[str] = None
    requestor_remarks: Optional[str] = None

    # Fulfillment-related fields
    shipdoc_tcn: Optional[str] = None
    v2x_ship_no: Optional[str] = None
    booking: Optional[str] = None
    vessel: Optional[str] = None
    container: Optional[str] = None
    carrier: Optional[str] = None
    sail_date: Optional[date] = None
    edd_to_ches: Optional[date] = None
    edd_egypt: Optional[date] = None
    rcd_v2x_date: Optional[date] = None
    lot_id: Optional[str] = None
    triwall: Optional[str] = None
    lsc_on_hand_date: Optional[date] = None
    arr_lsc_egypt: Optional[date] = None
    milstrip_req_no: Optional[str] = None

    # Additional fields and metadata
    additional_data: Optional[Dict[str, Any]] = None
    overall_quality_score: Optional[float] = None
    flags: Optional[Dict[str, Any]] = None
    data_integrity_score: Optional[float] = None
    consistency_score: Optional[float] = None
    completeness_score: Optional[float] = None
    check_details: Optional[Dict[str, Any]] = None
    mrl_matched: Optional[bool] = None
    fulfillment_matched: Optional[bool] = None
    processing_completed: Optional[bool] = None
    processing_category: Optional[str] = None
    mapped_fields: Optional[List[str]] = None
    import_timestamp: Optional[datetime] = None

@dataclass
class MRLRecord:
    # Fields from MRL_line_items
    order_line_item_id: Optional[int] = None
    jcn: Optional[str] = None
    twcode: Optional[str] = None
    nomenclature: Optional[str] = None
    cog: Optional[str] = None
    fsc: Optional[str] = None
    niin: Optional[str] = None
    part_no: Optional[str] = None
    qty: Optional[int] = None
    ui: Optional[str] = None
    market_research_up: Optional[float] = None
    market_research_ep: Optional[float] = None
    availability_identifier: Optional[int] = None
    request_date: Optional[date] = None
    rdd: Optional[date] = None
    pri: Optional[str] = None
    swlin: Optional[str] = None
    hull_or_shop: Optional[str] = None
    suggested_source: Optional[str] = None
    mfg_cage: Optional[str] = None
    apl: Optional[str] = None
    nha_equipment_system: Optional[str] = None
    nha_model: Optional[str] = None
    nha_serial: Optional[str] = None
    techmanual: Optional[str] = None
    dwg_pc: Optional[str] = None
    requestor_remarks: Optional[str] = None

    # Additional fields
    received_quantity: Optional[int] = None
    inquiry_status: Optional[bool] = None
    has_comments: Optional[bool] = None
    multiple_fulfillments: Optional[bool] = None
    fulfillment_item_id: Optional[int] = None # Needed to initially pair staged records with fulfillments. Used when there is only one. 
    # Exclude metadata fields like created_by, created_at, updated_by, updated_at, update_source, status_id

@dataclass
class Match:
    search_record: Optional[StagedRecord] = None
    mrl_record: Optional[MRLRecord] = None
    score: Optional[float] = 0.0
    field_scores: Optional[Dict[str, float]] = None
