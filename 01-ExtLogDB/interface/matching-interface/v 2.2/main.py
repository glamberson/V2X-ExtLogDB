# main.py
import sys
from PySide6.QtWidgets import QApplication
from ui.main_window import MainWindow
from utils.logging_config import get_logger

def main():
    logger = get_logger(__name__)
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    logger = get_logger(__name__)
    try:
        main()
    except Exception as e:
        logger.exception("An unhandled exception occurred: %s", e)
        sys.exit(1)