# search_window.py

import sys
import logging
from PySide6.QtWidgets import (
    QMainWindow, QMessageBox, QApplication, QTableView, QAbstractItemView
)
from PySide6.QtCore import QFile, QAbstractTableModel, Qt, QModelIndex, Signal
from PySide6.QtUiTools import QUiLoader
from PySide6.QtGui import QCursor
import pandas as pd
from mrl_detail_window import MRLDetailWindow

class SearchWindow(QMainWindow):
    window_closed = Signal()
    def __init__(self, db_manager):
        super(SearchWindow, self).__init__()
        self.db_manager = db_manager

        try:
            # Load the UI using QUiLoader
            loader = QUiLoader()
            ui_file = QFile("search_window.ui")
            if not ui_file.exists():
                logging.error("The UI file 'search_window.ui' was not found.")
                QMessageBox.critical(None, "Error", "The UI file 'search_window.ui' was not found.")
                return
            ui_file.open(QFile.ReadOnly)
            self.ui = loader.load(ui_file, self)
            ui_file.close()
            if self.ui is None:
                logging.error("Failed to load UI file. loader.load() returned None.")
                QMessageBox.critical(None, "Error", "Failed to load the UI file 'search_window.ui'.")
                return
            logging.debug("SearchWindow UI loaded successfully.")

            # Set the central widget
            self.setCentralWidget(self.ui)
            logging.debug("Central widget set for SearchWindow.")

            # Set window title
            self.setWindowTitle(self.ui.windowTitle())

            # Connect signals
            self.connect_signals()
            logging.debug("Signals connected in SearchWindow.")

            # Initialize variables
            self.results_df = pd.DataFrame()
            self.limit = 100  # Initial limit
            self.offset = 0

            # Set up the results table
            self.setup_results_table()

        except Exception as e:
            logging.exception(f"Exception occurred in SearchWindow __init__: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred while initializing the search window:\n{str(e)}")

    def connect_signals(self):
        # Connect search button
        self.ui.searchButton.clicked.connect(self.perform_search)
        
        # Connect Enter key press for each input field
        input_fields = [
            self.ui.jcnEdit, self.ui.niinEdit, self.ui.partNoEdit,
            self.ui.twcodeEdit, self.ui.swlinEdit, self.ui.nomenclatureEdit,
            self.ui.availabilityIdentifierEdit
        ]
        for field in input_fields:
            field.returnPressed.connect(self.perform_search)

        self.ui.clearButton.clicked.connect(self.clear_filters)
        self.ui.loadMoreButton.clicked.connect(self.load_more)
        self.ui.resultsTable.doubleClicked.connect(self.open_mrl_detail)
        
        # Hide the loading indicator initially
        self.ui.loadingIndicator.setVisible(False)
        
        logging.debug("Signals connected in SearchWindow.")

    def perform_search(self):
        self.offset = 0  # Reset offset when performing a new search
        self.apply_filter()

    def apply_filter(self):
        try:
            self.results_df = pd.DataFrame()  # Clear previous results
            self.ui.resultsTable.model().layoutChanged.emit()  # Refresh the table
            self.load_data()
        except Exception as e:
            logging.exception(f"Error in apply_filter: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred during search:\n{str(e)}")

    def setup_results_table(self):
        self.model = PandasTableModel(self.results_df)
        self.ui.resultsTable.setModel(self.model)
        self.ui.resultsTable.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.ui.resultsTable.setSelectionMode(QAbstractItemView.SingleSelection)
        self.ui.resultsTable.setAlternatingRowColors(True)
        self.ui.resultsTable.setSortingEnabled(True)

    def load_data(self):
        try:
            self.ui.loadingIndicator.setVisible(True)
            QApplication.processEvents()
            conditions = []
            params = {}

            # Get filter values
            filters = {
                'jcn': self.ui.jcnEdit.text(),
                'niin': self.ui.niinEdit.text(),
                'part_no': self.ui.partNoEdit.text(),
                'twcode': self.ui.twcodeEdit.text(),
                'swlin': self.ui.swlinEdit.text(),
                'nomenclature': self.ui.nomenclatureEdit.text(),
                'availability_identifier': self.ui.availabilityIdentifierEdit.text(),
            }

            # Define data types
            field_data_types = {
                'jcn': 'text',
                'niin': 'text',
                'part_no': 'text',
                'twcode': 'text',
                'swlin': 'text',
                'nomenclature': 'text',
                'availability_identifier': 'integer',
            }

            # Build conditions for each field, supporting multiple tokens
            for field, value in filters.items():
                if value:
                    data_type = field_data_types.get(field, 'text')
                    tokens = value.replace('*', '%').split('%')
                    token_conditions = []
                    for idx, token in enumerate(tokens):
                        if token:
                            param_key = f"{field}_{idx}"
                            if data_type == 'text':
                                token_conditions.append(f"{field} ILIKE %({param_key})s")
                                params[param_key] = f"%{token}%"
                            elif data_type == 'integer':
                                # For partial matching, cast integer field to text
                                token_conditions.append(f"CAST({field} AS TEXT) ILIKE %({param_key})s")
                                params[param_key] = f"%{token}%"
                            else:
                                # Handle other data types if necessary
                                pass
                    if token_conditions:
                        conditions.append(" AND ".join(token_conditions))

            # Build the SQL query
            sql_query = "SELECT * FROM combined_line_items_fulfillments_search_view WHERE 1=1"
            if conditions:
                sql_query += " AND " + " AND ".join(conditions)
            sql_query += f" ORDER BY jcn LIMIT {self.limit} OFFSET {self.offset}"

            logging.debug(f"Executing search query: {sql_query} with params: {params}")

            # Execute the query
            with self.db_manager.connection.cursor() as cursor:
                cursor.execute(sql_query, params)
                columns = [desc[0] for desc in cursor.description]
                data = cursor.fetchall()
                df = pd.DataFrame(data, columns=columns)

            # Append new data
            self.results_df = pd.concat([self.results_df, df], ignore_index=True)
            self.model.update_data(self.results_df)

            # Update the result count label
            total_records = len(self.results_df)
            self.ui.resultCountLabel.setText(f"Showing {total_records} records")

            self.offset += self.limit  # Update offset for next load
            self.ui.loadingIndicator.setVisible(False)
        except Exception as e:
            self.ui.loadingIndicator.setVisible(False)
            self.db_manager.connection.rollback()  # Rollback the transaction
            logging.exception(f"Error in load_data: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred while loading data:\n{str(e)}")

    def load_more(self):
        self.load_data()

    def clear_filters(self):
        self.ui.jcnEdit.clear()
        self.ui.niinEdit.clear()
        self.ui.partNoEdit.clear()
        self.ui.twcodeEdit.clear()
        self.ui.swlinEdit.clear()
        self.ui.nomenclatureEdit.clear()
        self.ui.availabilityIdentifierEdit.clear()
        # Clear results
        self.results_df = pd.DataFrame()
        self.model.update_data(self.results_df)
        self.ui.resultCountLabel.setText("Showing 0 records")
        self.offset = 0

    def open_mrl_detail(self, index):
        try:
            row = index.row()
            record = self.results_df.iloc[row]
            order_line_item_id = int(record['order_line_item_id'])  # Convert to Python int
            # Open MRL Detail Window
            mrl_detail_window = MRLDetailWindow(self.db_manager, order_line_item_id, parent=None)
            mrl_detail_window.show()
            if hasattr(QApplication.instance(), 'open_windows'):
                QApplication.instance().open_windows.append(mrl_detail_window)
            else:
                logging.warning("QApplication instance does not have 'open_windows' attribute")
            mrl_detail_window.window_closed.connect(lambda: self.remove_window_from_app_list(mrl_detail_window))
        except Exception as e:
            logging.exception(f"Error in open_mrl_detail: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred while opening MRL detail:\n{str(e)}")

    def remove_window_from_app_list(self, window):
        if window in QApplication.instance().open_windows:
            QApplication.instance().open_windows.remove(window)

    def closeEvent(self, event):
        self.window_closed.emit()
        super(SearchWindow, self).closeEvent(event)

class PandasTableModel(QAbstractTableModel):
    def __init__(self, df=pd.DataFrame(), parent=None):
        super(PandasTableModel, self).__init__(parent)
        self._df = df

    def update_data(self, df):
        self.beginResetModel()
        self._df = df
        self.endResetModel()

    def rowCount(self, parent=QModelIndex()):
        return len(self._df)

    def columnCount(self, parent=QModelIndex()):
        if not self._df.empty:
            return len(self._df.columns)
        return 0

    def data(self, index, role=Qt.DisplayRole):
        if index.isValid():
            value = self._df.iloc[index.row(), index.column()]
            if role == Qt.DisplayRole:
                return str(value)
        return None

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if self._df.empty:
            return None
        if role == Qt.DisplayRole:
            if orientation == Qt.Horizontal:
                return self._df.columns[section]
            else:
                return section
        return None

