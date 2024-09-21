import sys
import logging
from PySide6.QtUiTools import QUiLoader
from PySide6.QtWidgets import QApplication, QMessageBox, QDialog
from database_manager import DatabaseManager
from login_dialog import LoginDialog
from main_window import MainWindow

def main():
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
    loader = QUiLoader()
    app = QApplication(sys.argv)
    
    db_manager = DatabaseManager()
    if not db_manager.connect():
        logging.error("Failed to connect to the database.")
        QMessageBox.critical(None, "Database Error", "Failed to connect to the database.")
        sys.exit(1)
    else:
        logging.debug("Database connection established.")

    login_dialog = LoginDialog(db_manager)
    result = login_dialog.exec()
    logging.debug(f"Login dialog returned: {result}")

    if result == QDialog.Accepted:
        logging.debug("Login successful, launching main window.")
        window = MainWindow(db_manager)
        window.show()
        logging.debug("Main window shown.")
        sys.exit(app.exec())
    else:
        logging.debug("Login canceled or failed.")
        sys.exit(0)

if __name__ == "__main__":
    main()
