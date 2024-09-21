from PySide6.QtWidgets import QMainWindow, QMessageBox
from PySide6.QtUiTools import QUiLoader
from PySide6.QtCore import QFile, Qt
from PySide6.QtGui import QStandardItemModel, QStandardItem

class SearchWindow(QMainWindow):
    def __init__(self, db_manager):
        super().__init__()
        self.db_manager = db_manager
        self.load_ui()
        self.connect_signals()
        self.setup_models()
        self.current_offset = 0
        self.batch_size = 100
        self.total_records = 0

    def load_ui(self):
        loader = QUiLoader()
        ui_file = QFile("search_window.ui")
        ui_file.open(QFile.ReadOnly)
        self.ui = loader.load(ui_file, self)
        ui_file.close()

    def connect_signals(self):
        self.ui.searchButton.clicked.connect(self.perform_search)
        self.ui.clearButton.clicked.connect(self.clear_fields)
        self.ui.loadMoreButton.clicked.connect(self.load_more_results)
        self.ui.exportResultsButton.clicked.connect(self.export_results)
        self.ui.resultsTable.doubleClicked.connect(self.open_mrl_line_item)

    def setup_models(self):
        self.results_model = QStandardItemModel()
        self.ui.resultsTable.setModel(self.results_model)

    def perform_search(self):
        self.current_offset = 0
        self.load_results()

    def load_results(self):
        self.ui.loadingIndicator.setText("Loading...")
        conditions = self.build_search_conditions()
        results, self.total_records = self.db_manager.search_records(
            conditions, self.current_offset, self.batch_size)
        self.update_results_table(results)
        self.update_result_count()
        self.ui.loadingIndicator.setText("")

    def build_search_conditions(self):
        conditions = []
        fields = [
            ('jcn', self.ui.jcnEdit),
            ('niin', self.ui.niinEdit),
            ('part_no', self.ui.partNoEdit),
            ('twcode', self.ui.twcodeEdit),
            ('swlin', self.ui.swlinEdit),
            ('nomenclature', self.ui.nomenclatureEdit),
            ('availability_identifier', self.ui.availabilityIdentifierEdit)
        ]
        
        for field, edit in fields:
            value = edit.text().strip()
            if value:
                tokens = value.replace('*', '%').split('%')
                for token in tokens:
                    if token:
                        if field == 'availability_identifier':
                            conditions.append(f"CAST({field} AS TEXT) ILIKE '%{token}%'")
                        else:
                            conditions.append(f"{field} ILIKE '%{token}%'")
        
        return conditions

    def clear_fields(self):
        fields = [
            self.ui.jcnEdit, self.ui.niinEdit, self.ui.partNoEdit,
            self.ui.twcodeEdit, self.ui.swlinEdit, self.ui.nomenclatureEdit,
            self.ui.availabilityIdentifierEdit
        ]
        for field in fields:
            field.clear()
        self.perform_search()

    def load_more_results(self):
        self.current_offset += self.batch_size
        self.load_results()

    def update_results_table(self, results):
        if self.current_offset == 0:
            self.results_model.clear()
            self.results_model.setHorizontalHeaderLabels([
                'Order Line Item ID', 'JCN', 'TWCODE', 'NIIN', 'Part No', 
                'SWLIN', 'Nomenclature', 'Availability Identifier'
            ])

        for row in results:
            self.results_model.appendRow([QStandardItem(str(item)) for item in row])

    def update_result_count(self):
        self.ui.resultCountLabel.setText(f"Showing {self.results_model.rowCount()} of {self.total_records} records")

    def export_results(self):
        # Implement export functionality
        pass

    def open_mrl_line_item(self, index):
        order_line_item_id = self.results_model.item(index.row(), 0).text()
        # Implement opening the MRL Line Item form with the selected ID
        print(f"Opening MRL Line Item with ID: {order_line_item_id}")

# In your database manager class:
class DatabaseManager:
    def search_records(self, conditions, offset, limit):
        try:
            query = f"""
                SELECT order_line_item_id, jcn, twcode, niin, part_no, swlin, nomenclature, availability_identifier
                FROM combined_line_items_fulfillments_search_view
                WHERE 1=1
            """
            if conditions:
                query += " AND " + " AND ".join(conditions)
            query += f" LIMIT {limit} OFFSET {offset}"

            with self.connection.cursor() as cursor:
                cursor.execute(query)
                results = cursor.fetchall()

                # Get total count
                count_query = f"""
                    SELECT COUNT(*) FROM combined_line_items_fulfillments_search_view
                    WHERE 1=1 {' AND ' + ' AND '.join(conditions) if conditions else ''}
                """
                cursor.execute(count_query)
                total_count = cursor.fetchone()[0]

            return results, total_count
        except Exception as e:
            print(f"Database error: {e}")
            return [], 0