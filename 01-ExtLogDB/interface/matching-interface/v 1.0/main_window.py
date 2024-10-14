from PySide6.QtWidgets import (QMainWindow, QVBoxLayout, QHBoxLayout, QWidget, 
                               QLabel, QComboBox, QPushButton, QStatusBar, QMessageBox,
                               QTabWidget, QLineEdit, QTextEdit, QFormLayout, QScrollArea,
                               QTableWidget, QTableWidgetItem, QHeaderView, QFileDialog,
                               QCheckBox, QButtonGroup, QRadioButton, QSizePolicy)
from PySide6.QtCore import Slot, Qt, QSettings
from PySide6.QtGui import QColor
from database import DatabaseConnection
import logging
import csv
from matching_detail_window import MatchingDetailWindow

logger = logging.getLogger(__name__)

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Report Record Matching Tool")
        self.setGeometry(100, 100, 1200, 800)

        self.db = DatabaseConnection()
        self.report_name_combo = None
        self.sheet_name_combo = None
        self.column_names = self.db.get_column_names()

        self.init_ui()
        self.populate_report_names()

    def init_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)

        # Report Selection Section
        report_selection_layout = QHBoxLayout()
        
        report_name_label = QLabel("Report Name:")
        self.report_name_combo = QComboBox()
        
        sheet_name_label = QLabel("Sheet Name:")
        self.sheet_name_combo = QComboBox()
        
        load_button = QPushButton("Load Report")
        load_button.clicked.connect(self.load_report)

        report_selection_layout.addWidget(report_name_label)
        report_selection_layout.addWidget(self.report_name_combo)
        report_selection_layout.addWidget(sheet_name_label)
        report_selection_layout.addWidget(self.sheet_name_combo)
        report_selection_layout.addWidget(load_button)

        main_layout.addLayout(report_selection_layout)

        # Record Filtering Section
        self.filtering_tab_widget = QTabWidget()
        self.filtering_tab_widget.setMaximumHeight(200)
        main_layout.addWidget(self.filtering_tab_widget)

        # Custom Field Filters Tab
        custom_filter_widget = QWidget()
        custom_filter_layout = QVBoxLayout(custom_filter_widget)
        self.create_custom_filter_ui(custom_filter_layout)
        self.filtering_tab_widget.addTab(custom_filter_widget, "Custom Field Filters")

        # Preset Filters Tab
        preset_filter_widget = QWidget()
        preset_filter_layout = QVBoxLayout(preset_filter_widget)
        self.create_preset_filter_ui(preset_filter_layout)
        self.filtering_tab_widget.addTab(preset_filter_widget, "Preset Filters")

        # SQL Query Tab
        sql_query_widget = QWidget()
        sql_query_layout = QVBoxLayout(sql_query_widget)
        self.create_sql_query_ui(sql_query_layout)
        self.filtering_tab_widget.addTab(sql_query_widget, "SQL Query")

        # Results Display Section
        results_widget = QWidget()
        results_layout = QVBoxLayout(results_widget)
        self.create_results_display_ui(results_layout)
        main_layout.addWidget(results_widget)

        # Add Find Matches button
        self.find_matches_button = QPushButton("Find Matches")
        self.find_matches_button.clicked.connect(self.find_matches)
        main_layout.addWidget(self.find_matches_button)

        # Status Bar
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)

    def create_custom_filter_ui(self, layout):
        scroll_area = QScrollArea()
        scroll_widget = QWidget()
        scroll_layout = QVBoxLayout(scroll_widget)

        default_fields = ['jcn', 'twcode', 'nomenclature', 'niin', 'part_no']
        self.custom_filter_rows = []

        for field in default_fields:
            filter_row = self.create_filter_row(field)
            scroll_layout.addLayout(filter_row)
            self.custom_filter_rows.append(filter_row)

        add_filter_button = QPushButton("Add Filter")
        add_filter_button.clicked.connect(self.add_custom_filter_row)
        scroll_layout.addWidget(add_filter_button)

        scroll_area.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        scroll_area.setWidget(scroll_widget)
        scroll_area.setWidgetResizable(True)
        layout.addWidget(scroll_area)

        # Add mrl_processed and fulfillment_processed filter options
        process_layout = QHBoxLayout()
        process_layout.addWidget(QLabel("MRL Processed:"))
        self.mrl_processed_group = QButtonGroup(self)
        for option in ["All", "Yes", "No"]:
            radio = QRadioButton(option)
            self.mrl_processed_group.addButton(radio)
            process_layout.addWidget(radio)
        process_layout.addSpacing(20)
        process_layout.addWidget(QLabel("Fulfillment Processed:"))
        self.fulfillment_processed_group = QButtonGroup(self)
        for option in ["All", "Yes", "No"]:
            radio = QRadioButton(option)
            self.fulfillment_processed_group.addButton(radio)
            process_layout.addWidget(radio)
        process_layout.addStretch(1)
        layout.addLayout(process_layout)

        apply_filters_button = QPushButton("Apply Filters")
        apply_filters_button.clicked.connect(self.apply_custom_filters)
        layout.addWidget(apply_filters_button)

        # Make the main window resizable
        self.setMinimumSize(1000, 600)
        self.resize(1200, 800)

    def create_filter_row(self, default_field=None):
        row_layout = QHBoxLayout()
        field_combo = QComboBox()
        field_combo.addItems(self.column_names)
        if default_field:
            field_combo.setCurrentText(default_field)
        operation_combo = QComboBox()
        operation_combo.addItems(['contains', 'starts with', 'ends with', 'equals', 'is null', 'is not null'])
        value_input = QLineEdit()
        value_input.returnPressed.connect(self.apply_custom_filters)

        row_layout.addWidget(field_combo)
        row_layout.addWidget(operation_combo)
        row_layout.addWidget(value_input)

        return row_layout

    def add_custom_filter_row(self):
        new_row = self.create_filter_row()
        self.custom_filter_rows.append(new_row)
        self.findChild(QScrollArea).widget().layout().addLayout(new_row)

    def create_preset_filter_ui(self, layout):
        preset_combo = QComboBox()
        preset_combo.addItems(["Filter 1", "Filter 2", "Filter 3"])  # Add your preset filters here
        layout.addWidget(QLabel("Select Preset Filter:"))
        layout.addWidget(preset_combo)

        description_label = QLabel("Filter Description:")
        layout.addWidget(description_label)

        apply_preset_button = QPushButton("Apply Preset Filter")
        apply_preset_button.clicked.connect(self.apply_preset_filter)
        layout.addWidget(apply_preset_button)

    def create_sql_query_ui(self, layout):
        self.sql_query_text = QTextEdit()
        self.sql_query_text.setMaximumHeight(100)  # Limit the height of the text edit
        layout.addWidget(QLabel("Enter SQL Query:"))
        layout.addWidget(self.sql_query_text)

        button_layout = QHBoxLayout()
        validate_button = QPushButton("Validate SQL")
        validate_button.clicked.connect(self.validate_sql)
        button_layout.addWidget(validate_button)

        apply_sql_button = QPushButton("Apply SQL Query")
        apply_sql_button.clicked.connect(self.apply_sql_query)
        button_layout.addWidget(apply_sql_button)

        layout.addLayout(button_layout)

    def create_results_display_ui(self, layout):
        top_layout = QHBoxLayout()
        self.record_count_label = QLabel("Records: 0")
        top_layout.addWidget(self.record_count_label)
        
        self.select_all_button = QPushButton("Select All/None")
        self.select_all_button.setCheckable(True)
        self.select_all_button.clicked.connect(self.toggle_all_selections)
        top_layout.addWidget(self.select_all_button)
        
        layout.addLayout(top_layout)
        # Create the table widget
        self.results_table = QTableWidget()
        self.results_table.setColumnCount(len(self.column_names) + 1)
        headers = ['Select'] + self.column_names
        self.results_table.setHorizontalHeaderLabels(headers)
        self.results_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeToContents)
        self.results_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.Interactive)
        self.results_table.setColumnWidth(1, 50)  # Set initial width for staged_id
        for i in range(2, len(self.column_names) + 1):
            self.results_table.horizontalHeader().setSectionResizeMode(i, QHeaderView.Interactive)
        self.load_column_widths()
        layout.addWidget(self.results_table)
        self.results_table.horizontalHeader().sectionResized.connect(self.save_column_widths)

        # Add export button
        export_button = QPushButton("Export to CSV")
        export_button.clicked.connect(self.export_to_csv)
        layout.addWidget(export_button)

    def display_results(self, data):
        self.results_table.setRowCount(len(data))
        for row, record in enumerate(data):
            checkbox = QCheckBox()
            self.results_table.setCellWidget(row, 0, checkbox)
            
            for col, value in enumerate(record):
                display_value = '' if value is None else str(value)
                self.results_table.setItem(row, col + 1, QTableWidgetItem(display_value))
        
        self.record_count_label.setText(f"Records: {len(data)}")

    def populate_report_names(self):
        names = self.db.get_report_names()
        logger.debug(f"Populating report names: {names}")
        if not names:
            self.show_error("No reports found in the database.")
            return
        self.report_name_combo.addItems(names)
        self.report_name_combo.currentTextChanged.connect(self.update_sheet_names)
        # Trigger the sheet names update for the first item
        self.update_sheet_names(self.report_name_combo.currentText())

    def update_sheet_names(self, selected_name):
        if not hasattr(self, 'sheet_name_combo') or not self.sheet_name_combo:
            logger.error("sheet_name_combo is not initialized")
            return
        self.sheet_name_combo.clear()
        if not selected_name:
            logger.warning("No report name selected")
            return
        sheet_names = self.db.get_sheet_names(selected_name)
        logger.debug(f"Updating sheet names for {selected_name}: {sheet_names}")
        if not sheet_names:
            self.show_error(f"No sheets found for report: {selected_name}")
            return
        self.sheet_name_combo.addItems(sheet_names)

    def get_selected_records(self):
        selected_records = []
        for row in range(self.results_table.rowCount()):
            checkbox = self.results_table.cellWidget(row, 0)
            if isinstance(checkbox, QCheckBox) and checkbox.isChecked():
                record = {self.column_names[i-1]: self.results_table.item(row, i).text() 
                          for i in range(1, len(self.column_names) + 1)}
                selected_records.append(record)
        return selected_records

    def toggle_all_selections(self):
        check_state = Qt.Checked if self.select_all_button.isChecked() else Qt.Unchecked
        for row in range(self.results_table.rowCount()):
            checkbox = self.results_table.cellWidget(row, 0)
            if isinstance(checkbox, QCheckBox):
                checkbox.setChecked(check_state == Qt.Checked)

    def save_column_widths(self):
        settings = QSettings("YourCompany", "ReportMatchingTool")
        for i in range(self.results_table.columnCount()):
            settings.setValue(f"column_width_{i}", self.results_table.columnWidth(i))

    def load_column_widths(self):
        settings = QSettings("YourCompany", "ReportMatchingTool")
        for i in range(self.results_table.columnCount()):
            width = settings.value(f"column_width_{i}", type=int)
            if width:
                self.results_table.setColumnWidth(i, width)

    def closeEvent(self, event):
        self.save_column_widths()
        super().closeEvent(event)

    @Slot()
    def load_report(self):
        selected_name = self.report_name_combo.currentText()
        selected_sheet = self.sheet_name_combo.currentText()
        if not selected_name or not selected_sheet:
            self.show_error("Please select both a report and a sheet.")
            return
        logger.info(f"Loading report: {selected_name}, sheet: {selected_sheet}")
        self.status_bar.showMessage(f"Loading report: {selected_name}, sheet: {selected_sheet}")
        
        # Fetch data from the database
        data = self.db.get_report_data(selected_name, selected_sheet)
        self.display_results(data)  # Call display_results here

    @Slot()
    def find_matches(self):
        selected_records = self.get_selected_records()
        if not selected_records:
            self.show_error("Please select at least one record to match.")
            return
        
        try:
            potential_matches = self.db.find_potential_matches(selected_records)
            if not potential_matches:
                self.show_error("No potential matches found.")
            else:
                # Get the report_date from the first selected record
                report_date = selected_records[0]['report_date']
                report_info = {
                    'report_name': self.report_name_combo.currentText(),
                    'report_date': report_date,
                    'sheet_name': self.sheet_name_combo.currentText()
                }
                self.open_matching_detail_window(potential_matches, report_info)
        except Exception as e:
            logger.error(f"Error finding matches: {str(e)}", exc_info=True)
            self.show_error(f"An error occurred while finding matches: {str(e)}")

    def open_matching_detail_window(self, potential_matches, report_info):
        if not hasattr(self, 'matching_detail_window') or not self.matching_detail_window.isVisible():
            self.matching_detail_window = MatchingDetailWindow(potential_matches, self.db, report_info)
            self.matching_detail_window.matches_applied.connect(self.process_applied_matches)
            self.matching_detail_window.show()
        else:
            self.matching_detail_window.raise_()
            self.matching_detail_window.activateWindow()

    def get_report_date(self):
        # Implement this method to return the report date
        # You might need to add a date picker or extract the date from the report name
        pass

    def process_applied_matches(self, accepted_matches):
        # Process the accepted matches here
        print(f"Received {len(accepted_matches)} accepted matches")
        # Implement your logic to handle the accepted matches

    @Slot()
    def apply_custom_filters(self):
        filters = []
        for row in self.custom_filter_rows:
            field = row.itemAt(0).widget().currentText()
            operation = row.itemAt(1).widget().currentText()
            value = row.itemAt(2).widget().text()
            filters.append((field, operation, value))
        
        # Add MRL processed filter
        mrl_processed = next((btn for btn in self.mrl_processed_group.buttons() if btn.isChecked()), None)
        if mrl_processed and mrl_processed.text() != "All":
            filters.append(('mrl_processed', 'equals', mrl_processed.text()))

        # Add Fulfillment processed filter
        fulfillment_processed = next((btn for btn in self.fulfillment_processed_group.buttons() if btn.isChecked()), None)
        if fulfillment_processed and fulfillment_processed.text() != "All":
            filters.append(('fulfillment_processed', 'equals', fulfillment_processed.text()))

        logger.info(f"Applying custom filters: {filters}")
        self.status_bar.showMessage("Applying custom filters...")
        
        # Get the current report and sheet
        selected_name = self.report_name_combo.currentText()
        selected_sheet = self.sheet_name_combo.currentText()
        
        # Apply filters to the database query
        filtered_data = self.db.apply_filters(filters, selected_name, selected_sheet)
        self.display_results(filtered_data)
        
        # Ensure the sheet name remains selected
        index = self.sheet_name_combo.findText(selected_sheet)
        if index >= 0:
            self.sheet_name_combo.setCurrentIndex(index)

    @Slot()
    def apply_preset_filter(self):
        selected_preset = self.sender().parent().findChild(QComboBox).currentText()
        logger.info(f"Applying preset filter: {selected_preset}")
        self.status_bar.showMessage(f"Applying preset filter: {selected_preset}")
        
        # Apply preset filter to the database query
        filtered_data = self.db.apply_preset_filter(selected_preset)
        self.display_results(filtered_data)

    @Slot()
    def validate_sql(self):
        sql_query = self.sql_query_text.toPlainText()
        logger.info(f"Validating SQL query: {sql_query}")
        self.status_bar.showMessage("Validating SQL query...")
        
        # Validate the SQL query
        is_valid, message = self.db.validate_sql(sql_query)
        if is_valid:
            self.status_bar.showMessage("SQL query is valid")
        else:
            self.show_error(f"Invalid SQL query: {message}")

    @Slot()
    def apply_sql_query(self):
        sql_query = self.sql_query_text.toPlainText()
        logger.info(f"Applying SQL query: {sql_query}")
        self.status_bar.showMessage("Applying SQL query...")
        
        # Execute the SQL query
        result = self.db.execute_sql(sql_query)
        self.display_results(result)

    @Slot()
    def export_to_csv(self):
        file_name, _ = QFileDialog.getSaveFileName(self, "Save CSV", "", "CSV Files (*.csv)")
        if file_name:
            with open(file_name, 'w', newline='') as file:
                writer = csv.writer(file)
                headers = [self.results_table.horizontalHeaderItem(i).text() for i in range(self.results_table.columnCount())]
                writer.writerow(headers)
                for row in range(self.results_table.rowCount()):
                    row_data = []
                    for col in range(self.results_table.columnCount()):
                        if col == 0:
                            checkbox = self.results_table.cellWidget(row, col)
                            row_data.append("Checked" if checkbox and checkbox.isChecked() else "Unchecked")
                        else:
                            item = self.results_table.item(row, col)
                            row_data.append(item.text() if item else "")
                    writer.writerow(row_data)
            self.status_bar.showMessage(f"Data exported to {file_name}")

    def show_error(self, message):
        logger.error(message)
        QMessageBox.critical(self, "Error", message)