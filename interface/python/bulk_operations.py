# bulk_operations.py

import logging
import pandas as pd
import numpy as np
import math
from datetime import datetime, date
from config import FIELD_MAX_LENGTHS

def clean_data(obj):
    """
    Recursively replace NaN and Infinity with None in the data.
    """
    if isinstance(obj, float):
        if math.isnan(obj) or math.isinf(obj):
            return None
        else:
            return obj
    elif isinstance(obj, dict):
        return {k: clean_data(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [clean_data(elem) for elem in obj]
    else:
        return obj

def validate_and_truncate_data(data_list):
    """
    Validate and truncate fields in the data_list based on FIELD_MAX_LENGTHS.
    Fields exceeding their max length are truncated, and warnings are logged.
    """
    for record in data_list:
        for field, max_length in FIELD_MAX_LENGTHS.items():
            if max_length is None:
                continue  # No truncation needed for this field
            if field in record and isinstance(record[field], str):
                if len(record[field]) > max_length:
                    truncated_value = record[field][:max_length]
                    logging.warning(
                        f"Field '{field}' exceeded max length of {max_length}. "
                        f"Truncated from {len(record[field])} to {len(truncated_value)} characters."
                    )
                    record[field] = truncated_value
    return data_list

def prepare_mrl_data(data_frame):
    # Clean up column names
    data_frame.columns = (
        data_frame.columns
        .astype(str)
        .str.strip()
        .str.lower()
        .str.replace(r'[^0-9a-zA-Z_]', '_', regex=True)
        .str.replace(r'__+', '_', regex=True)
    )
    logging.debug("Column names cleaned and standardized.")

    # Handle date fields
    date_columns = ['request_date', 'rdd']
    for col in date_columns:
        if col in data_frame.columns:
            data_frame[col] = pd.to_datetime(
                data_frame[col],
                errors='coerce'
            ).dt.date  # Extract date component
            logging.debug(f"Date field '{col}' processed.")

    # Convert numeric columns to appropriate data types
    numeric_columns = ['fsc', 'niin', 'qty', 'market_research_up', 'market_research_ep', 'availability_identifier']
    for col in numeric_columns:
        if col in data_frame.columns:
            data_frame[col] = pd.to_numeric(data_frame[col], errors='coerce')
            logging.debug(f"Numeric field '{col}' converted.")

    # Replace NaN and Infinity with None
    data_frame = data_frame.replace([np.inf, -np.inf, np.nan], None)
    logging.debug("Replaced NaN and Infinity with None.")

    # Convert DataFrame to list of dictionaries
    data = data_frame.to_dict(orient='records')
    logging.debug("DataFrame converted to list of dictionaries.")

    # Clean the data recursively
    data = clean_data(data)
    logging.debug("Data cleaned to remove NaN and Infinity values.")

    # Validate and truncate data
    data = validate_and_truncate_data(data)
    logging.debug("Data validated and truncated based on field length constraints.")

    return data

def prepare_fulfillment_data(data_frame):
    # Clean up column names
    data_frame.columns = (
        data_frame.columns
        .astype(str)
        .str.strip()
        .str.lower()
        .str.replace(r'[^0-9a-zA-Z_]', '_', regex=True)
        .str.replace(r'__+', '_', regex=True)
    )
    logging.debug("Column names cleaned and standardized.")

    # Handle date fields
    date_columns = [
        'sail_date', 'edd_to_ches', 'edd_egypt', 'rcd_v2x_date',
        'lsc_on_hand_date', 'arr_lsc_egypt'
    ]
    for col in date_columns:
        if col in data_frame.columns:
            data_frame[col] = pd.to_datetime(
                data_frame[col],
                errors='coerce'
            ).dt.date  # Extract date component
            logging.debug(f"Date field '{col}' processed.")

    # Replace NaN and Infinity with None
    data_frame = data_frame.replace([np.inf, -np.inf, np.nan], None)
    logging.debug("Replaced NaN and Infinity with None.")

    # Convert DataFrame to list of dictionaries
    data = data_frame.to_dict(orient='records')
    logging.debug("DataFrame converted to list of dictionaries.")

    # Clean the data recursively
    data = clean_data(data)
    logging.debug("Data cleaned to remove NaN and Infinity values.")

    # Validate and truncate data
    data = validate_and_truncate_data(data)
    logging.debug("Data validated and truncated based on field length constraints.")

    return data
