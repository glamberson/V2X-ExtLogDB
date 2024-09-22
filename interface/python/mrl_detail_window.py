# mrl_detail_window.py

import sys
import logging
from PySide6.QtWidgets import (
    QMainWindow, QMessageBox, QApplication, QTableView, QAbstractItemView
)
from PySide6.QtCore import QFile, QAbstractTableModel, Qt, QModelIndex, Signal
from PySide6.QtUiTools import QUiLoader
import pandas as pd
import psycopg2.extras  # Import RealDictCursor

class MRLDetailWindow(QMainWindow):
    window_closed = Signal()

    def __init__(self, db_manager, order_line_item_id=None, parent=None):
        super(MRLDetailWindow, self).__init__(parent)
        self.db_manager = db_manager
        self.order_line_item_id = order_line_item_id

        try:
            # Load the UI using QUiLoader
            loader = QUiLoader()
            ui_file = QFile("mrl_detail_window.ui")
            if not ui_file.exists():
                logging.error("The UI file 'mrl_detail_window.ui' was not found.")
                QMessageBox.critical(None, "Error", "The UI file 'mrl_detail_window.ui' was not found.")
                return
            ui_file.open(QFile.ReadOnly)
            self.ui = loader.load(ui_file, self)
            ui_file.close()
            if self.ui is None:
                logging.error("Failed to load UI file. loader.load() returned None.")
                QMessageBox.critical(None, "Error", "Failed to load the UI file 'mrl_detail_window.ui'.")
                return
            logging.debug("MRLDetailWindow UI loaded successfully.")

            # Set the central widget
            self.setCentralWidget(self.ui)
            logging.debug("Central widget set for MRLDetailWindow.")

            # Set window title
            self.setWindowTitle(self.ui.windowTitle())

            # Connect signals
            self.connect_signals()
            logging.debug("Signals connected in MRLDetailWindow.")

            # Load data if order_line_item_id is provided
            if self.order_line_item_id is not None:
                self.load_mrl_data()
                self.load_fulfillment_records()

        except Exception as e:
            logging.exception(f"Exception occurred in MRLDetailWindow __init__: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred while initializing the MRL detail window:\n{str(e)}")

    def closeEvent(self, event):
        self.window_closed.emit()
        super(MRLDetailWindow, self).closeEvent(event)
        
    def open_child_window(self):
        child_window = SomeChildWindow(parent=None)
        child_window.show()
        QApplication.instance().open_windows.append(child_window)
        child_window.window_closed.connect(lambda: self.remove_window_from_app_list(child_window))

    def remove_window_from_app_list(self, window):
        QApplication.instance().open_windows.remove(window)    

    def connect_signals(self):
        self.ui.saveButton.clicked.connect(self.save_changes)
        self.ui.closeButton.clicked.connect(self.close)
        # Connect other signals as needed

    def load_mrl_data(self):
        try:
            sql_query = "SELECT * FROM mrl_line_items WHERE order_line_item_id = %s"
            with self.db_manager.connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute(sql_query, (int(self.order_line_item_id),))
                data = cursor.fetchone()
                if data:
                    # Populate the UI fields with data
                    self.ui.jcnEdit.setText(data.get('jcn', ''))
                    self.ui.twcodeEdit.setText(data.get('twcode', ''))
                    self.ui.niinEdit.setText(data.get('niin', ''))
                    self.ui.partNoEdit.setText(data.get('part_no', ''))
                    self.ui.nomenclatureEdit.setText(data.get('nomenclature', ''))
                    # Continue for other fields
                else:
                    QMessageBox.warning(self, "Data Not Found", "No MRL line item found with the provided ID.")
        except Exception as e:
            self.db_manager.connection.rollback()
            logging.exception(f"Error in load_mrl_data: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred while loading MRL data:\n{str(e)}")

    def load_fulfillment_records(self):
        try:
            sql_query = "SELECT * FROM fulfillment_items WHERE order_line_item_id = %s"
            with self.db_manager.connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute(sql_query, (int(self.order_line_item_id),))
                data = cursor.fetchall()
                self.fulfillment_df = pd.DataFrame(data)  # DataFrame from list of dicts
                # Set up the fulfillment table
                self.fulfillment_model = PandasTableModel(self.fulfillment_df)
                self.ui.fulfillmentTable.setModel(self.fulfillment_model)
                self.ui.fulfillmentTable.setSelectionBehavior(QAbstractItemView.SelectRows)
                self.ui.fulfillmentTable.setSelectionMode(QAbstractItemView.SingleSelection)
                self.ui.fulfillmentTable.setAlternatingRowColors(True)
                self.ui.fulfillmentTable.setSortingEnabled(True)
        except Exception as e:
            self.db_manager.connection.rollback()
            logging.exception(f"Error in load_fulfillment_records: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred while loading fulfillment records:\n{str(e)}")

    def save_changes(self):
        try:
            # Collect data from UI fields
            data = {
                'jcn': self.ui.jcnEdit.text(),
                'twcode': self.ui.twcodeEdit.text(),
                'niin': self.ui.niinEdit.text(),
                'part_no': self.ui.partNoEdit.text(),
                'nomenclature': self.ui.nomenclatureEdit.text(),
                # Add other fields as needed
            }
            # Build the update query
            set_clauses = ', '.join([f"{key} = %({key})s" for key in data.keys()])
            sql_query = f"UPDATE mrl_line_items SET {set_clauses} WHERE order_line_item_id = %(order_line_item_id)s"
            data['order_line_item_id'] = int(self.order_line_item_id)
            with self.db_manager.connection.cursor() as cursor:
                cursor.execute(sql_query, data)
                self.db_manager.connection.commit()
            QMessageBox.information(self, "Success", "Changes saved successfully.")
        except Exception as e:
            self.db_manager.connection.rollback()
            logging.exception(f"Error in save_changes: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred while saving changes:\n{str(e)}")

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
