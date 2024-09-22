import sys
import json
import logging
from PySide6.QtWidgets import (
    QMainWindow, QFileDialog, QMessageBox, QInputDialog, QDialog
)
from PySide6.QtCore import QFile, QSettings
from PySide6.QtUiTools import QUiLoader
from config import APP_NAME, COMPANY_NAME
import pandas as pd
from database_manager import DatabaseManager
import numpy as np
import math
from datetime import datetime, date
from utils import DateTimeEncoder

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
    'twcode': 50 }

class MainWindow(QMainWindow):
    def __init__(self, db_manager):
        super(MainWindow, self).__init__()
        self.db_manager = db_manager
        self.settings = QSettings(COMPANY_NAME, APP_NAME)

        try:
            # Initialize logging
            self.setup_logging()
            logging.debug("Starting MainWindow initialization.")

            logging.debug("Loading UI file for MainWindow.")
            # Load the UI using QUiLoader
            loader = QUiLoader()
            ui_file = QFile("main_window.ui")
            if not ui_file.exists():
                logging.error("The UI file 'main_window.ui' was not found.")
                QMessageBox.critical(None, "Error", "The UI file 'main_window.ui' was not found.")
                sys.exit(1)
            ui_file.open(QFile.ReadOnly)
            self.ui = loader.load(ui_file)
            ui_file.close()
            if self.ui is None:
                logging.error("Failed to load UI file. loader.load() returned None.")
                QMessageBox.critical(None, "Error", "Failed to load the UI file 'main_window.ui'.")
                sys.exit(1)
            logging.debug("UI file loaded successfully.")

            # Set the central widget
            self.setCentralWidget(self.ui)
            logging.debug("Central widget set.")

            # Connect signals
            self.connect_signals()
            logging.debug("Signals connected.")

            # Set up main UI elements
            self.setup_main_ui()
            logging.debug("Main UI setup complete.")

        except Exception as e:
            logging.exception(f"Exception occurred in MainWindow __init__: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred while initializing the main window:\n{str(e)}")
            sys.exit(1)

    def setup_logging(self):
        import logging
        import sys
        from logging.handlers import RotatingFileHandler

        logger = logging.getLogger()
        logger.setLevel(logging.DEBUG)  # Capture all levels of logs

        # Formatter for consistent log message format
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')

        # File handler with log rotation
        file_handler = RotatingFileHandler('app.log', maxBytes=5*1024*1024, backupCount=2)
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)

        # Console handler
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.DEBUG)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)

        logger.debug("Logging has been configured.")

    def connect_signals(self):
        try:
            self.ui.insert_mrl_button.clicked.connect(self.import_and_insert_mrl_line_items)
            logging.debug("Connected 'insert_mrl_button' signal.")
            self.ui.update_fulfillment_button.clicked.connect(self.import_and_update_fulfillment_records)
            logging.debug("Connected 'update_fulfillment_button' signal.")
        except AttributeError as e:
            logging.error(f"AttributeError in connect_signals: {e}")
            QMessageBox.critical(self, "Error", f"UI element not found: {str(e)}")
            sys.exit(1)

    def setup_main_ui(self):
        try:
            # Update UI elements based on user role
            self.ui.user_label.setText(f"User ID: {self.db_manager.user_id}")
            self.ui.role_label.setText(f"Role: {self.db_manager.db_role_name}")
            logging.debug("User information displayed on main UI.")
        except Exception as e:
            logging.error(f"Error in setup_main_ui: {e}")
            QMessageBox.critical(self, "Error", f"Failed to set up main UI elements:\n{str(e)}")

    def open_mrl_dialog(self):
        dialog = MRLLineItemDialog()
        dialog.exec()  # Show the dialog

    def import_and_insert_mrl_line_items(self):
        try:
            # Get the update source from the input field
            update_source = self.ui.update_source_input.text().strip()
            if not update_source:
                QMessageBox.warning(self, "Input Required", "Update source is required.")
                logging.warning("Update source input is empty.")
                return

            # Select the Excel file
            file_path, _ = QFileDialog.getOpenFileName(
                self, "Select Excel File", "", "Excel Files (*.xlsx *.xls *.csv)"
            )
            if not file_path:
                QMessageBox.warning(self, "File Required", "No file selected.")
                logging.warning("No Excel file selected for MRL insertion.")
                return

            # Read the Excel file into a pandas DataFrame
            data_frame = pd.read_excel(file_path)
            logging.debug(f"Excel file '{file_path}' read successfully.")

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

            # Define required columns
            required_columns = [
                'jcn', 'twcode'
            ]
            # For insertion, other columns can be optional but should be handled accordingly
            # If your stored procedure requires certain columns, include them here

            # Verify required columns are present
            missing_columns = set(required_columns) - set(data_frame.columns)
            if missing_columns:
                QMessageBox.warning(
                    self,
                    "Missing Columns",
                    f"The following required columns are missing in the Excel file: {', '.join(missing_columns)}"
                )
                logging.error(f"Missing required columns for MRL insertion: {', '.join(missing_columns)}")
                return

            # Keep only required columns and any optional columns
            # Assuming other columns can be present and handled by the stored procedure
            # If you need to enforce more required columns for insertion, adjust accordingly

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
            data = self.clean_data(data)
            logging.debug("Data cleaned to remove NaN and Infinity values.")

            # Call the insert_mrl_line_items_efficient method with the data
            summary = self.db_manager.insert_mrl_line_items_efficient(data, update_source)
            logging.debug("Called 'insert_mrl_line_items_efficient' stored procedure.")

            # Show the result to the user
            summary_pretty = json.dumps(summary, indent=2)
            QMessageBox.information(
                self,
                "Import Result",
                f"Import completed.\nSummary:\n{summary_pretty}"
            )
            logging.info("MRL Line Items inserted successfully.")

        except Exception as e:
            logging.exception(f"Error during import_and_insert_mrl_line_items: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred during MRL insertion:\n{str(e)}")

    def import_and_update_fulfillment_records(self):
        try:
            # Get the update source from the input field
            update_source = self.ui.update_source_input.text().strip()
            if not update_source:
                QMessageBox.warning(self, "Input Required", "Update source is required.")
                logging.warning("Update source input is empty.")
                return

            # Select the Excel file
            file_path, _ = QFileDialog.getOpenFileName(
                self, "Select Excel File", "", "Excel Files (*.xlsx *.xls *.csv)"
            )
            if not file_path:
                QMessageBox.warning(self, "File Required", "No file selected.")
                logging.warning("No Excel file selected for Fulfillment update.")
                return

            # Read the Excel file into a pandas DataFrame
            data_frame = pd.read_excel(file_path)
            logging.debug(f"Excel file '{file_path}' read successfully.")

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

            # Define identifying (mandatory) columns
            identifying_columns = [
                'jcn', 'twcode'
            ]

            # Define optional columns that can be updated if present
            optional_columns = [
                'shipdoc_tcn', 'v2x_ship_no',
                'booking', 'vessel', 'container', 'carrier',
                'sail_date', 'edd_to_ches', 'edd_egypt', 'rcd_v2x_date',
                'lot_id', 'triwall', 'lsc_on_hand_date', 'arr_lsc_egypt',
                'milstrip_req_no', 'comments'
            ]

            # Verify identifying columns are present
            missing_columns = set(identifying_columns) - set(data_frame.columns)
            if missing_columns:
                QMessageBox.warning(
                    self,
                    "Missing Columns",
                    f"The following required identifying columns are missing in the Excel file: {', '.join(missing_columns)}"
                )
                logging.error(f"Missing identifying columns for Fulfillment update: {', '.join(missing_columns)}")
                return

            # Keep only identifying columns and any optional columns present
            present_optional_columns = [col for col in optional_columns if col in data_frame.columns]
            required_columns = identifying_columns + present_optional_columns
            data_frame = data_frame[required_columns]
            logging.debug(f"DataFrame filtered to required and present optional columns: {required_columns}")

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

            # Print first few records to verify inclusion of 'jcn' and 'twcode'
            logging.debug("First few records:")
            for record in data[:2]:
                logging.debug(record)

            # Validate and truncate data
            data = self.validate_and_truncate_data(data)
            logging.debug("Data validated and truncated based on field length constraints.")

            # Clean the data recursively
            data = self.clean_data(data)
            logging.debug("Data cleaned to remove NaN and Infinity values.")

            # Pass `data` directly without JSON serialization
            summary = self.db_manager.update_fulfillment_records_efficient(data, update_source)
            logging.debug("Called 'update_fulfillment_items_efficient' stored procedure.")

            # Prepare the message based on summary
            if summary.get('status') == 'completed':
                message = (
                    f"Update completed.\n"
                    f"Total Records: {summary.get('total', 0)}\n"
                    f"Successful Updates: {summary.get('success', 0)}\n"
                    f"Warnings: {summary.get('warnings', 0)}\n"
                    f"Errors: {summary.get('errors', 0)}\n"
                    f"Operation: {summary.get('operation', 'N/A')}\n"
                    f"Timestamp: {summary.get('timestamp', 'N/A')}\n\n"
                    f"See import_error_log for details on warnings and errors."
                )
                QMessageBox.information(
                    self,
                    "Update Result",
                    message
                )
                logging.info("Fulfillment Records updated successfully.")

            elif summary.get('status') == 'error':
                message = (
                    f"Update encountered an error.\n"
                    f"Message: {summary.get('message', 'No message provided.')}\n"
                    f"Operation: {summary.get('operation', 'N/A')}\n"
                    f"Timestamp: {summary.get('timestamp', 'N/A')}"
                )
                QMessageBox.critical(
                    self,
                    "Update Error",
                    message
                )
                logging.error("Error encountered during Fulfillment Records update.")

            else:
                message = "Unexpected summary status received."
                QMessageBox.warning(
                    self,
                    "Unexpected Status",
                    message
                )
                logging.warning("Unexpected summary status received during Fulfillment Records update.")

        except Exception as e:
            logging.exception(f"Error during import_and_update_fulfillment_records: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred during Fulfillment Records update:\n{str(e)}")

    def clean_data(self, obj):
        """
        Recursively replace NaN and Infinity with None in the data.
        """
        if isinstance(obj, float):
            if math.isnan(obj) or math.isinf(obj):
                return None
            else:
                return obj
        elif isinstance(obj, dict):
            return {k: self.clean_data(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [self.clean_data(elem) for elem in obj]
        else:
            return obj

    def convert_types(self, obj):
        if isinstance(obj, dict):
            return {k: self.convert_types(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [self.convert_types(v) for v in obj]
        elif isinstance(obj, (np.integer,)):
            return int(obj)
        elif isinstance(obj, (np.floating,)):
            return float(obj) if not np.isnan(obj) else None
        elif isinstance(obj, (np.ndarray,)):
            return obj.tolist()
        elif pd.isnull(obj):
            return None
        elif isinstance(obj, (pd.Timestamp,)):
            return obj.strftime('%Y-%m-%d %H:%M:%S')
        else:
            return obj

    def validate_and_truncate_data(self, data_list):
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

    def select_excel_file(self):
        file_path, _ = QFileDialog.getOpenFileName(self, "Select Excel File", "", "Excel Files (*.xlsx *.xls)")
        return file_path

    def select_worksheet(self, workbook):
        sheet_names = [sheet.Name for sheet in workbook.Sheets]
        sheet_name, ok = QInputDialog.getItem(self, "Select Worksheet", "Choose a worksheet:", sheet_names, 0, False)
        if ok and sheet_name:
            return workbook.Worksheets(sheet_name)
        return None

    def clean_up_column_names(self, sheet, header_row):
        for col in range(1, 201):  # Limit to first 200 columns
            cell = sheet.Cells(header_row, col)
            if cell.Value is None:
                break
            col_name = cell.Value.strip().lower()
            col_name = col_name.replace(" ", "_").replace("-", "_").replace("/", "_")
            while "__" in col_name:
                col_name = col_name.replace("__", "_")
            cell.Value = col_name

    def clean_up_data(self, sheet, header_row):
        last_row = sheet.UsedRange.Rows.Count
        last_col = sheet.UsedRange.Columns.Count

        for col in range(1, last_col + 1):
            for row in range(header_row + 1, last_row + 1):
                cell = sheet.Cells(row, col)
                if isinstance(cell.Value, str):
                    if cell.Value.startswith("'") and cell.Value[1:].isnumeric():
                        cell.Value = float(cell.Value[1:])
                    elif cell.Value.isnumeric():
                        cell.Value = float(cell.Value)
                    cell.Value = cell.Value.strip()

    def build_column_lookup(self, sheet, header_row):
        column_lookup = {}
        for col in range(1, 201):
            cell_value = sheet.Cells(header_row, col).Value
            if cell_value is None:
                break
            column_lookup[cell_value.lower().strip()] = col
        return column_lookup

    def import_excel_to_dataframe(self, file_path):
        # Read the Excel file into a pandas DataFrame
        self.temp_data = pd.read_excel(file_path)

    def show_import_errors(self, batch_id):
        error_message = f"Import completed with errors or duplicates.\nBatch ID: {batch_id}\n\n"
        error_message += "Please review the import results in the database."
        QMessageBox.warning(self, "Import Errors", error_message)

    def cleanup_temp_data(self):
        if hasattr(self, 'temp_data'):
            del self.temp_data
            print("Temporary data cleaned up")


class MRLLineItemDialog(QDialog):
    def __init__(self):
        super(MRLLineItemDialog, self).__init__()

        # Load the UI for the dialog
        loader = QUiLoader()
        ui_file = QFile("mrl_line_item_dialog.ui")
        if not ui_file.exists():
            logging.error("The UI file 'mrl_line_item_dialog.ui' was not found.")
            QMessageBox.critical(None, "Error", "The UI file 'mrl_line_item_dialog.ui' was not found.")
            sys.exit(1)
        ui_file.open(QFile.ReadOnly)
        self.ui = loader.load(ui_file, self)
        ui_file.close()
