import pandas as pd
import psycopg2
import os
import glob
import logging
from datetime import datetime
import re

# Configure logging with timestamps
logging.basicConfig(filename='upload_reports.log', level=logging.INFO)

def log_info(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    logging.info(f"{timestamp} - {message}")
    print(f"{timestamp} - {message}")

# Function to clean sheet names by removing quotes, special characters, and redundant parts
def clean_sheet_name(sheet_name):
    cleaned_name = re.sub(r'[^\w]', '_', sheet_name).strip('_')
    return re.sub(r'_+', '_', cleaned_name)

# Function to extract and clean the report date
def extract_report_date(file_name):
    # Use regex to find date patterns in the file name
    date_match = re.search(r'(\d{1,2})[-_](\d{1,2})[-_](\d{4})', file_name)
    if date_match:
        month, day, year = date_match.groups()
        try:
            return datetime.strptime(f'{month}-{day}-{year}', '%m-%d-%Y').date()
        except ValueError:
            return None
    return None

# Connect to PostgreSQL database
conn = psycopg2.connect(
    host="cmms-db-01",
    dbname="ReportsDB",
    user="postgres",
    password="123456"
)
cur = conn.cursor()

# Pattern to match preprocessed CSV files
file_pattern = "*.csv"
files_to_process = glob.glob(file_pattern)

for file_path in files_to_process:
    log_info(f"Processing CSV file: {file_path}")

    # Extract the report name (original Excel file name from the CSV name)
    report_name = os.path.basename(file_path).split('_')[0]  # Extract just the report name

    # Extract the report date from the file name
    report_date = extract_report_date(os.path.basename(file_path))
    if report_date is None:
        log_info(f"Error extracting report date from {file_path}")
        continue

    # Extract the sheet name from the file name, removing "cleaned" and problematic characters
    sheet_name = os.path.basename(file_path).replace('.csv', '').replace('cleaned', '')
    cleaned_sheet_name = clean_sheet_name(sheet_name)

    # Read the CSV file into a DataFrame
    try:
        df = pd.read_csv(file_path, dtype=str, encoding='utf-8')
    except UnicodeDecodeError:
        log_info(f"UTF-8 decoding failed for {file_path}, trying latin-1")
        try:
            df = pd.read_csv(file_path, dtype=str, encoding='latin-1')
        except Exception as e:
            log_info(f"Error reading {file_path}: {e}")
            continue

    # Get the column names as a list
    column_names = df.columns.tolist()

    # Convert the entire DataFrame to JSON (this will be a JSON representation of all rows)
    sheet_data_json = df.to_json(orient="records")

    # Insert a single record with all the sheet's data into the raw_egypt_weekly_reports table
    try:
        cur.execute(
            """
            INSERT INTO raw_egypt_weekly_reports (report_name, report_date, sheet_name, column_names, row_data)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                report_name,                       # report_name (original Excel file name)
                report_date,                       # report_date (extracted date)
                cleaned_sheet_name,                # sheet_name (cleaned)
                column_names,                      # column_names as TEXT[]
                sheet_data_json                    # row_data (entire sheet's data as a JSON string)
            )
        )
        conn.commit()
        log_info(f"Successfully inserted sheet {cleaned_sheet_name} from report {report_name} into raw_egypt_weekly_reports")

    except Exception as e:
        log_info(f"Error inserting data for {cleaned_sheet_name} in {report_name}: {e}")
        conn.rollback()

# Close the cursor and connection
cur.close()
conn.close()
