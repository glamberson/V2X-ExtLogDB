# ui/matching_detail_window.py
from PySide6.QtWidgets import (
    QMainWindow, QVBoxLayout, QHBoxLayout, QWidget, QPushButton,
    QLabel, QScrollArea, QTabWidget, QComboBox, QLineEdit,
    QTableWidget, QTableWidgetItem, QHeaderView, QCheckBox, QMessageBox,
    QProgressDialog, QFrame, QSizePolicy, QStackedWidget, QGridLayout, QSlider, QMessageBox
)
from PySide6.QtCore import Qt, Signal, Slot
from PySide6.QtGui import QColor, QPalette, QPainter
from PySide6.QtCharts import QChart, QChartView, QPieSeries, QBarSeries, QBarSet, QBarCategoryAxis, QValueAxis
from models.data_models import Match, StagedRecord, MRLRecord
from models.database import DatabaseConnection
from controllers.match_controller import MatchController
from utils.logging_config import get_logger
from Levenshtein import ratio

logger = get_logger(__name__)

def to_pg_array(lst):
    # Escape any special characters and properly format array literals
    escaped_items = [item.replace('"', '\\"').replace("'", "\\'") for item in lst]
    return '{' + ','.join('"%s"' % item for item in escaped_items) + '}'

class MatchingDetailWindow(QMainWindow):
    matches_applied = Signal(list)  # Signal to emit when matches are applied

    def __init__(self, potential_matches, db_connection: DatabaseConnection, report_info):
        super().__init__()
        self.potential_matches = potential_matches

        # Debug logging
        for i, match in enumerate(self.potential_matches):
            logger.debug(f"Match {i + 1}:")
            logger.debug(f"Staged Record: {vars(match.search_record)}")
            logger.debug(f"MRL Record: {vars(match.mrl_record)}")


        self.db = db_connection
        self.report_name = report_info['report_name']
        self.report_date = report_info['report_date']
        self.sheet_name = report_info['sheet_name']
        self.accepted_matches = []
        self.match_selections = {i: False for i in range(len(self.potential_matches))}
        self.match_controller = MatchController(self.db)
        self.current_staged_record = None  # Initialize current_staged_record
        self.main_checkboxes = []
        self.match_widgets = []
        self.init_ui()

    def init_ui(self):
        self.setWindowTitle("Detailed Match View")
        self.setGeometry(150, 150, 1200, 800)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)

        # Add bulk accept controls
        main_layout.addLayout(self.add_bulk_accept_controls())

        # Add Lock Views checkbox
        self.lock_views_checkbox = QCheckBox("Lock Views")
        self.lock_views_checkbox.stateChanged.connect(self.toggle_lock_views)
        main_layout.addWidget(self.lock_views_checkbox)

        # Create tab widget
        self.tab_widget = QTabWidget()
        main_layout.addWidget(self.tab_widget)

        # Create tabs
        self.create_main_view_tab()
        self.create_side_by_side_view_tab()
        self.create_table_view_tab()
        self.create_summary_view_tab()

        # Add apply button
        apply_button = QPushButton("Apply Selections")
        apply_button.clicked.connect(self.apply_selections)
        main_layout.addWidget(apply_button)

    def _bulk_accept_matches(self, match_type):
        """
        Helper method to perform bulk acceptance of matches.
        :param match_type: 'mrl' for MRL-only matches, 'both' for MRL+Fulfillment matches.
        """
        threshold = self.threshold_slider.value()
        logger.info(f"Bulk Accept '{match_type.upper()}' initiated with threshold: {threshold}")

        # Log all potential matches and their statuses
        for idx, match in enumerate(self.potential_matches):
            multiple_fulfillments = match.mrl_record.multiple_fulfillments
            logger.debug(f"Match {idx + 1}: Staged ID = {match.search_record.staged_id}, "
                         f"Score = {match.score}, Multiple Fulfillments: {multiple_fulfillments}")

        # Filter matches based on match type and criteria
        if match_type == 'mrl':
            selected_matches = [
                match for match in self.potential_matches
                if match.score >= threshold
            ]
            logger.info(f"Number of matches meeting threshold: {len(selected_matches)}")
        elif match_type == 'both':
            selected_matches = [
                match for match in self.potential_matches
                if match.score >= threshold and not match.mrl_record.multiple_fulfillments
            ]
            logger.info(f"Number of matches meeting threshold with exactly one fulfillment record: {len(selected_matches)}")
        else:
            logger.error(f"Invalid match type: {match_type}")
            return

        if not selected_matches:
            logger.warning("No matches meet the criteria for bulk acceptance.")
            QMessageBox.information(self, "No Matches", "No matches meet the criteria for bulk acceptance.")
            return

        # Confirm with the user
        match_desc = "MRL matches" if match_type == 'mrl' else "MRL+Fulfillment matches"
        reply = QMessageBox.question(
            self,
            "Confirm Bulk Accept",
            f"Are you sure you want to bulk accept {len(selected_matches)} {match_desc} at a threshold of {threshold}%?",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )

        if reply == QMessageBox.Yes:
            staged_ids = [int(match.search_record.staged_id) for match in selected_matches]
            order_line_item_ids = [int(match.mrl_record.order_line_item_id) for match in selected_matches]
            match_scores = [float(match.score) for match in selected_matches]
            match_grades = [self.get_match_grade(match.score) for match in selected_matches]
            matched_fields = [to_pg_array(list(match.field_scores.keys())) for match in selected_matches]
            mismatched_fields = [to_pg_array(list(set(vars(match.search_record).keys()) - set(match.field_scores.keys()))) for match in selected_matches]

            # Collect fulfillment_item_ids for 'both' match type
            if match_type == 'both':
                fulfillment_item_ids = [int(match.mrl_record.fulfillment_item_id) for match in selected_matches]
            else:
                fulfillment_item_ids = None  # Not needed for 'mrl' match type

            # Hardcode user_id and role_id to 1 for now
            user_id = 1
            role_id = 1

            logger.info(f"Bulk accepting {len(selected_matches)} {match_desc}")
            logger.debug(f"Staged IDs: {staged_ids}")
            logger.debug(f"Order Line Item IDs: {order_line_item_ids}")
            if fulfillment_item_ids:
                logger.debug(f"Fulfillment Item IDs: {fulfillment_item_ids}")
            logger.debug(f"Match Scores: {match_scores}")
            logger.debug(f"Match Grades: {match_grades}")
            logger.debug(f"Matched Fields: {matched_fields}")
            logger.debug(f"Mismatched Fields: {mismatched_fields}")

            try:
                if match_type == 'mrl':
                    self.match_controller.bulk_accept_staged_mrl_only_match(
                        staged_ids,
                        order_line_item_ids,
                        match_scores,
                        match_grades,
                        matched_fields,
                        mismatched_fields,
                        self.report_name,
                        self.report_date,
                        self.sheet_name,
                        user_id,
                        role_id
                    )
                elif match_type == 'both':
                    self.match_controller.bulk_accept_staged_mrl_fulfillment_match(
                        staged_ids,
                        order_line_item_ids,
                        fulfillment_item_ids,
                        match_scores,
                        match_grades,
                        matched_fields,
                        mismatched_fields,
                        self.report_name,
                        self.report_date,
                        self.sheet_name,
                        user_id,
                        role_id
                    )

                QMessageBox.information(self, "Bulk Accept", f"Successfully bulk accepted {len(selected_matches)} {match_desc}.")
                logger.info(f"Successfully bulk accepted {len(selected_matches)} {match_desc}.")
                self.update_match_display()
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to perform bulk accept: {str(e)}")
                logger.error(f"Bulk accept failed: {str(e)}", exc_info=True)

    def add_bulk_accept_controls(self):
        layout = QHBoxLayout()

        # Create the threshold slider
        self.threshold_slider = QSlider(Qt.Horizontal)
        self.threshold_slider.setMinimum(50)
        self.threshold_slider.setMaximum(100)
        self.threshold_slider.setValue(70)  # Default value
        self.threshold_slider.setTickInterval(5)
        self.threshold_slider.setTickPosition(QSlider.TicksBelow)
        self.threshold_slider.setSingleStep(5)
        self.threshold_slider.setFixedWidth(150)
        self.threshold_slider.valueChanged.connect(self.update_threshold_label)

        self.threshold_label = QLabel(f"Threshold: {self.threshold_slider.value()}%")

        # Create bulk accept buttons
        bulk_accept_mrl_button = QPushButton("Bulk Accept MRL")
        bulk_accept_mrl_button.clicked.connect(self.bulk_accept_mrl)
        bulk_accept_mrl_button.setFixedSize(120, 30)

        bulk_accept_both_button = QPushButton("Bulk Accept MRL+Fulfillment")
        bulk_accept_both_button.clicked.connect(self.bulk_accept_both)
        bulk_accept_both_button.setFixedSize(180, 30)

        # Add widgets to layout
        layout.addWidget(QLabel("Match Score Threshold:"))
        layout.addWidget(self.threshold_slider)
        layout.addWidget(self.threshold_label)
        layout.addWidget(bulk_accept_mrl_button)
        layout.addWidget(bulk_accept_both_button)
        layout.addStretch(1)

        return layout

    def update_threshold_label(self, value):
        self.threshold_label.setText(f"Threshold: {value}%")

    def bulk_accept_mrl(self):
        self._bulk_accept_matches(match_type='mrl')

    def bulk_accept_both(self):
        self._bulk_accept_matches(match_type='both')
            
    def get_match_grade(self, score):
        if score >= 80:
            return 'High'
        elif score >= 50:
            return 'Medium'
        else:
            return 'Low'

    def update_match_display(self):
        self.potential_matches = [match for match in self.potential_matches if match.search_record.staged_id not in self.accepted_matches]
        self.update_main_view()
        self.update_table_view()
        self.create_summary_view_tab()

    def toggle_lock_views(self):
        is_locked = self.lock_views_checkbox.isChecked()
        if is_locked:
            # Connect signals to synchronize views
            self.record_selector.currentIndexChanged.connect(self.sync_selection_from_combobox)
            self.table.itemSelectionChanged.connect(self.sync_selection_from_table)
            # Synchronize main checkboxes
            for idx, checkbox in enumerate(self.main_checkboxes):
                checkbox.stateChanged.connect(lambda state, index=idx: self.sync_selection_from_main_view(index))
        else:
            # Disconnect signals to stop synchronization
            self.record_selector.currentIndexChanged.disconnect(self.sync_selection_from_combobox)
            self.table.itemSelectionChanged.disconnect(self.sync_selection_from_table)
            # Disconnect main checkboxes
            for idx, checkbox in enumerate(self.main_checkboxes):
                checkbox.stateChanged.disconnect()

    def sync_selection_from_combobox(self, index):
        if not self.lock_views_checkbox.isChecked():
            return
        # Update main view checkbox
        if 0 <= index < len(self.main_checkboxes):
            self.main_checkboxes[index].setChecked(True)
        # Update table view selection
        self.table.clearSelection()
        row = index * 3  # Assuming each record occupies 3 rows
        self.table.selectRow(row)

    def sync_selection_from_table(self):
        if not self.lock_views_checkbox.isChecked():
            return
        selected_ranges = self.table.selectedRanges()
        if selected_ranges:
            row = selected_ranges[0].topRow()
            index = row // 3
            # Update record selector
            self.record_selector.setCurrentIndex(index)
            # Update main view checkbox
            if 0 <= index < len(self.main_checkboxes):
                self.main_checkboxes[index].setChecked(True)

    def sync_selection_from_main_view(self, index):
        if not self.lock_views_checkbox.isChecked():
            return
        # Update record selector
        self.record_selector.setCurrentIndex(index)
        # Update table view selection
        self.table.clearSelection()
        row = index * 3
        self.table.selectRow(row)

    def highlight_selected_record(self, index):
        self.main_checkboxes[index].setStyleSheet("background-color: yellow;")
        
        self.table.scrollToItem(self.table.item(index * 3, 0))
        for row in range(index * 3, index * 3 + 2):
            for col in range(self.table.columnCount()):
                item = self.table.item(row, col)
                if item:
                    item.setBackground(QColor("yellow"))

        self.record_selector.setCurrentIndex(index)

    def clear_highlights(self):
        for checkbox in self.main_checkboxes:
            checkbox.setStyleSheet("")

        for row in range(self.table.rowCount()):
            for col in range(self.table.columnCount()):
                item = self.table.item(row, col)
                if item:
                    item.setBackground(QColor("white"))

    def apply_selections(self):
        self.accepted_matches = []
        for index, checkbox in enumerate(self.main_checkboxes):
            if checkbox.isChecked():
                self.accepted_matches.append(self.potential_matches[index])

        if self.accepted_matches:
            self.matches_applied.emit(self.accepted_matches)
            QMessageBox.information(self, "Matches Applied", f"{len(self.accepted_matches)} matches have been applied.")
        else:
            QMessageBox.warning(self, "No Matches Selected", "No matches were selected to apply.")

        self.close()

    def create_main_view_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        # Add toggle button
        self.view_toggle_button = QPushButton("Switch to Detailed View")
        self.view_toggle_button.clicked.connect(self.toggle_main_view)
        layout.addWidget(self.view_toggle_button)

        # Create scroll area for match widgets
        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        layout.addWidget(scroll_area)

        self.main_content = QWidget()
        self.main_layout = QVBoxLayout(self.main_content)
        scroll_area.setWidget(self.main_content)

        self.create_match_widgets()

        # Add select all/none button
        self.select_all_button = QPushButton("Select All")
        self.select_all_button.setCheckable(True)
        self.select_all_button.clicked.connect(self.toggle_all_selections)
        layout.addWidget(self.select_all_button)

        self.tab_widget.addTab(tab, "Main View")

    def create_match_widgets(self):
        self.match_widgets = []
        for index, match in enumerate(self.potential_matches):
            match_widget = self.create_match_widget(match, index)
            self.main_layout.addWidget(match_widget)
            self.match_widgets.append(match_widget)

    def create_summary_view(self, match: Match):
        widget = QWidget()
        layout = QVBoxLayout(widget)

        # Display key fields
        key_fields = ['twcode', 'jcn', 'nomenclature', 'niin', 'part_no']
        self.current_staged_record = match.search_record  # Set current staged record for color coding

        staged_row = self.create_record_row(match.search_record, is_staged=True, fields=key_fields)
        mrl_row = self.create_record_row(match.mrl_record, is_staged=False, fields=key_fields)

        layout.addWidget(staged_row)
        layout.addWidget(mrl_row)

        return widget

    def create_detailed_view(self, match: Match):
        widget = QWidget()
        layout = QVBoxLayout(widget)

        # Display all fields
        all_fields = self.get_all_fields()
        self.current_staged_record = match.search_record  # Set current staged record for color coding

        staged_row = self.create_record_row(match.search_record, is_staged=True, fields=all_fields)
        mrl_row = self.create_record_row(match.mrl_record, is_staged=False, fields=all_fields)

        layout.addWidget(staged_row)
        layout.addWidget(mrl_row)

        return widget

    def toggle_detailed_view(self, detailed_widget, toggle_button):
        if detailed_widget.isVisible():
            detailed_widget.hide()
            toggle_button.setText("Show Details")
        else:
            detailed_widget.show()
            toggle_button.setText("Hide Details")

    def create_match_widget(self, match: Match, index: int):
        match_frame = QFrame()
        match_layout = QVBoxLayout(match_frame)

        # Add checkbox and index label
        top_layout = QHBoxLayout()
        checkbox = QCheckBox(f"Match #{index + 1}")
        self.main_checkboxes.append(checkbox)
        top_layout.addWidget(checkbox)
        top_layout.addStretch(1)
        match_layout.addLayout(top_layout)

        # Create summary and detailed widgets
        summary_widget = self.create_summary_view(match)
        summary_widget.setObjectName("summary_view")
        detailed_widget = self.create_detailed_view(match)
        detailed_widget.setObjectName("detailed_view")

        # Initially, show summary view and hide detailed view
        detailed_widget.hide()

        # Add widgets to layout
        match_layout.addWidget(summary_widget)
        match_layout.addWidget(detailed_widget)

        # Add accept/reject buttons
        button_layout = QHBoxLayout()
        accept_button = QPushButton("Accept Match")
        reject_button = QPushButton("Reject Match")
        button_layout.addWidget(accept_button)
        button_layout.addWidget(reject_button)
        match_layout.addLayout(button_layout)

        # Connect buttons to methods
        accept_button.clicked.connect(lambda checked, idx=index: self.accept_match(idx))
        reject_button.clicked.connect(lambda checked, idx=index: self.reject_match(idx))

        return match_frame

    def accept_match(self, index: int):
        match = self.potential_matches[index]
        if match not in self.accepted_matches:
            self.accepted_matches.append(match)
        self.main_checkboxes[index].setChecked(True)

    def reject_match(self, index: int):
        match = self.potential_matches[index]
        if match in self.accepted_matches:
            self.accepted_matches.remove(match)
        self.main_checkboxes[index].setChecked(False)

    def create_record_row(self, record, is_staged, fields):
        row_widget = QWidget()
        row_layout = QHBoxLayout(row_widget)
        row_layout.setSpacing(10)  # Add some spacing between fields

        background_color = 'lightcoral' if is_staged else 'lightblue'
        row_widget.setStyleSheet(f"background-color: {background_color};")

        for field in fields:
            value = getattr(record, field, 'N/A')
            field_label = QLabel(f"{field}: {value}")
            field_label.setFixedWidth(200)  # Set a fixed width for alignment
            field_label.setWordWrap(True)  # Enable word wrapping for long values

            if not is_staged:
                match_quality = self.get_field_match_quality(self.current_staged_record, record, field)
                quality_info = self.get_match_quality_info(match_quality)
                field_label.setStyleSheet(f"color: {quality_info['color']};")
                field_label.setToolTip(quality_info['tooltip'])
            else:
                field_label.setStyleSheet("color: black;")

            row_layout.addWidget(field_label)

        row_layout.addStretch(1)  # Add stretch at the end to left-align the fields
        return row_widget

    def add_record_to_grid(self, grid, record, row, is_staged, fields):
        bg_color = 'lightcoral' if is_staged else 'lightblue'
        
        for col, field in enumerate(fields):
            value = getattr(record, field, 'N/A')
            if value is None:
                value = 'N/A'
            label = QLabel(str(value))
            label.setStyleSheet(f"background-color: {bg_color};")
            
            if not is_staged:
                match_quality = self.get_field_match_quality(self.current_staged_record, record, field)
                label.setStyleSheet(f"background-color: {bg_color}; color: {match_quality};")
            
            grid.addWidget(label, row, col)

    def toggle_main_view(self):
        is_summary = self.view_toggle_button.text() == "Switch to Detailed View"
        self.view_toggle_button.setText("Switch to Summary View" if is_summary else "Switch to Detailed View")
        
        for widget in self.match_widgets:
            self.update_match_widget_view(widget, not is_summary)

    def update_match_widget_view(self, match_widget, show_summary: bool):
        summary_view = match_widget.findChild(QWidget, "summary_view")
        detailed_view = match_widget.findChild(QWidget, "detailed_view")

        if show_summary:
            summary_view.show()
            detailed_view.hide()
        else:
            summary_view.hide()
            detailed_view.show()

    def get_all_fields(self):
        staged_fields = vars(self.potential_matches[0].search_record).keys()
        mrl_fields = vars(self.potential_matches[0].mrl_record).keys()
        return list(set(staged_fields) | set(mrl_fields))

    def toggle_all_selections(self):
        check_state = self.select_all_button.isChecked()
        if check_state:
            self.select_all_button.setText("Deselect All")
        else:
            self.select_all_button.setText("Select All")
        for checkbox in self.main_checkboxes:
            checkbox.setChecked(check_state)

    def create_side_by_side_view_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        selection_layout = QHBoxLayout()
        selection_layout.addWidget(QLabel("Select Record:"))
        self.record_selector = QComboBox()
        self.record_selector.addItems([f"Match #{i + 1}" for i in range(len(self.potential_matches))])
        self.record_selector.currentIndexChanged.connect(self.update_side_by_side_view)
        selection_layout.addWidget(self.record_selector)
        layout.addLayout(selection_layout)

        self.side_by_side_widget = QWidget()
        self.side_by_side_layout = QHBoxLayout(self.side_by_side_widget)
        layout.addWidget(self.side_by_side_widget)

        self.update_side_by_side_view(0)
        self.tab_widget.addTab(tab, "Side-by-Side View")

    def update_side_by_side_view(self, index):
        for i in reversed(range(self.side_by_side_layout.count())):
            widget = self.side_by_side_layout.itemAt(i).widget()
            if widget:
                widget.setParent(None)

        match = self.potential_matches[index]
        staged_column = self.create_record_column(match.search_record, is_staged=True, index=index)
        mrl_column = self.create_record_column(match.mrl_record, is_staged=False, index=index)

        self.side_by_side_layout.addWidget(staged_column)
        self.side_by_side_layout.addWidget(mrl_column)

    def create_record_column(self, record, is_staged, index):
        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        column_widget = QWidget()
        column_layout = QVBoxLayout(column_widget)

        palette = column_widget.palette()
        palette.setColor(QPalette.Window, QColor('lightcoral') if is_staged else QColor('lightblue'))
        column_widget.setAutoFillBackground(True)
        column_widget.setPalette(palette)

        header = QLabel(f"{'Staged' if is_staged else 'MRL'} Record #{index + 1}")
        header.setStyleSheet("font-weight: bold;")
        column_layout.addWidget(header)

        field_mapping = self.get_field_mapping()
        for field, mrl_field in field_mapping.items():
            if field is None:
                continue  # Skip if field is None

            if is_staged or (not is_staged and mrl_field is not None):
                actual_field = field if is_staged else mrl_field
                if actual_field is None:
                    continue  # Skip if actual_field is None

                value = getattr(record, actual_field, 'N/A')
                if value is None:
                    value = 'N/A'
                field_widget = QLabel(f"{actual_field}: {value}")

                if not is_staged and mrl_field is not None:
                    match_quality = self.get_field_match_quality(self.current_staged_record, record, mrl_field)
                    quality_info = self.get_match_quality_info(match_quality)
                    field_widget.setStyleSheet(f"color: {quality_info['color']};")
                    field_widget.setToolTip(quality_info['tooltip'])
                else:
                    field_widget.setStyleSheet("color: black;")

                column_layout.addWidget(field_widget)

        scroll_area.setWidget(column_widget)
        return scroll_area

    def create_table_view_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        filter_layout = QHBoxLayout()
        self.field_filter = QComboBox()
        if self.potential_matches:
            fields = vars(self.potential_matches[0].search_record).keys()
            self.field_filter.addItems(['All Fields'] + list(fields))
        else:
            self.field_filter.addItems(['All Fields'])
        self.quality_filter = QComboBox()
        self.quality_filter.addItems(['All Qualities', 'High (>=80%)', 'Medium (50-79%)', 'Low (<50%)'])
        self.search_filter = QLineEdit()
        self.search_filter.setPlaceholderText("Search...")

        filter_layout.addWidget(QLabel("Field:"))
        filter_layout.addWidget(self.field_filter)
        filter_layout.addWidget(QLabel("Quality:"))
        filter_layout.addWidget(self.quality_filter)
        filter_layout.addWidget(self.search_filter)

        layout.addLayout(filter_layout)

        self.table = QTableWidget()
        self.update_table_view()

        # Add select all/none button
        self.table_select_all_button = QPushButton("Select All")
        self.table_select_all_button.setCheckable(True)
        self.table_select_all_button.clicked.connect(self.toggle_all_table_selections)
        layout.addWidget(self.table_select_all_button)

        layout.addWidget(self.table)
        self.tab_widget.addTab(tab, "Table View")
    
        self.field_filter.currentTextChanged.connect(self.update_table_view)
        self.quality_filter.currentTextChanged.connect(self.update_table_view)
        self.search_filter.textChanged.connect(self.update_table_view)

        layout.addWidget(self.table)
        self.tab_widget.addTab(tab, "Table View")

    def update_table_view(self):
        self.table.clear()
        field_filter = self.field_filter.currentText()
        quality_filter = self.quality_filter.currentText()
        search_text = self.search_filter.text().lower()

        filtered_matches = self.filter_matches(field_filter, quality_filter, search_text)
        filtered_matches.sort(key=lambda x: x.score, reverse=True)

        if not filtered_matches:
            self.table.setRowCount(0)
            self.table.setColumnCount(0)
            return

        field_mapping = self.get_field_mapping()
        headers = ['Select'] + list(field_mapping.keys())
        self.table.setColumnCount(len(headers))
        self.table.setHorizontalHeaderLabels(headers)

        # Calculate the total number of rows needed
        total_rows = len(filtered_matches) * 3 - (len(filtered_matches) - 1)
        self.table.setRowCount(total_rows)

        current_row = 0
        for i, match in enumerate(filtered_matches):
            row_staged = current_row
            row_mrl = current_row + 1

            # Staged record row
            checkbox_item = QTableWidgetItem()
            checkbox_item.setFlags(Qt.ItemIsUserCheckable | Qt.ItemIsEnabled)
            checkbox_item.setCheckState(Qt.Unchecked)
            self.table.setItem(row_staged, 0, checkbox_item)

            for col, field in enumerate(headers[1:], start=1):
                value = getattr(match.search_record, field, '')
                item = QTableWidgetItem(str(value))
                item.setBackground(QColor('lightcoral'))
                self.table.setItem(row_staged, col, item)

            # MRL record row
            for col, field in enumerate(headers[1:], start=1):
                mrl_field = field_mapping.get(field)
                if mrl_field:
                    value = getattr(match.mrl_record, mrl_field, '')
                    item = QTableWidgetItem(str(value))
                    item.setBackground(QColor('lightblue'))
                    match_quality = self.get_field_match_quality(match.search_record, match.mrl_record, field)
                    quality_info = self.get_match_quality_info(match_quality)
                    item.setForeground(QColor(quality_info['color']))
                    item.setToolTip(quality_info['tooltip'])
                else:
                    item = QTableWidgetItem('')
                    item.setBackground(QColor('lightblue'))
                self.table.setItem(row_mrl, col, item)

            current_row += 2

            # Add separator row if not the last record
            if i < len(filtered_matches) - 1:
                row_separator = current_row
                self.table.setSpan(row_separator, 0, 1, len(headers))
                separator_item = QTableWidgetItem()
                separator_item.setBackground(QColor(200, 200, 200))
                separator_item.setFlags(Qt.NoItemFlags)
                self.table.setItem(row_separator, 0, separator_item)
                self.table.setRowHeight(row_separator, 2)
                current_row += 1

        self.table.resizeColumnsToContents()
        self.table.setSortingEnabled(True)

    def toggle_all_table_selections(self):
        check_state = self.table_select_all_button.isChecked()
        if check_state:
            self.table_select_all_button.setText("Deselect All")
        else:
            self.table_select_all_button.setText("Select All")
        for row in range(0, self.table.rowCount(), 3):
            checkbox_item = self.table.item(row, 0)
            if checkbox_item:
                checkbox_item.setCheckState(Qt.Checked if check_state else Qt.Unchecked)

    def filter_matches(self, field_filter, quality_filter, search_text):
        filtered = self.potential_matches

        if field_filter != 'All Fields':
            filtered = [match for match in filtered if search_text in str(getattr(match.search_record, field_filter, '')).lower() or
                        search_text in str(getattr(match.mrl_record, field_filter, '')).lower()]

        if quality_filter != 'All Qualities':
            if quality_filter == 'High (>=80%)':
                filtered = [match for match in filtered if match.score >= 80]
            elif quality_filter == 'Medium (50-79%)':
                filtered = [match for match in filtered if 50 <= match.score < 80]
            elif quality_filter == 'Low (<50%)':
                filtered = [match for match in filtered if match.score < 50]

        if search_text and field_filter == 'All Fields':
            filtered = [match for match in filtered if any(search_text in str(value).lower() for value in vars(match.search_record).values()) or
                        any(search_text in str(value).lower() for value in vars(match.mrl_record).values())]

        return filtered

    def get_field_match_quality(self, search_record, mrl_record, field):
        search_value = str(getattr(search_record, field, '')).lower().strip()
        mrl_value = str(getattr(mrl_record, field, '')).lower().strip()

        if not search_value or not mrl_value:
            return 'unknown'

        if field == 'nomenclature':
            similarity = ratio(search_value, mrl_value)
            if similarity >= 0.8:
                return 'exact'
            elif similarity >= 0.5:
                return 'similar'
            else:
                return 'no_match'
        else:
            if search_value == mrl_value:
                return 'exact'
            else:
                return 'no_match'

    def create_summary_view_tab(self):
        # Remove the existing summary tab if it exists
        for i in range(self.tab_widget.count()):
            if self.tab_widget.tabText(i) == "Summary View":
                self.tab_widget.removeTab(i)
                break

        tab = QWidget()
        layout = QVBoxLayout(tab)

        # Text summary
        summary_text = self.get_summary_text()
        summary_label = QLabel(summary_text)
        summary_label.setAlignment(Qt.AlignTop)
        summary_label.setWordWrap(True)  # Enable word wrapping
        layout.addWidget(summary_label)

        # Pie chart for match quality distribution
        quality_chart_view = self.create_quality_distribution_chart()
        layout.addWidget(quality_chart_view)

        # Bar chart for field-specific match rates
        field_chart_view = self.create_field_match_rate_chart()
        layout.addWidget(field_chart_view)

        # Add the tab to the tab widget
        self.tab_widget.addTab(tab, "Summary View")

    def get_summary_text(self):
        total_matches = len(self.potential_matches)
        high_quality_matches = sum(1 for match in self.potential_matches if match.score >= 80)
        medium_quality_matches = sum(1 for match in self.potential_matches if 50 <= match.score < 80)
        low_quality_matches = sum(1 for match in self.potential_matches if match.score < 50)

        summary_text = f"""
        <h2>Match Summary</h2>
        <p><strong>Total Matches:</strong> {total_matches}</p>
        <p><strong>High Quality Matches (>=80%):</strong> {high_quality_matches}</p>
        <p><strong>Medium Quality Matches (50-79%):</strong> {medium_quality_matches}</p>
        <p><strong>Low Quality Matches (<50%):</strong> {low_quality_matches}</p>
        <h3>Field-specific Match Rates:</h3>
        """

        fields = ['twcode', 'jcn', 'nomenclature', 'niin', 'part_no']
        for field in fields:
            match_rate = self.calculate_field_match_rate(field)
            summary_text += f"<p><strong>{field.upper()}:</strong> {match_rate:.2f}%</p>"

        return summary_text

    def create_quality_distribution_chart(self):
        high_quality = sum(1 for match in self.potential_matches if match.score >= 80)
        medium_quality = sum(1 for match in self.potential_matches if 50 <= match.score < 80)
        low_quality = sum(1 for match in self.potential_matches if match.score < 50)

        series = QPieSeries()
        series.append("High Quality", high_quality)
        series.append("Medium Quality", medium_quality)
        series.append("Low Quality", low_quality)

        # Add labels to the slices
        for slice in series.slices():
            percentage = (slice.value() / len(self.potential_matches)) * 100 if len(self.potential_matches) > 0 else 0
            slice.setLabel(f"{slice.label()} ({slice.value()}) - {percentage:.1f}%")

        # Customize colors
        series.slices()[0].setBrush(QColor("green"))
        series.slices()[1].setBrush(QColor("orange"))
        series.slices()[2].setBrush(QColor("red"))

        chart = QChart()
        chart.addSeries(series)
        chart.setTitle("Match Quality Distribution")
        chart.legend().setAlignment(Qt.AlignBottom)

        chartview = QChartView(chart)
        chartview.setRenderHint(QPainter.Antialiasing)

        return chartview

    def create_field_match_rate_chart(self):
        fields = ['twcode', 'jcn', 'nomenclature', 'niin', 'part_no']
        match_rates = [self.calculate_field_match_rate(field) for field in fields]

        series = QBarSeries()
        bar_set = QBarSet("Match Rate (%)")
        bar_set.append(match_rates)
        series.append(bar_set)

        chart = QChart()
        chart.addSeries(series)
        chart.setTitle("Field-specific Match Rates")
        chart.setAnimationOptions(QChart.SeriesAnimations)

        # Customize axes
        axis_x = QBarCategoryAxis()
        axis_x.append([field.upper() for field in fields])
        chart.addAxis(axis_x, Qt.AlignBottom)
        series.attachAxis(axis_x)

        axis_y = QValueAxis()
        axis_y.setRange(0, 100)
        axis_y.setTitleText("Match Rate (%)")
        chart.addAxis(axis_y, Qt.AlignLeft)
        series.attachAxis(axis_y)

        chart.legend().setVisible(False)

        chartview = QChartView(chart)
        chartview.setRenderHint(QPainter.Antialiasing)

        return chartview

    def calculate_field_match_rate(self, field):
        total = len(self.potential_matches)
        if total == 0:
            return 0.0

        matches = 0
        for match in self.potential_matches:
            search_value = str(getattr(match.search_record, field, '')).lower().strip()
            mrl_value = str(getattr(match.mrl_record, field, '')).lower().strip()

            if field == 'nomenclature':
                similarity = ratio(search_value, mrl_value)
                if similarity >= 0.8:
                    matches += 1
            else:
                if search_value == mrl_value and search_value != '':
                    matches += 1

        match_rate = (matches / total) * 100
        return match_rate

    def update_main_view(self):
        for i in reversed(range(self.main_layout.count())):
            widget = self.main_layout.itemAt(i).widget()
            if widget:
                widget.setParent(None)

        self.create_match_widgets()
        self.main_layout.addStretch(1)

    def get_field_mapping(self):
        # Retrieve all unique fields from both staged and MRL records
        all_fields = set()
        for match in self.potential_matches:
            staged_fields = vars(match.search_record).keys()
            mrl_fields = vars(match.mrl_record).keys()
            all_fields.update(staged_fields)
            all_fields.update(mrl_fields)

        # Remove any None values from all_fields
        all_fields.discard(None)

        # Create a field mapping where keys are staged fields and values are corresponding MRL fields
        field_mapping = {}
        for field in all_fields:
            if field is None:
                continue  # Skip if field is None

            # Check if the field exists in both records
            field_in_staged = any(field in vars(match.search_record) for match in self.potential_matches)
            field_in_mrl = any(field in vars(match.mrl_record) for match in self.potential_matches)

            if field_in_staged and field_in_mrl:
                field_mapping[field] = field  # Direct mapping
            elif field_in_staged and not field_in_mrl:
                field_mapping[field] = None  # Field only in staged record
            elif not field_in_staged and field_in_mrl:
                # Find the corresponding staged field if possible
                corresponding_field = self.find_corresponding_field(field)
                if corresponding_field:
                    field_mapping[corresponding_field] = field
                # Do not add to field_mapping if corresponding_field is None
        return field_mapping

    def find_corresponding_field(self, mrl_field):
        # Define possible field name mappings if needed
        field_aliases = {
            'manufacturer_part_number': 'part_no',
            'item_name': 'nomenclature',
            # Add more aliases as necessary
        }
        for staged_field, alias in field_aliases.items():
            if mrl_field == alias:
                return staged_field
        return None

    def get_match_quality_info(self, match_quality):
        if match_quality == 'exact':
            return {'color': 'darkgreen', 'tooltip': 'Exact Match'}
        elif match_quality == 'similar':
            return {'color': 'darkorange', 'tooltip': 'Similar Match'}
        elif match_quality == 'no_match':
            return {'color': 'darkred', 'tooltip': 'No Match'}
        else:
            return {'color': 'black', 'tooltip': 'Unknown'}

    def closeEvent(self, event):
        # Perform any cleanup if necessary
        super().closeEvent(event)