import pandas as pd
import openpyxl
import glob
import logging
from pyxlsb import open_workbook
from datetime import datetime
import os

# Configure logging
logging.basicConfig(filename='process_excel.log', level=logging.INFO)

def log_info(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    logging.info(f"{timestamp} - {message}")
    print(f"{timestamp} - {message}")

# Function to detect SWLIN headers and assign SWLIN to valid data rows for .xlsx files
def detect_and_assign_swlin_xlsx(file_path, sheet_name):
    wb = openpyxl.load_workbook(file_path, data_only=True)
    ws = wb[sheet_name]
    
    valid_rows = []
    current_swlin = None
    header_row = True  # Keep track of header row (first row)

    for row in ws.iter_rows(min_row=1, values_only=False):  # We need the full row to access style
        row_data = [cell.value for cell in row]
        
        # Skip the header row
        if header_row:
            valid_rows.append(row_data)
            header_row = False
            continue
        
        # Detect SWLIN headers: rows with JCN but no twcode
        jcn_value = row_data[0]  # Assuming JCN is the first column
        twcode_value = row_data[4]  # Assuming twcode is in the 5th column (adjust if needed)

        if jcn_value and not twcode_value:
            # This is a SWLIN header row, use the JCN as SWLIN identifier
            current_swlin = jcn_value
            continue  # Don't include SWLIN header rows in data

        # For valid data rows, assign the current SWLIN
        if twcode_value:
            row_data.append(current_swlin)  # Add SWLIN to the end of the row
            valid_rows.append(row_data)
    
    return valid_rows

# Function to handle .xlsb files using pyxlsb and detect SWLIN headers
def detect_and_assign_swlin_xlsb(file_path, sheet_name):
    valid_rows = []
    current_swlin = None

    with open_workbook(file_path) as wb:
        with wb.get_sheet(sheet_name) as sheet:
            for row in sheet.rows():
                row_data = [item.v for item in row]  # Extract cell values
                jcn_value = row_data[0]  # Assuming JCN is the first column
                twcode_value = row_data[4]  # Assuming twcode is in the 5th column

                if jcn_value and not twcode_value:
                    # This is a SWLIN header row, use the JCN as SWLIN identifier
                    current_swlin = jcn_value
                    continue  # Don't include SWLIN header rows in data

                # For valid data rows, assign the current SWLIN
                if twcode_value:
                    row_data.append(current_swlin)  # Add SWLIN to the end of the row
                    valid_rows.append(row_data)

    return valid_rows

# Function to prompt user for availability_identifier
def get_availability_identifier(sheet_name):
    return input(f"Enter availability_identifier for sheet '{sheet_name}': ")

# Function to convert Excel date format to PostgreSQL-friendly date format (YYYY-MM-DD)
def convert_excel_date(excel_date):
    if pd.isna(excel_date):
        return None
    return pd.to_datetime('1899-12-30') + pd.to_timedelta(excel_date, 'D')

def truncate_part_no_field(sheet, max_length=50):
    if 'part_no' in sheet.columns:
        sheet['part_no'] = sheet['part_no'].apply(lambda x: x[:max_length] if isinstance(x, str) else x)
    return sheet

def process_sheet_with_swlin_extraction(file_path, sheet_name):
    log_info(f"Processing sheet '{sheet_name}'")

    # Detect file format
    file_extension = os.path.splitext(file_path)[1].lower()

    # Detect and assign SWLIN for .xlsx or .xlsb
    if file_extension == '.xlsx':
        valid_rows = detect_and_assign_swlin_xlsx(file_path, sheet_name)
    elif file_extension == '.xlsb':
        valid_rows = detect_and_assign_swlin_xlsb(file_path, sheet_name)
    else:
        raise ValueError(f"Unsupported file format: {file_extension}")
    
    # Handle the case where a sheet might be empty or just a junk sheet
    if not valid_rows or len(valid_rows) < 2:
        log_info(f"Skipping empty or invalid sheet '{sheet_name}'")
        return  # Skip this sheet if no valid data rows exist

    # Create a DataFrame from the valid rows
    header_row = valid_rows[0]
    header_row.append('swlin')  # Add the SWLIN column to the header row
    
    # Check if all rows have the same length
    for row in valid_rows[1:]:
        if len(row) == len(header_row) - 1:  # If SWLIN was added, rows should have one less column
            row.append(None)  # Add a placeholder if SWLIN was not present in this row

    sheet = pd.DataFrame(valid_rows[1:], columns=header_row)  # Use the modified header

    # Normalize column names
    sheet.columns = sheet.columns.str.strip().str.lower().str.replace(' ', '_')

    # MRL Line Items Mapping
    mrl_line_item_mapping = {
        'jcn': 'jcn',
        'tw_code': 'twcode',
        'nomen': 'nomenclature',
        'niin': 'niin',
        'part_no': 'part_no',
        'qty': 'qty',
        'ui': 'ui',
        'pri': 'pri',
        'lsc_dt': 'request_date',
        'swlin': 'swlin'
    }

    # Filter columns for MRL line items
    available_columns = [col for col in mrl_line_item_mapping.keys() if col in sheet.columns]
    mrl_line_items = sheet[available_columns].rename(columns={col: mrl_line_item_mapping[col] for col in available_columns})

    # Truncate part_no to 50 characters
    mrl_line_items = truncate_part_no_field(mrl_line_items, max_length=50)

    # Convert qty to integer and handle NaN cases
    if 'qty' in mrl_line_items.columns:
        mrl_line_items['qty'] = mrl_line_items['qty'].fillna(0).astype(int)

    # Convert request_date and other date fields to PostgreSQL-friendly format
    if 'request_date' in mrl_line_items.columns:
        mrl_line_items['request_date'] = mrl_line_items['request_date'].apply(convert_excel_date)

    # Prompt user for availability_identifier
    availability_identifier = get_availability_identifier(sheet_name)
    mrl_line_items['availability_identifier'] = availability_identifier

    # Fulfillment Mapping
    fulfillment_mapping = {
        'shipdoc_v2x': 'shipdoc_tcn',
        'v2x_ship_no': 'v2x_ship_no',
        'booking_no': 'booking',
        'vessel': 'vessel',
        'container': 'container',
        'sail_date': 'sail_date',
        'edd_to_egy': 'edd_egypt',
        'rcd_v2x_date': 'rcd_v2x_date'
    }

    # Filter columns for Fulfillment records
    available_columns_fulfillment = [col for col in fulfillment_mapping.keys() if col in sheet.columns]
    fulfillment_records = sheet[available_columns_fulfillment].rename(columns={col: fulfillment_mapping[col] for col in available_columns_fulfillment})

    # Convert date fields for fulfillment records
    if 'sail_date' in fulfillment_records.columns:
        fulfillment_records['sail_date'] = fulfillment_records['sail_date'].apply(convert_excel_date)

    # Add JCN and TWCODE as linking fields in the fulfillment records
    if 'jcn' in mrl_line_items.columns:
        fulfillment_records['jcn'] = mrl_line_items['jcn']
    if 'twcode' in mrl_line_items.columns:
        fulfillment_records['twcode'] = mrl_line_items['twcode']

    # Save the processed data to Excel files
    mrl_line_items.to_excel(f"{sheet_name}_MRL_line_items.xlsx", index=False)
    fulfillment_records.to_excel(f"{sheet_name}_fulfillment_items.xlsx", index=False)

    log_info(f"Processed and saved MRL and Fulfillment records for sheet '{sheet_name}'")

# Updated excel file processing function
def process_excel_file_with_swlin_extraction(file_path):
    log_info(f"Starting processing of file: {file_path}")
    xls = pd.ExcelFile(file_path)
    for sheet_name in xls.sheet_names:
        if sheet_name.lower() != 'summary report':  # Skip summary sheets
            process_sheet_with_swlin_extraction(file_path, sheet_name)
    log_info(f"Completed processing of file: {file_path}")

# File handling: Process all Excel files in the current directory
excel_files = glob.glob("*.xls*")

for file in excel_files:
    process_excel_file_with_swlin_extraction(file)

log_info("All files processed.")
