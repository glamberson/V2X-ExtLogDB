# config.py

# Application configuration
APP_NAME = "External Logistics Database"
COMPANY_NAME = "FOTS-Egypt"

# Define maximum allowed lengths for each field based on your PostgreSQL schema
FIELD_MAX_LENGTHS = {
    # fulfillment_items table fields
    'shipdoc_tcn': 30,
    'v2x_ship_no': 20,
    'booking': 20,
    'vessel': 30,
    'container': 25,
    'carrier': 50,
    'lot_id': 30,
    'triwall': 30,
    'milstrip_req_no': 25,
    'comments': None,  # TEXT type, no strict limit

    # MRL_line_items table fields (if applicable)
    'jcn': 50,
    'twcode': 50
}
