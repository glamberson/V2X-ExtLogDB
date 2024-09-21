import psycopg2
import json
import traceback
from psycopg2 import sql
from datetime import datetime
import logging
import pandas as pd
import numpy as np

# Set up logging
logging.basicConfig(
    filename='preprocessing.log', 
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def remove_nat_nan(value):
    if pd.isna(value) or value is None:
        return None
    if isinstance(value, str) and value.lower() in ['nat', 'nan']:
        return None
    if isinstance(value, (np.integer, np.floating)):
        return value.item()
    return value

def safe_string(value, max_length=None):
    if value is None:
        return None
    result = str(value)
    if max_length:
        return result[:max_length]
    return result

def safe_int(value):
    try:
        return int(float(value))
    except (ValueError, TypeError):
        return None

def safe_float(value):
    try:
        return float(value)
    except (ValueError, TypeError):
        return None

def flexible_date_parse(date_value):
    if pd.isna(date_value) or date_value == 'NaT' or date_value is None:
        return None
    try:
        return pd.to_datetime(date_value).date()
    except Exception as e:
        logging.error(f"Date parsing error: {e}, value: {date_value}")
        return None

def get_field_mappings(conn, raw_data_id):
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT raw_field_name, target_field_name, mapping_type, data_type
            FROM field_mappings
            WHERE raw_data_id = %s
        """, (raw_data_id,))
        return {row[0]: dict(target=row[1], type=row[2], data_type=row[3]) for row in cursor.fetchall()}
    finally:
        cursor.close()

def insert_processed_rows(cursor, rows):
    if not rows:
        return
    columns = rows[0].keys()
    query = sql.SQL("INSERT INTO preprocessed_egypt_weekly_data ({}) VALUES ({})").format(
        sql.SQL(', ').join(map(sql.Identifier, columns)),
        sql.SQL(', ').join(sql.Placeholder() * len(columns))
    )
    cursor.executemany(query, [tuple(row.values()) for row in rows])

def insert_error_records(cursor, error_records):
    if not error_records:
        return
    cursor.executemany("""
        INSERT INTO preprocessing_errors 
        (raw_data_id, report_name, report_date, sheet_name, original_line, error_message)
        VALUES (%(raw_data_id)s, %(report_name)s, %(report_date)s, %(sheet_name)s, %(original_line)s, %(error_message)s)
    """, error_records)

def clean_row(row):
    """Applies NaT and NaN removal to a row."""
    return [remove_nat_nan(value) for value in row]

def get_available_reports(conn):
    """Fetches available reports from the database that haven't been preprocessed."""
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT raw_data_id, report_name, report_date, sheet_name
            FROM raw_egypt_weekly_reports
            WHERE NOT preprocessed
            ORDER BY report_date DESC, report_name, sheet_name
        """)
        return cursor.fetchall()
    finally:
        cursor.close()

def select_report(conn):
    """Prompts user to select a report from available reports."""
    reports = get_available_reports(conn)
    print("Available reports:")
    for i, (raw_data_id, report_name, report_date, sheet_name) in enumerate(reports, 1):
        print(f"{i}. {report_name} - {report_date} - {sheet_name} (ID: {raw_data_id})")
    
    while True:
        try:
            selection = int(input("Enter the number of the report to process (or 0 to exit): "))
            if selection == 0:
                return None
            if 1 <= selection <= len(reports):
                return reports[selection - 1]
            print("Invalid selection. Please try again.")
        except ValueError:
            print("Please enter a valid number.")

def check_field_mappings(conn, raw_data_id):
    """Checks if there are field mappings for a given report."""
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT COUNT(*) 
            FROM field_mappings 
            WHERE raw_data_id = %s
        """, (raw_data_id,))
        count = cursor.fetchone()[0]
        return count > 0
    finally:
        cursor.close()

def get_default_mappings(conn):
    """Fetches the default field mappings."""
    cursor = conn.cursor()
    try:
        cursor.execute("""
            SELECT raw_field_name, mapping_type, target_field_name, data_type
            FROM default_field_mappings
            JOIN mapping_sets ON default_field_mappings.set_id = mapping_sets.set_id
            WHERE mapping_sets.set_name = 'Default Mapping'
        """)
        return {row[0]: dict(type=row[1], target=row[2], data_type=row[3]) for row in cursor.fetchall()}
    finally:
        cursor.close()

def process_chunk(chunk, field_mappings, default_mappings, raw_data_id, report_name, report_date, sheet_name):
    processed_rows = []
    error_records = []
    
    logging.debug(f"Processing chunk. Type: {type(chunk)}, Length: {len(chunk)}")
    
    for index, row in enumerate(chunk):
        try:
            processed_row = clean_and_process_row(row, field_mappings, default_mappings)
            processed_row.update({
                'raw_data_id': raw_data_id,
                'report_name': report_name,
                'report_date': flexible_date_parse(report_date),
                'sheet_name': sheet_name,
                'original_line': index + 1
            })
            processed_rows.append(processed_row)
        except Exception as e:
            error_message = f"Error processing row {index}: {str(e)}\n{traceback.format_exc()}"
            logging.error(error_message)
            logging.debug(f"Problematic row data: {row}")
            error_records.append({
                'raw_data_id': raw_data_id,
                'report_name': report_name,
                'report_date': report_date,
                'sheet_name': sheet_name,
                'original_line': index + 1,
                'error_message': error_message
            })
    
    return processed_rows, error_records

def clean_and_process_row(row, field_mappings, default_mappings):
    processed_row = {}
    additional_data = {}
    
    logging.debug(f"Processing row. Type: {type(row)}, Content: {row}")
    
    for col, value in row.items():
        mapping = field_mappings.get(col) or default_mappings.get(col)
        if mapping:
            target_field = mapping['target']
            data_type = mapping.get('data_type')
            
            logging.debug(f"Processing field: {col}, Value: {value}, Mapping: {mapping}")
            
            if mapping['type'] in ['identifier', 'mrl', 'fulfillment']:
                processed_value = process_value(value, data_type)
                processed_row[target_field] = processed_value
            elif mapping['type'] == 'additional':
                additional_data[target_field] = safe_string(value)
        else:
            logging.warning(f"No mapping found for column: {col}")
    
    processed_row['additional_data'] = json.dumps(additional_data)
    return processed_row

def process_value(value, data_type):
    value = remove_nat_nan(value)
    if value is None:
        return None
    
    if data_type:
        if data_type.startswith('VARCHAR'):
            try:
                max_length = int(data_type.split('(')[1].rstrip(')'))
                return safe_string(value, max_length)
            except (IndexError, ValueError):
                return safe_string(value)  # Default to no max length if not specified
        elif data_type == 'TEXT':
            return safe_string(value)
        elif data_type == 'INT':
            return safe_int(value)
        elif data_type == 'MONEY':
            return safe_float(value)
        elif data_type == 'DATE':
            return flexible_date_parse(value)
        elif data_type == 'BOOLEAN':
            return bool(value) if pd.notnull(value) else None
    
    return safe_string(value)

def preprocess_egypt_weekly_data(conn, raw_data_id, report_name, report_date, sheet_name):
    cursor = conn.cursor()
    error_records = []

    logging.info(f"Starting preprocessing for raw_data_id: {raw_data_id}, report: {report_name}, date: {report_date}, sheet: {sheet_name}")

    try:
        # Check if already preprocessed
        cursor.execute("SELECT preprocessed FROM raw_egypt_weekly_reports WHERE raw_data_id = %s", (raw_data_id,))
        result = cursor.fetchone()
        if result and result[0]:
            logging.info(f"Raw data with ID {raw_data_id} has already been preprocessed. Skipping.")
            return

        if not check_field_mappings(conn, raw_data_id):
            use_default = input("No field mappings found. Do you want to use the Default Mapping? (y/n): ").lower() == 'y'
            if not use_default:
                raise ValueError(f"No field mappings found for raw_data_id {raw_data_id}. "
                                 "Please apply data mapping for this report/sheet before preprocessing.")
        
        cursor.execute("""
            SELECT column_names, row_data
            FROM raw_egypt_weekly_reports
            WHERE raw_data_id = %s
        """, (raw_data_id,))
        raw_data = cursor.fetchone()

        if not raw_data:
            logging.warning(f"No data found for raw_data_id {raw_data_id}")
            return
        
        column_names, row_data = raw_data

        logging.debug(f"Raw column_names: {column_names}")
        logging.debug(f"Raw row_data type: {type(row_data)}")
        logging.debug(f"Raw row_data sample: {str(row_data)[:1000]}")  # Log first 1000 characters

        # Parse column names and row data
        if isinstance(column_names, str):
            column_names = json.loads(column_names)
        
        if isinstance(row_data, str):
            json_data = json.loads(row_data)
        elif isinstance(row_data, list):
            json_data = row_data
        else:
            raise ValueError(f"Unexpected row_data type: {type(row_data)}")
        
        logging.debug(f"Parsed json_data type: {type(json_data)}")
        logging.debug(f"Parsed json_data length: {len(json_data)}")
        logging.debug(f"First row of json_data: {json_data[0] if json_data else 'Empty'}")

        # Fetch field mappings and default mappings
        field_mappings = get_field_mappings(conn, raw_data_id)
        default_mappings = get_default_mappings(conn)
        
        # If no field mappings and user chose to use default, use default mappings
        if not field_mappings and use_default:
            field_mappings = default_mappings
        
        # Process data in chunks
        chunk_size = 1000
        total_processed = 0
        for i in range(0, len(json_data), chunk_size):
            chunk = json_data[i:i+chunk_size]
            logging.debug(f"Processing chunk {i//chunk_size + 1}, size: {len(chunk)}")
            processed_rows, chunk_errors = process_chunk(chunk, field_mappings, default_mappings, 
                                                         raw_data_id, report_name, report_date, sheet_name)
            
            # Insert processed rows
            if processed_rows:
                insert_processed_rows(cursor, processed_rows)
                total_processed += len(processed_rows)
            
            # Accumulate errors
            error_records.extend(chunk_errors)
        
        # Insert error records
        if error_records:
            insert_error_records(cursor, error_records)

        conn.commit()
        logging.info(f"Preprocessed {total_processed} rows for raw_data_id {raw_data_id}")
        if error_records:
            logging.warning(f"Encountered {len(error_records)} errors during preprocessing. See preprocessing_errors table for details.")

        # Update preprocessed status
        update_preprocessed_status(conn, raw_data_id)

    except Exception as e:
        conn.rollback()
        logging.error(f"Error preprocessing data: {str(e)}")
        logging.error(traceback.format_exc())
        raise
    finally:
        cursor.close()
        
def update_preprocessed_status(conn, raw_data_id):
    """Updates the preprocessed status to True for the given raw_data_id."""
    cursor = conn.cursor()
    try:
        cursor.execute("""
            UPDATE raw_egypt_weekly_reports
            SET preprocessed = TRUE
            WHERE raw_data_id = %s
        """, (raw_data_id,))
        conn.commit()
    except Exception as e:
        conn.rollback()
        logging.error(f"Error updating preprocessed status: {str(e)}")
        raise
    finally:
        cursor.close()

def main():
    conn = psycopg2.connect(
        dbname="ReportsDB",
        user="postgres",
        password="123456",
        host="cmms-db-01",
        port="5432"
    )
    try:
        while True:
            selected_report = select_report(conn)
            if selected_report is None:
                print("Exiting.")
                break
            
            raw_data_id, report_name, report_date, sheet_name = selected_report
            try:
                preprocess_egypt_weekly_data(conn, raw_data_id, report_name, report_date, sheet_name)
                print(f"Preprocessing completed for raw_data_id {raw_data_id}")
            except ValueError as ve:
                print(f"Error: {str(ve)}")
            except Exception as e:
                print(f"An error occurred during preprocessing: {str(e)}")
                logging.error("Traceback:", exc_info=True)
            
            if input("Do you want to process another report? (y/n): ").lower() != 'y':
                break
    finally:
        conn.close()

if __name__ == "__main__":
    main()

if __name__ == "__main__":
    main()