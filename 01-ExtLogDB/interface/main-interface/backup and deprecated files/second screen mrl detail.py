from PySide6.QtWidgets import QMainWindow, QMessageBox
from PySide6.QtUiTools import QUiLoader
from PySide6.QtCore import QFile
from PySide6.QtGui import QStandardItemModel, QStandardItem

class MRLDetailWindow(QMainWindow):
    def __init__(self, db_manager, order_line_item_id):
        super().__init__()
        self.db_manager = db_manager
        self.order_line_item_id = order_line_item_id
        self.load_ui()
        self.setup_models()
        self.connect_signals()
        self.load_mrl_data()

    def load_ui(self):
        loader = QUiLoader()
        ui_file = QFile("mrl_detail_window.ui")
        ui_file.open(QFile.ReadOnly)
        self.ui = loader.load(ui_file, self)
        ui_file.close()

    def setup_models(self):
        self.fulfillment_model = QStandardItemModel()
        self.ui.fulfillmentTable.setModel(self.fulfillment_model)
        
        self.history_model = QStandardItemModel()
        self.ui.historyTable.setModel(self.history_model)
        
        self.reports_model = QStandardItemModel()
        self.ui.reportsTable.setModel(self.reports_model)

    def connect_signals(self):
        self.ui.saveButton.clicked.connect(self.save_changes)
        self.ui.closeButton.clicked.connect(self.close)
        self.ui.addCommentButton.clicked.connect(self.add_comment)
        self.ui.fulfillmentTable.doubleClicked.connect(self.open_fulfillment_detail)

    def load_mrl_data(self):
        mrl_data = self.db_manager.get_mrl_details(self.order_line_item_id)
        if mrl_data:
            self.ui.jcnEdit.setText(mrl_data['jcn'])
            self.ui.twcodeEdit.setText(mrl_data['twcode'])
            self.ui.niinEdit.setText(mrl_data['niin'])
            self.ui.partNoEdit.setText(mrl_data['part_no'])
            self.ui.nomenclatureEdit.setText(mrl_data['nomenclature'])
            # Set more fields as needed
            
            self.load_fulfillment_records()
            self.load_comments()
            self.load_history()
            self.load_linked_reports()

    def load_fulfillment_records(self):
        fulfillment_records = self.db_manager.get_fulfillment_records(self.order_line_item_id)
        self.fulfillment_model.clear()
        self.fulfillment_model.setHorizontalHeaderLabels(['ID', 'Status', 'Date', 'Location'])
        for record in fulfillment_records:
            self.fulfillment_model.appendRow([QStandardItem(str(item)) for item in record])

    def load_comments(self):
        comments = self.db_manager.get_mrl_comments(self.order_line_item_id)
        self.ui.commentsTextEdit.setPlainText("\n\n".join(comments))

    def load_history(self):
        history = self.db_manager.get_mrl_history(self.order_line_item_id)
        self.history_model.clear()
        self.history_model.setHorizontalHeaderLabels(['Date', 'User', 'Action', 'Details'])
        for entry in history:
            self.history_model.appendRow([QStandardItem(str(item)) for item in entry])

    def load_linked_reports(self):
        reports = self.db_manager.get_linked_reports(self.order_line_item_id)
        self.reports_model.clear()
        self.reports_model.setHorizontalHeaderLabels(['Report ID', 'Date', 'Type', 'Description'])
        for report in reports:
            self.reports_model.appendRow([QStandardItem(str(item)) for item in report])

    def save_changes(self):
        # Collect changes from UI fields
        updated_data = {
            'jcn': self.ui.jcnEdit.text(),
            'twcode': self.ui.twcodeEdit.text(),
            'niin': self.ui.niinEdit.text(),
            'part_no': self.ui.partNoEdit.text(),
            'nomenclature': self.ui.nomenclatureEdit.text(),
            # Add more fields as needed
        }
        success = self.db_manager.update_mrl_record(self.order_line_item_id, updated_data)
        if success:
            QMessageBox.information(self, "Success", "MRL record updated successfully.")
        else:
            QMessageBox.warning(self, "Error", "Failed to update MRL record.")

    def add_comment(self):
        comment = self.ui.commentsTextEdit.toPlainText()
        success = self.db_manager.add_mrl_comment(self.order_line_item_id, comment)
        if success:
            self.load_comments()
            QMessageBox.information(self, "Success", "Comment added successfully.")
        else:
            QMessageBox.warning(self, "Error", "Failed to add comment.")

    def open_fulfillment_detail(self, index):
        fulfillment_id = self.fulfillment_model.item(index.row(), 0).text()
        # Implement opening the Fulfillment Detail window
        print(f"Opening Fulfillment Detail with ID: {fulfillment_id}")

# In your database manager class:
class DatabaseManager:
    def get_mrl_details(self, order_line_item_id):
        # Implement fetching MRL details
        pass

    def get_fulfillment_records(self, order_line_item_id):
        # Implement fetching associated fulfillment records
        pass

    def get_mrl_comments(self, order_line_item_id):
        # Implement fetching comments
        pass

    def get_mrl_history(self, order_line_item_id):
        # Implement fetching history
        pass

    def get_linked_reports(self, order_line_item_id):
        # Implement fetching linked reports
        pass

    def update_mrl_record(self, order_line_item_id, updated_data):
        # Implement updating MRL record
        pass

    def add_mrl_comment(self, order_line_item_id, comment):
        # Implement adding a new comment
        pass