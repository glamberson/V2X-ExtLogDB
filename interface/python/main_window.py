# main_window.py

import sys
import json
import logging
from PySide6.QtWidgets import (
    QMainWindow, QMessageBox, QApplication, QListWidgetItem, QDialog,
    QWidget, QVBoxLayout, QLabel
)
from PySide6.QtCore import QFile, QSettings
from config import APP_NAME, COMPANY_NAME
from search_window import SearchWindow
from mrl_detail_window import MRLDetailWindow
from bulk_operations_window import BulkOperationsWindow
from configuration_dialog import ConfigurationDialog

class MainWindow(QMainWindow):
    def __init__(self, db_manager, loader):
        super(MainWindow, self).__init__()
        logging.debug("MainWindow __init__ started")
        self.db_manager = db_manager
        self.settings = QSettings(COMPANY_NAME, APP_NAME)

        try:
            self.setup_logging()
            logging.debug("Starting MainWindow initialization.")

            # Load the UI file using the passed loader
            logging.debug("Creating QFile for main_window.ui")
            ui_file = QFile("main_window.ui")
            logging.debug(f"Checking if UI file exists: {ui_file.exists()}")
            if not ui_file.exists():
                raise FileNotFoundError("The UI file 'main_window.ui' was not found.")
            logging.debug("Opening UI file")
            ui_file.open(QFile.ReadOnly)
            logging.debug("Loading UI file")
            self.ui = loader.load(ui_file, self)
            logging.debug("Closing UI file")
            ui_file.close()
            if self.ui is None:
                raise RuntimeError("Failed to load the UI file 'main_window.ui'.")
            logging.debug("UI file loaded successfully.")

            # Set up main UI elements
            self.setup_main_ui()

            # Connect signals
            self.connect_signals()

        except Exception as e:
            logging.exception(f"Exception occurred in MainWindow __init__: {e}")
            QMessageBox.critical(self, "Error",
                                 f"An error occurred while initializing the main window:\n{str(e)}")
            raise

        logging.debug("MainWindow initialization completed")

    def setup_main_ui(self):
        try:
            self.setWindowTitle(self.ui.windowTitle())
            
            # Instead of setting the entire UI as the central widget,
            # set the centralwidget from the UI file as the central widget
            if hasattr(self.ui, 'centralwidget'):
                self.setCentralWidget(self.ui.centralwidget)
            else:
                logging.warning("No centralwidget found in the UI file")
            
            # Set up the menu bar
            if hasattr(self.ui, 'menubar'):
                self.setMenuBar(self.ui.menubar)
            else:
                logging.warning("No menubar found in the UI file")
            
            # Set up the status bar
            if hasattr(self.ui, 'statusbar'):
                self.setStatusBar(self.ui.statusbar)
            else:
                logging.warning("No statusbar found in the UI file")
            
            # Update user info label
            if hasattr(self.ui, 'userInfoLabel'):
                self.ui.userInfoLabel.setText(f"User: {self.db_manager.user_id} | Role: {self.db_manager.db_role_name}")
            else:
                logging.warning("No userInfoLabel found in the UI file")
            
            logging.debug("Main UI setup complete")
        except Exception as e:
            logging.error(f"Error in setup_main_ui: {e}")
            raise

    def connect_signals(self):
        try:
            if hasattr(self.ui, 'openSearchWindowButton'):
                self.ui.openSearchWindowButton.clicked.connect(self.open_search_window)
            if hasattr(self.ui, 'openNewMRLWindowButton'):
                self.ui.openNewMRLWindowButton.clicked.connect(self.open_new_mrl_window)
            if hasattr(self.ui, 'openBulkOperationsWindowButton'):
                self.ui.openBulkOperationsWindowButton.clicked.connect(self.open_bulk_operations_window)
            if hasattr(self.ui, 'configurationButton'):  # Add this line
                self.ui.configurationButton.clicked.connect(self.open_configuration_dialog)  # And this line
            if hasattr(self.ui, 'menuSettings'):
                self.ui.menuSettings.actions()[0].triggered.connect(self.open_configuration_dialog)
            if hasattr(self.ui, 'openWindowsList'):
                self.ui.openWindowsList.itemDoubleClicked.connect(self.focus_window)
            logging.debug("Signals connected successfully.")
        except AttributeError as e:
            logging.error(f"AttributeError in connect_signals: {e}")
            raise

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
                "password": self.settings.value("db_password", "FOTS-Egypt")
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
        if hasattr(QApplication.instance(), 'open_windows'):
            QApplication.instance().open_windows.append(search_window)
        else:
            logging.warning("QApplication instance does not have 'open_windows' attribute")
        search_window.window_closed.connect(lambda: self.remove_window_from_app_list(search_window))
        self.add_window_to_list(search_window, "Search Window")

    def open_new_mrl_window(self):
        mrl_window = MRLDetailWindow(self.db_manager)
        mrl_window.show()
        if hasattr(QApplication.instance(), 'open_windows'):
            QApplication.instance().open_windows.append(mrl_window)
        else:
            logging.warning("QApplication instance does not have 'open_windows' attribute")
        mrl_window.window_closed.connect(lambda: self.remove_window_from_app_list(mrl_window))
        self.add_window_to_list(mrl_window, "New MRL Line Item")

    def open_bulk_operations_window(self):
        bulk_window = BulkOperationsWindow(self.db_manager)
        bulk_window.show()
        if hasattr(QApplication.instance(), 'open_windows'):
            QApplication.instance().open_windows.append(bulk_window)
        else:
            logging.warning("QApplication instance does not have 'open_windows' attribute")
        bulk_window.window_closed.connect(lambda: self.remove_window_from_app_list(bulk_window))
        self.add_window_to_list(bulk_window, "Bulk Operations")

    def add_window_to_list(self, window, title):
        item = QListWidgetItem(title)
        item.setData(256, window)  # Store the window reference
        self.ui.openWindowsList.addItem(item)
        window.window_closed.connect(lambda: self.remove_window_from_list(item))

    def remove_window_from_app_list(self, window):
        if hasattr(QApplication.instance(), 'open_windows'):
            if window in QApplication.instance().open_windows:
                QApplication.instance().open_windows.remove(window)
        else:
            logging.warning("QApplication instance does not have 'open_windows' attribute")

    def remove_window_from_list(self, item):
        row = self.ui.openWindowsList.row(item)
        self.ui.openWindowsList.takeItem(row)

    def focus_window(self, item):
        window = item.data(256)
        if window:
            window.activateWindow()
            window.raise_()
