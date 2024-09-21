import logging
from PySide6.QtWidgets import QDialog, QVBoxLayout, QLabel, QLineEdit, QPushButton, QMessageBox

class LoginDialog(QDialog):
    def __init__(self, db_manager, parent=None):
        super().__init__(parent)
        self.db_manager = db_manager
        self.setup_ui()

    def setup_ui(self):
        self.setWindowTitle("Login")
        layout = QVBoxLayout(self)

        self.username_input = QLineEdit(self)
        self.username_input.setPlaceholderText("Username")
        layout.addWidget(self.username_input)

        self.password_input = QLineEdit(self)
        self.password_input.setPlaceholderText("Password")
        self.password_input.setEchoMode(QLineEdit.Password)
        layout.addWidget(self.password_input)

        login_button = QPushButton("Login", self)
        login_button.clicked.connect(self.try_login)
        layout.addWidget(login_button)

    def try_login(self):
        username = self.username_input.text()
        password = self.password_input.text()

        try:
            logging.debug(f"Attempting login for user {username}.")
            if self.db_manager.login(username, password):
                logging.debug("Login successful in login_dialog.")
                self.accept()
            else:
                logging.debug("Login failed in login_dialog.")
                QMessageBox.warning(self, "Login Failed", "Invalid username or password.")
        except Exception as e:
            logging.error(f"Error during login: {e}")
            QMessageBox.critical(self, "Error", f"An error occurred during login: {str(e)}")
