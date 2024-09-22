# main_window.py

import sys
import json
import logging
from PySide6.QtWidgets import (
    QMainWindow, QMessageBox, QApplication, QListWidgetItem
)
from PySide6.QtCore import QFile, QSettings
from PySide6.QtUiTools import QUiLoader
from config import APP_NAME, COMPANY_NAME
from search_window import SearchWindow
from mrl_detail_window import MRLDetailWindow
from bulk_operations_window import BulkOperationsWindow

class MainWindow(QMainWindow):
    def __init__(self, db_manager):
        super(MainWindow, self).__init__()
        self.db_manager = db_manager
        self.settings = QSettings(COMPANY_NAME, APP_NAME)

        try:
            # Initialize logging
            self.setup_logging()
            logging.debug("Starting MainWindow initialization.")

            # Load the UI using QUiLoader
            loader = QUiLoader()
            ui_file = QFile("main_window.ui")
            if not ui_file.exists():
                logging.error("The UI file 'main_window.ui' was not found.")
                QMessageBox.critical(None, "Error", "The UI file 'main_window.ui' was not found.")
                sys.exit(1)
            ui_file.open(QFile.ReadOnly)
            self.ui = loader.load(ui_file, self)
            ui_file.close()
            if self.ui is None:
                logging.error("Failed to load UI file. loader.load() returned None.")
                QMessageBox.critical(None, "Error", "Failed to load the UI file 'main_window.ui'.")
                sys.exit(1)
            logging.debug("UI file loaded successfully.")

            # Set the central widget
            self.setCentralWidget(self.ui)
            logging.debug("Central widget set.")

            # Set window title
            self.setWindowTitle(self.ui.windowTitle())

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
            self.ui.openSearchWindowButton.clicked.connect(self.open_search_window)
            logging.debug("Connected 'openSearchWindowButton' signal.")
            self.ui.openNewMRLWindowButton.clicked.connect(self.open_new_mrl_window)
            logging.debug("Connected 'openNewMRLWindowButton' signal.")
            self.ui.openBulkOperationsWindowButton.clicked.connect(self.open_bulk_operations_window)
            logging.debug("Connected 'openBulkOperationsWindowButton' signal.")
            self.ui.actionDatabaseConfiguration.triggered.connect(self.open_configuration_dialog)
            logging.debug("Connected 'Database Configuration' menu action.")
        except AttributeError as e:
            logging.error(f"AttributeError in connect_signals: {e}")
            QMessageBox.critical(self, "Error", f"UI element not found: {str(e)}")
            sys.exit(1)

    def setup_main_ui(self):
        try:
            # Update UI elements based on user role
            self.ui.userInfoLabel.setText(f"User: {self.db_manager.user_id} | Role: {self.db_manager.db_role_name}")
            logging.debug("User information displayed on main UI.")
            # Initialize the open windows list
            self.ui.openWindowsList.itemDoubleClicked.connect(self.focus_window)
        except Exception as e:
            logging.error(f"Error in setup_main_ui: {e}")
            QMessageBox.critical(self, "Error", f"Failed to set up main UI elements:\n{str(e)}")

    def open_configuration_dialog(self):
        config_dialog = ConfigurationDialog()
        result = config_dialog.exec()
        if result == QDialog.Accepted:
            # Reload the configuration
            new_db_config = {
                "host": self.settings.value("db_host", "localhost"),
                "port": int(self.settings.value("db_port", "5432")),
                "database": self.settings.value("db_name", "ExtLogDB"),
                "user": self.settings.value("db_user", "login"),
                "password": self.settings.value("db_password", "")
            }
            # Reconnect the database
            self.db_manager.db_config = new_db_config
            if not self.db_manager.connect():
                logging.error("Failed to reconnect to the database with new settings.")
                QMessageBox.critical(self, "Database Error", "Failed to reconnect to the database with new settings.")
            else:
                logging.debug("Database reconnected with new settings.")
        else:
            logging.debug("Database configuration dialog canceled.")

    def open_search_window(self):
        search_window = SearchWindow(self.db_manager)
        search_window.show()
        QApplication.instance().open_windows.append(search_window)
        search_window.window_closed.connect(lambda: self.remove_window_from_app_list(search_window))
        self.add_window_to_list(search_window, "Search Window")

    def open_new_mrl_window(self):
        mrl_window = MRLDetailWindow(self.db_manager)
        mrl_window.show()
        QApplication.instance().open_windows.append(mrl_window)
        mrl_window.window_closed.connect(lambda: self.remove_window_from_app_list(mrl_window))
        self.add_window_to_list(mrl_window, "New MRL Line Item")

    def open_bulk_operations_window(self):
        bulk_window = BulkOperationsWindow(self.db_manager)
        bulk_window.show()
        QApplication.instance().open_windows.append(bulk_window)
        bulk_window.window_closed.connect(lambda: self.remove_window_from_app_list(bulk_window))
        self.add_window_to_list(bulk_window, "Bulk Operations")

    def add_window_to_list(self, window, title):
        item = QListWidgetItem(title)
        item.setData(256, window)  # Store the window reference
        self.ui.openWindowsList.addItem(item)
        window.window_closed.connect(lambda: self.remove_window_from_list(item))

    def remove_window_from_app_list(self, window):
        if window in QApplication.instance().open_windows:
            QApplication.instance().open_windows.remove(window)

    def remove_window_from_list(self, item):
        row = self.ui.openWindowsList.row(item)
        self.ui.openWindowsList.takeItem(row)

    def focus_window(self, item):
        window = item.data(256)
        if window:
            window.activateWindow()
            window.raise_()
