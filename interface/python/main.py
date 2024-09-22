# main.py

import sys
import logging
from PySide6.QtWidgets import QApplication, QMessageBox, QDialog
from PySide6.QtCore import QSettings
from database_manager import DatabaseManager
from login_dialog import LoginDialog
from main_window import MainWindow
from configuration_dialog import ConfigurationDialog
from config import APP_NAME, COMPANY_NAME

class MyApp(QApplication):
    def __init__(self, sys_argv):
        super(MyApp, self).__init__(sys_argv)
        self.open_windows = []
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

        # Load or set database configuration
        self.settings = QSettings(COMPANY_NAME, APP_NAME)
        self.db_config = self.load_db_config()

        # Show configuration dialog
        config_dialog = ConfigurationDialog()
        result = config_dialog.exec()
        if result == QDialog.Accepted:
            self.db_config = self.load_db_config()
        else:
            logging.debug("Configuration canceled.")
            sys.exit(0)

        # Database connection
        self.db_manager = DatabaseManager(self.db_config)
        if not self.db_manager.connect():
            logging.error("Failed to connect to the database.")
            QMessageBox.critical(None, "Database Error", "Failed to connect to the database.")
            sys.exit(1)
        else:
            logging.debug("Database connection established.")

        # Show login dialog
        self.login_dialog = LoginDialog(self.db_manager)
        result = self.login_dialog.exec()
        logging.debug(f"Login dialog returned: {result}")

        if result == QDialog.Accepted:
            logging.debug("Login successful, launching main window.")
            self.main_window = MainWindow(self.db_manager)
            self.main_window.show()
            logging.debug("Main window shown.")
        else:
            logging.debug("Login canceled or failed.")
            sys.exit(0)

    def load_db_config(self):
        return {
            "host": self.settings.value("db_host", "localhost"),
            "port": int(self.settings.value("db_port", "5432")),
            "database": self.settings.value("db_name", "ExtLogDB"),
            "user": self.settings.value("db_user", "login"),
            "password": self.settings.value("db_password", "")
        }

if __name__ == '__main__':
    app = MyApp(sys.argv)
    sys.exit(app.exec())
