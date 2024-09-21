import pandas as pd
import os
import glob
import logging
from datetime import datetime
import re

# Configure logging with timestamps
logging.basicConfig(filename='process_excel.log', level=logging.INFO)

def log_info(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    logging.info(f"{timestamp} - {message}")
    print(f"{timestamp} - {message}")

# Function to clean non-ASCII characters
def clean_text(text):
    if isinstance(text, str):
        return ''.join(char if ord(char) < 128 else '' for char in text)
    return text

# Function to clean column names to be compatible with PostgreSQL and ensure lowercase
def clean_column_name(col_name):
    # Replace invalid characters (like spaces, periods, and hyphens) with underscores
    col_name = re.sub(r'[^a-zA-Z0-9]', '_', col_name.strip().lower())
    # Replace multiple consecutive underscores with a single underscore
    col_name = re.sub(r'_+', '_', col_name)
    return col_name[:63]  # Ensure no longer than 63 characters

# Function to detect invalid values and log them to the ERRORS field
def detect_errors_and_log(df):
    error_column_data = []

    for index, row in df.iterrows():
        error_log = []
        for col in df.columns:
            value = row[col]
            # Check for problematic values (e.g., invalid dates or outliers)
            if isinstance(value, (int, float)) and (value > 1e10 or value < -1e10):  # Example of outliers
                error_log.append(f"{col}: {value}")

        # Combine all errors for the row, if any, into a semicolon-separated string
        if error_log:
            error_column_data.append('; '.join(error_log))
        else:
            error_column_data.append(None)

    # Add the ERRORS column to the DataFrame
    df['ERRORS'] = error_column_data

    return df

# Function to clean sheet names
def clean_sheet_name(sheet_name):
    cleaned_name = re.sub(r'[^\w]', '_', sheet_name).strip('_')
    return re.sub(r'_+', '_', cleaned_name)

# Set the pattern for the Excel files to process
file_pattern = "EG*.xlsx"
files_to_process = glob.glob(file_pattern)

for excel_file in files_to_process:
    log_info(f"Processing Excel file: {excel_file}")

    # Load the Excel file, read all sheets
    try:
        df_dict = pd.read_excel(excel_file, sheet_name=None, engine='openpyxl')
    except Exception as e:
        log_info(f"Error processing {excel_file}: {e}")
        continue

    # Clean data and save to CSV for each sheet
    for sheet_name, df in df_dict.items():
        # Clean column names and ensure they are all lowercase with only one underscore between words
        df.columns = [clean_column_name(col) for col in df.columns]

        # Clean the data (remove non-ASCII characters)
        df = df.apply(lambda col: col.map(clean_text))

        # Detect errors in the data and log to the ERRORS column
        df = detect_errors_and_log(df)

        # Cast all columns to strings to handle mixed types
        df = df.astype(str)

        # Add the original row number as 'original_line' column
        df['original_line'] = df.index + 2  # Correcting row number offset

        # Clean the sheet name
        cleaned_sheet_name = clean_sheet_name(sheet_name)

        # Generate the output CSV filename
        base_filename = os.path.splitext(os.path.basename(excel_file))[0]
        csv_file = f"{base_filename}_{cleaned_sheet_name}_cleaned.csv"

        # Save the cleaned DataFrame to CSV
        try:
            df.to_csv(csv_file, index=False, encoding='utf-8')
            log_info(f"Successfully saved {csv_file}")
        except Exception as e:
            log_info(f"Error saving {csv_file}: {e}")
