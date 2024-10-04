# ui/matching_detail_window.py

from PySide6.QtWidgets import (
    QMainWindow, QVBoxLayout, QHBoxLayout, QWidget, QPushButton,
    QLabel, QScrollArea, QTabWidget, QComboBox, QLineEdit,
    QTableWidget, QTableWidgetItem, QHeaderView, QCheckBox, QMessageBox,
    QProgressDialog
)
from PySide6.QtCore import Qt, Signal, Slot
from PySide6.QtGui import QColor, QPalette
from models.data_models import Match, StagedRecord, MRLRecord
from models.database import DatabaseConnection
from controllers.match_controller import MatchController
import logging
from Levenshtein import ratio

logger = logging.getLogger(__name__)

class MatchingDetailWindow(QMainWindow):
    matches_applied = Signal(list)  # Signal to emit when matches are applied

    def __init__(self, potential_matches, db_connection: DatabaseConnection, report_info):
        super().__init__()
        self.potential_matches = potential_matches  # List of Match instances
        self.db = db_connection
        self.report_name = report_info['report_name']
        self.report_date = report_info['report_date']
        self.sheet_name = report_info['sheet_name']
        self.accepted_matches = []
        self.match_selections = {i: False for i in range(len(self.potential_matches))}
        self.match_controller = MatchController(self.db)
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

    def add_bulk_accept_controls(self):
        layout = QHBoxLayout()

        self.threshold_slider = QComboBox()
        self.threshold_slider.addItems([str(i) for i in range(50, 101, 5)])
        self.threshold_slider.setCurrentText("70")
        self.threshold_slider.setFixedWidth(80)

        self.threshold_label = QLabel("Threshold: 70%")
        self.threshold_slider.currentTextChanged.connect(self.update_threshold_label)

        bulk_accept_mrl_button = QPushButton("Bulk Accept MRL")
        bulk_accept_mrl_button.clicked.connect(self.bulk_accept_mrl)
        bulk_accept_mrl_button.setFixedSize(120, 30)

        bulk_accept_both_button = QPushButton("Bulk Accept MRL+Fulfillment")
        bulk_accept_both_button.clicked.connect(self.bulk_accept_both)
        bulk_accept_both_button.setFixedSize(180, 30)

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
        threshold = int(self.threshold_slider.currentText())
        # Filter matches based on threshold
        selected_matches = [match for match in self.potential_matches if match.score >= threshold]
        staged_ids = [match.search_record.staged_id for match in selected_matches]
        order_line_item_ids = [match.mrl_record.order_line_item_id for match in selected_matches]
        match_scores = [match.score for match in selected_matches]
        match_grades = [self.get_match_grade(match.score) for match in selected_matches]
        matched_fields = [list(match.field_scores.keys()) for match in selected_matches]
        mismatched_fields = [list(set(vars(match.search_record).keys()) - set(match.field_scores.keys())) for match in selected_matches]
        user_id = 1  # Hardcoded user_id
        role_id = 1  # Hardcoded role_id
        try:
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
            self.update_match_display()
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to perform bulk MRL accept: {str(e)}")
            logger.error(f"Bulk MRL accept failed: {str(e)}")

    def get_match_grade(self, score):
        if score >= 80:
            return 'High'
        elif score >= 50:
            return 'Medium'
        else:
            return 'Low'

    def bulk_accept_both(self):
        threshold = int(self.threshold_slider.currentText())
        selected_matches = [match for match in self.potential_matches if match.score >= threshold]
        staged_ids = [match.search_record.staged_id for match in selected_matches]
        order_line_item_ids = [match.mrl_record.order_line_item_id for match in selected_matches]
        fulfillment_item_ids = [match.fulfillment_record.fulfillment_item_id for match in selected_matches]
        match_scores = [match.score for match in selected_matches]
        match_grades = [self.get_match_grade(match.score) for match in selected_matches]
        matched_fields = [list(match.field_scores.keys()) for match in selected_matches]
        mismatched_fields = [list(set(vars(match.search_record).keys()) - set(match.field_scores.keys())) for match in selected_matches]
        user_id = 1  # Hardcoded user_id
        role_id = 1  # Hardcoded role_id
        try:
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
            self.update_match_display()
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to perform bulk MRL+Fulfillment accept: {str(e)}")
            logger.error(f"Bulk MRL+Fulfillment accept failed: {str(e)}")

    def update_match_display(self):
        # Remove accepted matches from the display
        self.potential_matches = [match for match in self.potential_matches if match.search_record.staged_id not in self.accepted_matches]
        self.update_main_view()
        self.update_table_view()
        self.create_summary_view_tab()  # Recreate the summary view with updated data

    def toggle_lock_views(self):
        is_locked = self.lock_views_checkbox.isChecked()
        if is_locked:
            current_index = self.record_selector.currentIndex()
            self.highlight_selected_record(current_index)
        else:
            self.clear_highlights()

    def highlight_selected_record(self, index):
        # Highlight in main view
        self.main_checkboxes[index].setStyleSheet("background-color: yellow;")

        # Highlight in table view
        self.table.scrollToItem(self.table.item(index * 2, 0))
        for col in range(self.table.columnCount()):
            self.table.item(index * 2, col).setBackground(QColor("yellow"))
            self.table.item(index * 2 + 1, col).setBackground(QColor("yellow"))

        # Update side-by-side view
        self.record_selector.setCurrentIndex(index)

    def clear_highlights(self):
        # Clear highlights in main view
        for checkbox in self.main_checkboxes:
            checkbox.setStyleSheet("")

        # Clear highlights in table view
        for row in range(self.table.rowCount()):
            for col in range(self.table.columnCount()):
                item = self.table.item(row, col)
                if item:
                    item.setBackground(QColor("white"))

    def apply_selections(self):
        # Collect accepted matches based on user selections
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

        self.main_checkboxes = []

        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        layout.addWidget(scroll_area)

        self.main_content = QWidget()
        self.main_layout = QVBoxLayout(self.main_content)
        scroll_area.setWidget(self.main_content)

        for index, match in enumerate(self.potential_matches):
            match_widget = self.create_match_widget(match, index)
            self.main_layout.addWidget(match_widget)

        select_all_button = QPushButton("Select All/None")
        select_all_button.setCheckable(True)
        select_all_button.clicked.connect(self.toggle_all_selections)
        layout.addWidget(select_all_button)

        self.tab_widget.addTab(tab, "Main View")

    def create_match_widget(self, match: Match, index):
        match_frame = QFrame()
        match_layout = QVBoxLayout(match_frame)

        # Add checkbox and index
        top_layout = QHBoxLayout()
        checkbox = QCheckBox()
        self.main_checkboxes.append(checkbox)
        top_layout.addWidget(checkbox)
        top_layout.addWidget(QLabel(f"Match #{index + 1}"))
        top_layout.addStretch(1)
        match_layout.addLayout(top_layout)

        # Compact View
        compact_widget = self.create_compact_view(match)
        match_layout.addWidget(compact_widget)

        # Expanded View (initially hidden)
        expanded_widget = self.create_expanded_view(match)
        match_layout.addWidget(expanded_widget)
        expanded_widget.hide()

        # Expand/Collapse button
        toggle_button = QPushButton("Expand")
        toggle_button.clicked.connect(lambda: self.toggle_expanded_view(expanded_widget, toggle_button))
        match_layout.addWidget(toggle_button)

        # Accept/Reject buttons
        control_layout = QHBoxLayout()
        accept_button = QPushButton("Accept Match")
        accept_button.clicked.connect(lambda: self.accept_match(match))
        reject_button = QPushButton("Reject Match")
        reject_button.clicked.connect(lambda: self.reject_match(match))
        control_layout.addWidget(accept_button)
        control_layout.addWidget(reject_button)
        match_layout.addLayout(control_layout)

        return match_frame

    def create_compact_view(self, match: Match):
        widget = QWidget()
        layout = QVBoxLayout(widget)

        staged_row = self.create_record_row(match.search_record, is_staged=True, is_compact=True)
        mrl_row = self.create_record_row(match.mrl_record, is_staged=False, is_compact=True)

        layout.addWidget(staged_row)
        layout.addWidget(mrl_row)
        layout.addWidget(QLabel(f"Match Score: {match.score:.2f}%"))

        return widget

    def create_expanded_view(self, match: Match):
        widget = QWidget()
        layout = QVBoxLayout(widget)

        staged_row = self.create_record_row(match.search_record, is_staged=True, is_compact=False)
        mrl_row = self.create_record_row(match.mrl_record, is_staged=False, is_compact=False)

        layout.addWidget(staged_row)
        layout.addWidget(mrl_row)

        return widget

    def create_record_row(self, record, is_staged, is_compact):
        row_widget = QWidget()
        row_layout = QHBoxLayout(row_widget)

        palette = row_widget.palette()
        palette.setColor(QPalette.Window, QColor('lightcoral') if is_staged else QColor('lightblue'))
        row_widget.setAutoFillBackground(True)
        row_widget.setPalette(palette)

        fields = ['twcode', 'jcn', 'nomenclature', 'niin', 'part_no']
        if not is_compact:
            # Include all fields if not compact
            fields = vars(record).keys()

        for field in fields:
            value = getattr(record, field, '')
            if value is None:
                value = ''
            field_widget = QLabel(f"{field}: {value}")
            row_layout.addWidget(field_widget)

        row_widget.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        return row_widget

    def toggle_expanded_view(self, expanded_widget, toggle_button):
        if expanded_widget.isVisible():
            expanded_widget.hide()
            toggle_button.setText("Expand")
        else:
            expanded_widget.show()
            toggle_button.setText("Collapse")

    def accept_match(self, match: Match):
        if match not in self.accepted_matches:
            self.accepted_matches.append(match)
        QMessageBox.information(self, "Match Accepted", "The match has been accepted.")

    def reject_match(self, match: Match):
        if match in self.accepted_matches:
            self.accepted_matches.remove(match)
        QMessageBox.information(self, "Match Rejected", "The match has been rejected.")

    def toggle_all_selections(self):
        check_state = self.sender().isChecked()
        for checkbox in self.main_checkboxes:
            checkbox.setChecked(check_state)

    def create_side_by_side_view_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        # Add record selection controls
        selection_layout = QHBoxLayout()
        selection_layout.addWidget(QLabel("Select Record:"))
        self.record_selector = QComboBox()
        self.record_selector.addItems([f"Match #{i + 1}" for i in range(len(self.potential_matches))])
        self.record_selector.currentIndexChanged.connect(self.update_side_by_side_view)
        selection_layout.addWidget(self.record_selector)
        layout.addLayout(selection_layout)

        # Create side-by-side view
        self.side_by_side_widget = QWidget()
        self.side_by_side_layout = QHBoxLayout(self.side_by_side_widget)
        layout.addWidget(self.side_by_side_widget)

        self.update_side_by_side_view(0)
        self.tab_widget.addTab(tab, "Side-by-Side View")

    def update_side_by_side_view(self, index):
        # Clear existing widgets
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
        column_widget = QWidget()
        column_layout = QVBoxLayout(column_widget)

        palette = column_widget.palette()
        palette.setColor(QPalette.Window, QColor('lightcoral') if is_staged else QColor('lightblue'))
        column_widget.setAutoFillBackground(True)
        column_widget.setPalette(palette)

        header = QLabel(f"{'Staged' if is_staged else 'MRL'} Record #{index + 1}")
        header.setStyleSheet("font-weight: bold;")
        column_layout.addWidget(header)

        fields = vars(record).keys()

        for field in fields:
            value = getattr(record, field, '')
            if value is None:
                value = ''
            field_widget = QLabel(f"{field}: {value}")
            column_layout.addWidget(field_widget)

        return column_widget

    def create_table_view_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        # Add filter controls
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

        # Add Select All/None button
        select_all_button = QPushButton("Select All/None")
        select_all_button.setCheckable(True)
        select_all_button.clicked.connect(self.toggle_all_table_selections)
        layout.addWidget(select_all_button)

        # Connect filter signals
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

        headers = ['Select'] + list(vars(filtered_matches[0].search_record).keys())
        self.table.setColumnCount(len(headers))
        self.table.setHorizontalHeaderLabels(headers)

        # Set the row count to accommodate all rows (staged and mrl records)
        self.table.setRowCount(len(filtered_matches) * 2)

        for i, match in enumerate(filtered_matches):
            row_staged = i * 2
            row_mrl = i * 2 + 1

            # Add checkbox to staged row
            checkbox_item = QTableWidgetItem()
            checkbox_item.setFlags(Qt.ItemIsUserCheckable | Qt.ItemIsEnabled)
            checkbox_item.setCheckState(Qt.Unchecked)
            self.table.setItem(row_staged, 0, checkbox_item)

            # Fill staged record
            for col, field in enumerate(headers[1:], start=1):
                value = getattr(match.search_record, field, '')
                item = QTableWidgetItem(str(value))
                item.setBackground(QColor('lightcoral'))
                self.table.setItem(row_staged, col, item)

            # Fill mrl record
            for col, field in enumerate(headers[1:], start=1):
                value = getattr(match.mrl_record, field, '')
                item = QTableWidgetItem(str(value))
                item.setBackground(QColor('lightblue'))
                # Apply match quality coloring if applicable
                match_quality = self.get_field_match_quality(match.search_record, match.mrl_record, field)
                item.setForeground(QColor(match_quality))
                self.table.setItem(row_mrl, col, item)

            self.table.setRowHeight(row_staged, self.table.rowHeight(row_staged) + 2)
            self.table.setRowHeight(row_mrl, self.table.rowHeight(row_mrl) + 2)

        self.table.resizeColumnsToContents()
        self.table.setSortingEnabled(True)

    def toggle_all_table_selections(self):
        check_state = self.sender().isChecked()
        for row in range(0, self.table.rowCount(), 2):  # Every other row is a staged record
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

    def get_field_match_quality(self, search_record: StagedRecord, mrl_record: MRLRecord, field):
        search_value = getattr(search_record, field, '').lower().strip()
        mrl_value = getattr(mrl_record, field, '').lower().strip()

        if field == 'nomenclature':
            similarity = ratio(search_value, mrl_value)
            if similarity > 0.8:
                return 'darkgreen'
            elif similarity > 0.5:
                return 'darkorange'
            else:
                return 'darkred'
        else:
            if search_value == mrl_value and search_value != '':
                return 'darkgreen'
            elif search_value != mrl_value and search_value != '' and mrl_value != '':
                return 'darkred'
            else:
                return 'black'

    def create_summary_view_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        # Text summary
        summary_text = self.get_summary_text()
        summary_label = QLabel(summary_text)
        summary_label.setAlignment(Qt.AlignTop)
        layout.addWidget(summary_label)

        self.tab_widget.addTab(tab, "Summary View")

    def get_summary_text(self):
        total_matches = len(self.potential_matches)
        high_quality_matches = sum(1 for match in self.potential_matches if match.score >= 80)
        medium_quality_matches = sum(1 for match in self.potential_matches if 50 <= match.score < 80)
        low_quality_matches = sum(1 for match in self.potential_matches if match.score < 50)

        summary_text = f"""
        Total Matches: {total_matches}
        High Quality Matches (>=80%): {high_quality_matches}
        Medium Quality Matches (50-79%): {medium_quality_matches}
        Low Quality Matches (<50%): {low_quality_matches}
        """

        return summary_text

    def update_main_view(self):
        # Clear existing widgets
        for i in reversed(range(self.main_layout.count())):
            widget = self.main_layout.itemAt(i).widget()
            if widget:
                widget.setParent(None)

        for index, match in enumerate(self.potential_matches):
            match_widget = self.create_match_widget(match, index)
            self.main_layout.addWidget(match_widget)
        self.main_layout.addStretch(1)

    def closeEvent(self, event):
        # Perform any cleanup if necessary
        super().closeEvent(event)
