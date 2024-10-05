# bulk_operations_window.py

import logging
from PySide6.QtWidgets import (
    QMainWindow, QMessageBox, QFileDialog, QApplication
)
from PySide6.QtCore import QFile, Signal
from PySide6.QtUiTools import QUiLoader
import pandas as pd
import json
from bulk_operations import (
    prepare_mrl_data,
    prepare_fulfillment_data
)
from database_manager import DatabaseManager

class BulkOperationsWindow(QMainWindow):
    window_closed = Signal()

    def __init__(self, db_manager, parent=None):
        super(BulkOperationsWindow, self).__init__(parent)
        self.db_manager = db_manager

        try:
            # Load the UI using QUiLoader
            loader = QUiLoader()
            ui_file = QFile("bulk_operations_window.ui")
            if not ui_file.exists():
                logging.error("The UI file 'bulk_operations_window.ui' was not found.")
                QMessageBox.critical(None, "Error", "The UI file 'bulk_operations_window.ui' was not found.")
                return
            ui_file.open(QFile.ReadOnly)
            self.ui = loader.load(ui_file, self)
            ui_file.close()
            if self.ui is None:
                logging.error("Failed to load UI file. loader.load() returned None.")
                QMessageBox.critical(None, "Error", "Failed to load the UI file 'bulk_operations_window.ui'.")
                return
            logging.debug("BulkOperationsWindow UI loaded successfully.")

            # Set the central widget
            self.setCentralWidget(self.ui)
            logging.debug("Central widget set for BulkOperationsWindow.")

            # Set window title
            self.setWindowTitle(self.ui.windowTitle())

            # Connect signals
            self.connect_signals()
            logging.debug("Signals connected in BulkOperationsWindow.")

            # Set default selections or states
            self.ui.importMRLLineItemsRadio.setChecked(True)

        except Exception as e:
            logging.exception(f"Exception occurred in BulkOperationsWindow __init__: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred while initializing the Bulk Operations window:\n{str(e)}")

    def closeEvent(self, event):
        self.window_closed.emit()
        super(BulkOperationsWindow, self).closeEvent(event)

    def connect_signals(self):
        self.ui.executeButton.clicked.connect(self.execute_operation)
        self.ui.closeButton.clicked.connect(self.close)

    def execute_operation(self):
        try:
            update_source = self.ui.updateSourceEdit.text().strip()
            if not update_source:
                QMessageBox.warning(self, "Input Required", "Update source is required.")
                logging.warning("Update source input is empty.")
                return

            # Determine which operation is selected
            if self.ui.importMRLLineItemsRadio.isChecked():
                self.import_mrl_line_items(update_source)
            elif self.ui.updateFulfillmentRecordsRadio.isChecked():
                self.update_fulfillment_records(update_source)
            else:
                QMessageBox.warning(self, "Operation Not Selected", "Please select a bulk operation to execute.")
                logging.warning("No bulk operation selected.")
        except Exception as e:
            logging.exception(f"Error in execute_operation: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred during bulk operation execution:\n{str(e)}")

    def import_mrl_line_items(self, update_source):
        try:
            # Select the Excel file
            file_path, _ = QFileDialog.getOpenFileName(
                self, "Select Excel File for MRL Line Items", "", "Excel Files (*.xlsx *.xls *.csv)"
            )
            if not file_path:
                QMessageBox.warning(self, "File Required", "No file selected.")
                logging.warning("No Excel file selected for MRL insertion.")
                return

            # Read the Excel file into a pandas DataFrame
            data_frame = pd.read_excel(file_path)
            logging.debug(f"Excel file '{file_path}' read successfully.")

            # Prepare data
            data = prepare_mrl_data(data_frame)

            # Call the insert method
            summary = self.db_manager.insert_mrl_line_items_efficient(data, update_source)

            # Show the result to the user
            summary_pretty = json.dumps(summary, indent=2)
            QMessageBox.information(
                self,
                "Import Result",
                f"Import completed.\nSummary:\n{summary_pretty}"
            )
            logging.info("MRL Line Items imported successfully.")

        except Exception as e:
            logging.exception(f"Error in import_mrl_line_items: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred during MRL Line Items import:\n{str(e)}")

    def update_fulfillment_records(self, update_source):
        try:
            # Select the Excel file
            file_path, _ = QFileDialog.getOpenFileName(
                self, "Select Excel File for Fulfillment Records Update", "", "Excel Files (*.xlsx *.xls *.csv)"
            )
            if not file_path:
                QMessageBox.warning(self, "File Required", "No file selected.")
                logging.warning("No Excel file selected for Fulfillment update.")
                return

            # Read the Excel file into a pandas DataFrame
            data_frame = pd.read_excel(file_path)
            logging.debug(f"Excel file '{file_path}' read successfully.")

            # Prepare data
            data = prepare_fulfillment_data(data_frame)

            # Call the update method
            summary = self.db_manager.update_fulfillment_records_efficient(data, update_source)

            # Show the result to the user
            summary_pretty = json.dumps(summary, indent=2)
            QMessageBox.information(
                self,
                "Update Result",
                f"Update completed.\nSummary:\n{summary_pretty}"
            )
            logging.info("Fulfillment Records updated successfully.")

        except Exception as e:
            logging.exception(f"Error in update_fulfillment_records: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred during Fulfillment Records update:\n{str(e)}")
