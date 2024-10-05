# main.py

import sys
import logging
from PySide6.QtWidgets import QApplication, QMessageBox, QDialog
from PySide6.QtCore import QSettings, QTimer
from PySide6.QtUiTools import QUiLoader
from database_manager import DatabaseManager
from login_dialog import LoginDialog
from main_window import MainWindow
from configuration_dialog import ConfigurationDialog
from config import APP_NAME, COMPANY_NAME

# Create QUiLoader instance before QApplication
loader = QUiLoader()

def main():
    app = QApplication(sys.argv)
    app.open_windows = []

    # Configure logging
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('app.log', mode='w'),
            logging.StreamHandler(sys.stdout)
        ]
    )
    logging.debug("Starting application.")

    settings = QSettings(COMPANY_NAME, APP_NAME)

    # Start the main application logic
    if not is_db_configured(settings):
        logging.debug("Database configuration is not set. Showing configuration dialog.")
        # Show configuration dialog
        config_dialog = ConfigurationDialog()
        result = config_dialog.exec()
        logging.debug(f"ConfigurationDialog exec() returned: {result}")
        if result == QDialog.Accepted:
            logging.debug("Database configuration saved.")
            # Reload settings
            settings.sync()
        else:
            logging.debug("Configuration canceled.")
            sys.exit(0)

    # Load database configuration
    db_config = load_db_config(settings)
    logging.debug(f"Database configuration loaded: {db_config}")

    # Attempt database connection
    connected = False
    while not connected:
        db_manager = DatabaseManager(db_config)
        if not db_manager.connect():
            logging.error("Failed to connect to the database.")
            reply = QMessageBox.question(
                None,
                "Database Error",
                "Failed to connect to the database.\nWould you like to adjust the settings?",
                QMessageBox.Yes | QMessageBox.No,
                QMessageBox.Yes
            )
            if reply == QMessageBox.Yes:
                # Show configuration dialog again
                config_dialog = ConfigurationDialog()
                result = config_dialog.exec()
                logging.debug(f"ConfigurationDialog exec() returned: {result}")
                if result == QDialog.Accepted:
                    logging.debug("Database configuration updated.")
                    db_config = load_db_config(settings)
                    logging.debug(f"New database configuration: {db_config}")
                else:
                    logging.debug("Configuration canceled.")
                    sys.exit(0)
            else:
                sys.exit(1)
        else:
            logging.debug("Database connection established.")
            connected = True

    # Show login dialog
    login_dialog = LoginDialog(db_manager)
    result = login_dialog.exec()
    logging.debug(f"Login dialog returned: {result}")

    if result == QDialog.Accepted:
        logging.debug("Login successful, launching main window.")
        try:
            logging.debug("Creating MainWindow instance")
            main_window = MainWindow(db_manager, loader)  # Pass the loader to MainWindow
            logging.debug("MainWindow instance created")
            
            logging.debug("Scheduling MainWindow show")
            QTimer.singleShot(100, main_window.show)
            logging.debug("Main window show scheduled.")
            
            logging.debug("Starting application event loop")
            return_code = app.exec()
            logging.debug(f"Application event loop finished with code: {return_code}")
            sys.exit(return_code)
        except Exception as e:
            logging.exception(f"Error creating or showing MainWindow: {e}")
            QMessageBox.critical(None, "Error", f"An error occurred: {str(e)}")
            sys.exit(1)

def is_db_configured(settings):
    required_keys = ["db_host", "db_port", "db_name", "db_user", "db_password"]
    defaults = {
        "db_host": "localhost",
        "db_port": "5432",
        "db_name": "ExtLogDB",
        "db_user": "login",
        "db_password": "FOTS-Egypt"
    }
    for key in required_keys:
        if not settings.value(key):
            settings.setValue(key, defaults[key])
    settings.sync()
    return True

def load_db_config(settings):
    return {
        "host": settings.value("db_host", "localhost"),
        "port": int(settings.value("db_port", 5432)),
        "database": settings.value("db_name", "ExtLogDB"),
        "user": settings.value("db_user", "login"),
        "password": settings.value("db_password", "FOTS-Egypt")
    }

if __name__ == '__main__':
    main()
