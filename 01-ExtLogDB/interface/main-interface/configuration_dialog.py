# configuration_dialog.py

import logging
from PySide6.QtWidgets import QDialog, QMessageBox, QVBoxLayout
from PySide6.QtUiTools import QUiLoader
from PySide6.QtCore import QFile, QSettings
from config import APP_NAME, COMPANY_NAME

class ConfigurationDialog(QDialog):
    def __init__(self):
        super(ConfigurationDialog, self).__init__()
        self.settings = QSettings(COMPANY_NAME, APP_NAME)
        try:
            logging.debug("Initializing ConfigurationDialog.")
            # Load the UI using QUiLoader
            loader = QUiLoader()
            ui_file = QFile("configuration_dialog.ui")
            if not ui_file.exists():
                logging.error("The UI file 'configuration_dialog.ui' was not found.")
                QMessageBox.critical(self, "Error", "The UI file 'configuration_dialog.ui' was not found.")
                return
            ui_file.open(QFile.ReadOnly)
            self.ui = loader.load(ui_file, None)
            ui_file.close()
            if self.ui is None:
                logging.error("Failed to load UI file. loader.load() returned None.")
                QMessageBox.critical(self, "Error", "Failed to load the UI file 'configuration_dialog.ui'.")
                return
            logging.debug("ConfigurationDialog UI loaded successfully.")

            # Set up the layout
            layout = QVBoxLayout()
            layout.addWidget(self.ui)
            self.setLayout(layout)

            # Set the dialog title
            self.setWindowTitle("Database Configuration")

            # Load saved settings
            self.load_settings()

            # Connect signals
            self.ui.saveButton.clicked.connect(self.save_settings)
            self.ui.cancelButton.clicked.connect(self.reject)
            self.ui.resetButton.clicked.connect(self.reset_to_defaults)

        except Exception as e:
            logging.exception(f"Exception occurred in ConfigurationDialog __init__: {e}")
            QMessageBox.critical(self, "Error",
                                 f"An error occurred while initializing the configuration dialog:\n{str(e)}")

    def save_settings(self):
        # Save settings to QSettings
        self.settings.setValue("db_host", self.ui.hostEdit.text())
        self.settings.setValue("db_port", self.ui.portEdit.text())
        self.settings.setValue("db_name", self.ui.databaseEdit.text())
        self.settings.setValue("db_user", self.ui.userEdit.text())
        self.settings.setValue("db_password", self.ui.passwordEdit.text())
        self.settings.sync()  # Ensure settings are written to storage
        self.accept()

    def load_settings(self):
        # Load settings from QSettings or use defaults
        self.ui.hostEdit.setText(self.settings.value("db_host", "localhost"))
        self.ui.portEdit.setText(self.settings.value("db_port", "5432"))
        self.ui.databaseEdit.setText(self.settings.value("db_name", "ExtLogDB"))
        self.ui.userEdit.setText(self.settings.value("db_user", "login"))
        self.ui.passwordEdit.setText(self.settings.value("db_password", ""))

    def reset_to_defaults(self):
        # Reset fields to default values
        self.ui.hostEdit.setText("localhost")
        self.ui.portEdit.setText("5432")
        self.ui.databaseEdit.setText("ExtLogDB")
        self.ui.userEdit.setText("login")
        self.ui.passwordEdit.setText("")
