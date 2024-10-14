from PySide6.QtWidgets import (QMainWindow, QVBoxLayout, QHBoxLayout, QWidget, QPushButton,
                               QLabel, QScrollArea, QFrame, QSizePolicy, QTabWidget, QComboBox, QLineEdit,
                               QTableWidget, QTableWidgetItem, QHeaderView, QSlider, QCheckBox, QMessageBox)
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QColor, QPalette, QPainter
from PySide6.QtCharts import QChart, QChartView, QPieSeries, QBarSeries, QBarSet, QBarCategoryAxis, QValueAxis
from Levenshtein import ratio
import logging

class MatchingDetailWindow(QMainWindow):
    matches_applied = Signal(list)  # Signal to emit when matches are applied

    def __init__(self, potential_matches, db_connection, report_info):
        super().__init__()
        self.potential_matches = potential_matches
        self.db = db_connection
        self.report_name = report_info['report_name']
        self.report_date = report_info['report_date']
        self.sheet_name = report_info['sheet_name']
        self.accepted_matches = []
        self.init_ui()
        self.match_selections = {i: False for i in range(len(self.potential_matches))}        

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

    def create_match_widget(self, match, index):
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

        return match_frame, checkbox

    def accept_match(self, match):
        if match not in self.accepted_matches:
            self.accepted_matches.append(match)

    def reject_match(self, match):
        if match in self.accepted_matches:
            self.accepted_matches.remove(match)

    def create_compact_view(self, match):
        widget = QWidget()
        layout = QVBoxLayout(widget)

        staged_row = self.create_record_row(match['search_record'], is_staged=True, is_compact=True)
        mrl_row = self.create_record_row(match['mrl_record'], is_staged=False, is_compact=True)

        layout.addWidget(staged_row)
        layout.addWidget(mrl_row)
        layout.addWidget(QLabel(f"Match Score: {match['score']:.2f}%"))

        return widget

    def create_expanded_view(self, match):
        widget = QWidget()
        layout = QVBoxLayout(widget)

        staged_row = self.create_record_row(match['search_record'], is_staged=True, is_compact=False)
        mrl_row = self.create_record_row(match['mrl_record'], is_staged=False, is_compact=False)

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

        field_mapping = self.get_field_mapping()
        if is_compact:
            fields = ['twcode', 'jcn', 'nomenclature', 'niin', 'part_no']
        else:
            fields = list(field_mapping.keys()) if is_staged else [f for f in field_mapping.values() if f is not None]

        for field in fields:
            if is_staged or field_mapping[field] is not None:
                value = record.get(field, '')
                if value is None:
                    value = ''
                field_widget = QLabel(f"{field}: {value}")
                if not is_staged and field_mapping[field] is not None:
                    match_quality = self.get_field_match_quality(self.current_staged_record, record, field)
                    field_widget.setStyleSheet(f"color: {match_quality};")
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

    def apply_selections(self):
        self.matches_applied.emit(self.accepted_matches)
        self.close()

    def get_summary_text(self):
        total_matches = len(self.potential_matches)
        high_quality_matches = sum(1 for match in self.potential_matches if match['score'] >= 80)
        medium_quality_matches = sum(1 for match in self.potential_matches if 50 <= match['score'] < 80)
        low_quality_matches = sum(1 for match in self.potential_matches if match['score'] < 50)

        summary_text = f"""
        Total Matches: {total_matches}
        High Quality Matches (>=80%): {high_quality_matches}
        Medium Quality Matches (50-79%): {medium_quality_matches}
        Low Quality Matches (<50%): {low_quality_matches}
        
        Field-specific Match Rates:
        """

        fields = ['twcode', 'jcn', 'nomenclature', 'niin', 'part_no']
        for field in fields:
            match_rate = self.calculate_field_match_rate(field)
            summary_text += f"\n{field.upper()}: {match_rate:.2f}%"

        return summary_text

    def create_side_by_side_view_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        # Add record selection controls
        selection_layout = QHBoxLayout()
        selection_layout.addWidget(QLabel("Select Record:"))
        self.record_selector = QComboBox()
        self.record_selector.addItems([f"Match #{i+1}" for i in range(len(self.potential_matches))])
        self.record_selector.currentIndexChanged.connect(self.update_side_by_side_view)
        selection_layout.addWidget(self.record_selector)
        layout.addLayout(selection_layout)

        # Create side-by-side view
        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        layout.addWidget(scroll_area)

        self.side_by_side_widget = QWidget()
        self.side_by_side_layout = QHBoxLayout(self.side_by_side_widget)
        scroll_area.setWidget(self.side_by_side_widget)

        self.update_side_by_side_view(0)
        self.tab_widget.addTab(tab, "Side-by-Side View")

    def update_side_by_side_view(self, index):
        # Clear existing widgets
        for i in reversed(range(self.side_by_side_layout.count())): 
            self.side_by_side_layout.itemAt(i).widget().setParent(None)

        match = self.potential_matches[index]
        staged_column = self.create_record_column(match['search_record'], is_staged=True, index=index)
        mrl_column = self.create_record_column(match['mrl_record'], is_staged=False, index=index)
        
        self.side_by_side_layout.addWidget(staged_column)
        self.side_by_side_layout.addWidget(mrl_column)

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

    def create_side_by_side_widget(self, match):
        widget = QWidget()
        layout = QHBoxLayout(widget)
        layout.setContentsMargins(0, 0, 0, 0)

        self.current_staged_record = match['search_record']
        staged_scroll = QScrollArea()
        mrl_scroll = QScrollArea()
        
        staged_column = self.create_record_column(match['search_record'], is_staged=True)
        mrl_column = self.create_record_column(match['mrl_record'], is_staged=False)
        
        staged_scroll.setWidget(staged_column)
        mrl_scroll.setWidget(mrl_column)
        
        staged_scroll.setWidgetResizable(True)
        mrl_scroll.setWidgetResizable(True)

        layout.addWidget(staged_scroll)
        layout.addWidget(mrl_scroll)
        layout.setStretchFactor(staged_scroll, 1)
        layout.setStretchFactor(mrl_scroll, 1)

        return widget

    def update_match_selection(self, index, state):
        self.match_selections[index] = state
        # Update checkboxes in all views
        self.update_main_view_checkboxes()
        self.update_side_by_side_view_checkbox()
        self.update_table_view_checkboxes()

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

        field_mapping = self.get_field_mapping()
        for field, mrl_field in field_mapping.items():
            if is_staged or mrl_field is not None:
                value = record.get(field if is_staged else mrl_field, '')
                if value is None:
                    value = ''
                field_widget = QLabel(f"{field}: {value}")
                if not is_staged and mrl_field is not None:
                    match_quality = self.get_field_match_quality(self.potential_matches[index]['search_record'], record, mrl_field)
                    field_widget.setStyleSheet(f"color: {match_quality};")
                column_layout.addWidget(field_widget)

        return column_widget

    def create_main_view_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        self.detail_view = True
        toggle_button = QPushButton("Switch to Summary View")
        toggle_button.clicked.connect(self.toggle_main_view)
        layout.addWidget(toggle_button)

        scroll_area = QScrollArea()
        scroll_area.setWidgetResizable(True)
        layout.addWidget(scroll_area)

        self.main_content = QWidget()
        self.main_layout = QVBoxLayout(self.main_content)
        scroll_area.setWidget(self.main_content)

        self.main_checkboxes = []
        for index, match in enumerate(self.potential_matches):
            match_widget = self.create_match_widget(match, index)
            self.main_layout.addWidget(match_widget)

        select_all_button = QPushButton("Select All/None")
        select_all_button.setCheckable(True)
        select_all_button.clicked.connect(self.toggle_all_selections)
        layout.addWidget(select_all_button)

        self.tab_widget.addTab(tab, "Main View")

    def toggle_all_selections(self):
        check_state = self.sender().isChecked()
        for checkbox in self.main_checkboxes:
            checkbox.setChecked(check_state)

    def toggle_all_table_selections(self):
        check_state = self.sender().isChecked()
        for row in range(0, self.table.rowCount(), 2):
            checkbox_item = self.table.item(row, 0)
            if checkbox_item:
                checkbox_item.setCheckState(Qt.Checked if check_state else Qt.Unchecked)

    def toggle_main_view(self):
        self.detail_view = not self.detail_view
        sender = self.sender()
        sender.setText("Switch to Detail View" if not self.detail_view else "Switch to Summary View")
        self.update_main_view()

    def update_main_view(self):
        for i in reversed(range(self.main_layout.count())): 
            self.main_layout.itemAt(i).widget().setParent(None)

        for match in sorted(self.potential_matches, key=lambda x: x['score'], reverse=True):
            if self.detail_view:
                match_widget = self.create_detail_match_widget(match)
            else:
                match_widget = self.create_summary_match_widget(match)
            self.main_layout.addWidget(match_widget)

    def get_field_mapping(self):
        mapping = {
            'jcn': 'jcn',
            'twcode': 'twcode',
            'nomenclature': 'nomenclature',
            'cog': 'cog',
            'fsc': 'fsc',
            'niin': 'niin',
            'part_no': 'part_no',
            'qty': 'qty',
            'ui': 'ui',
            'market_research_up': 'market_research_up',
            'market_research_ep': 'market_research_ep',
            'availability_identifier': 'availability_identifier',
            'request_date': 'request_date',
            'rdd': 'rdd',
            'pri': 'pri',
            'swlin': 'swlin',
            'hull_or_shop': 'hull_or_shop',
            'suggested_source': 'suggested_source',
            'mfg_cage': 'mfg_cage',
            'apl': 'apl',
            'nha_equipment_system': 'nha_equipment_system',
            'nha_model': 'nha_model',
            'nha_serial': 'nha_serial',
            'techmanual': 'techmanual',
            'dwg_pc': 'dwg_pc',
            'requestor_remarks': 'requestor_remarks'
        }
        # Add all other staged fields
        staged_only_fields = [
            'staged_id', 'preprocessed_id', 'raw_data_id', 'report_name', 'report_date', 
            'sheet_name', 'original_line', 'system_identifier_code', 'shipdoc_tcn', 
            'v2x_ship_no', 'booking', 'vessel', 'container', 'carrier', 'sail_date', 
            'edd_to_ches', 'edd_egypt', 'rcd_v2x_date', 'lot_id', 'triwall', 
            'lsc_on_hand_date', 'arr_lsc_egypt', 'milstrip_req_no'
        ]
        for field in staged_only_fields:
            mapping[field] = None
        return mapping

    def create_detail_match_widget(self, match):
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        self.current_staged_record = match['search_record']
        staged_row = self.create_record_row(match['search_record'], is_staged=True, is_compact=False)
        mrl_row = self.create_record_row(match['mrl_record'], is_staged=False, is_compact=False)
        
        layout.addWidget(staged_row)
        layout.addWidget(mrl_row)
        layout.addWidget(QLabel(f"Match Score: {match['score']:.2f}%"))
        
        return widget

    def create_summary_match_widget(self, match):
        widget = QWidget()
        layout = QVBoxLayout(widget)
        
        self.current_staged_record = match['search_record']
        staged_row = self.create_record_row(match['search_record'], is_staged=True, is_compact=True)
        mrl_row = self.create_record_row(match['mrl_record'], is_staged=False, is_compact=True)
        
        layout.addWidget(staged_row)
        layout.addWidget(mrl_row)
        layout.addWidget(QLabel(f"Match Score: {match['score']:.2f}%"))
        
        return widget
         
    def get_field_match_quality(self, staged_record, mrl_record, field):
        field_mapping = self.get_field_mapping()
        staged_field = next((k for k, v in field_mapping.items() if v == field), None)
        if not staged_field:
            return 'black'

        staged_value = str(staged_record.get(staged_field, '')).lower().strip()
        mrl_value = str(mrl_record.get(field, '')).lower().strip()
        
        if field == 'nomenclature':
            similarity = ratio(staged_value, mrl_value)
            if similarity > 0.8:
                return 'darkgreen'
            elif similarity > 0.5:
                return 'darkorange'
            else:
                return 'darkred'
        else:
            if staged_value == mrl_value and staged_value != '':
                return 'darkgreen'
            elif staged_value != mrl_value and staged_value != '' and mrl_value != '':
                return 'darkred'
            else:
                return 'black'

    def create_table_view_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        # Add filter controls
        filter_layout = QHBoxLayout()
        self.field_filter = QComboBox()
        self.field_filter.addItems(['All Fields'] + list(self.potential_matches[0]['search_record'].keys()))
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
        filtered_matches.sort(key=lambda x: x['score'], reverse=True)

        if not filtered_matches:
            self.table.setRowCount(0)
            self.table.setColumnCount(0)
            return

        field_mapping = self.get_field_mapping()
        headers = ['Select'] + list(field_mapping.keys())
        self.table.setColumnCount(len(headers))
        self.table.setHorizontalHeaderLabels(headers)

        # Missing line: Set the row count to accommodate all rows
        self.table.setRowCount(len(filtered_matches) * 2)

        for i, match in enumerate(filtered_matches):
            row = i * 2

            # Add checkbox
            checkbox_item = QTableWidgetItem()
            checkbox_item.setFlags(Qt.ItemIsUserCheckable | Qt.ItemIsEnabled)
            checkbox_item.setCheckState(Qt.Unchecked)
            self.table.setItem(row, 0, checkbox_item)

            row = i * 2 + 1
            for col, staged_field in enumerate(headers):
                mrl_field = field_mapping[staged_field]
                if mrl_field is not None:
                    value = match['mrl_record'].get(mrl_field, '')
                    if value is None:
                        value = ''
                    item = QTableWidgetItem(str(value))
                    item.setBackground(QColor('lightblue'))
                    match_quality = self.get_field_match_quality(
                        match['search_record'], match['mrl_record'], mrl_field
                    )
                    item.setForeground(QColor(match_quality))
                else:
                    item = QTableWidgetItem('')
                    item.setBackground(QColor('lightblue'))
                self.table.setItem(row, col, item)

            self.table.setRowHeight(row, self.table.rowHeight(row) + 2)

        self.table.resizeColumnsToContents()
        self.table.setSortingEnabled(True)

    def update_main_view_checkboxes(self):
        for index, checkbox in enumerate(self.main_checkboxes):
            checkbox.setChecked(self.match_selections[index])

    def update_side_by_side_view_checkbox(self):
        current_index = self.record_selector.currentIndex()
        # Assuming you add a checkbox to the side-by-side view
        if hasattr(self, 'side_by_side_checkbox'):
            self.side_by_side_checkbox.setChecked(self.match_selections[current_index])

    def update_table_view_checkboxes(self):
        for row in range(0, self.table.rowCount(), 2):  # Every other row is a match
            index = row // 2
            checkbox_item = self.table.item(row, 0)
            if checkbox_item and isinstance(checkbox_item, QTableWidgetItem):
                checkbox_item.setCheckState(Qt.Checked if self.match_selections[index] else Qt.Unchecked)

    def filter_matches(self, field_filter, quality_filter, search_text):
        filtered = self.potential_matches

        if field_filter != 'All Fields':
            filtered = [match for match in filtered if search_text in str(match['search_record'].get(field_filter, '')).lower() or 
                        search_text in str(match['mrl_record'].get(field_filter, '')).lower()]

        if quality_filter != 'All Qualities':
            if quality_filter == 'High (>=80%)':
                filtered = [match for match in filtered if match['score'] >= 80]
            elif quality_filter == 'Medium (50-79%)':
                filtered = [match for match in filtered if 50 <= match['score'] < 80]
            elif quality_filter == 'Low (<50%)':
                filtered = [match for match in filtered if match['score'] < 50]

        if search_text and field_filter == 'All Fields':
            filtered = [match for match in filtered if any(search_text in str(value).lower() for value in match['search_record'].values()) or
                        any(search_text in str(value).lower() for value in match['mrl_record'].values())]

        return filtered

    def create_summary_view_tab(self):
        tab = QWidget()
        layout = QVBoxLayout(tab)

        # Text summary
        summary_text = self.get_summary_text()
        summary_label = QLabel(summary_text)
        summary_label.setAlignment(Qt.AlignTop)
        layout.addWidget(summary_label)

        # Pie chart for match quality distribution
        quality_chart = self.create_quality_distribution_chart()
        layout.addWidget(quality_chart)

        # Bar chart for field-specific match rates
        field_chart = self.create_field_match_rate_chart()
        layout.addWidget(field_chart)

        self.tab_widget.addTab(tab, "Summary View")

    def add_bulk_accept_controls(self):
        layout = QHBoxLayout()

        self.threshold_slider = QSlider(Qt.Horizontal)
        self.threshold_slider.setRange(50, 100)
        self.threshold_slider.setValue(70)  # Default to 70%
        self.threshold_slider.setTickInterval(5)
        self.threshold_slider.setTickPosition(QSlider.TicksBelow)
        self.threshold_slider.setSingleStep(5)
        self.threshold_slider.setFixedWidth(150)

        self.threshold_label = QLabel("Threshold: 70%")
        self.threshold_slider.valueChanged.connect(self.update_threshold_label)

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
        threshold = self.threshold_slider.value()
        staged_ids = [match['search_record']['staged_id'] for match in self.potential_matches if match['score'] >= threshold]
        try:
            self.db.bulk_accept_staged_mrl_only_match(staged_ids, self.report_name, self.report_date, self.sheet_name)
            self.update_match_display()
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to perform bulk MRL accept: {str(e)}")
            logging.error(f"Bulk MRL accept failed: {str(e)}")

    def bulk_accept_both(self):
        threshold = self.threshold_slider.value()
        staged_ids = [match['search_record']['staged_id'] for match in self.potential_matches if match['score'] >= threshold]
        try:
            self.db.bulk_accept_staged_mrl_fulfillment_match(staged_ids, self.report_name, self.report_date, self.sheet_name)
            self.update_match_display()
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to perform bulk MRL+Fulfillment accept: {str(e)}")
            logging.error(f"Bulk MRL+Fulfillment accept failed: {str(e)}")

    def update_match_display(self):
        # Remove accepted matches from the display
        self.potential_matches = [match for match in self.potential_matches if match['search_record']['staged_id'] not in self.accepted_matches]
        self.update_main_view()
        self.update_table_view()
        self.create_summary_view_tab()  # Recreate the summary view with updated data

    def create_quality_distribution_chart(self):
        series = QPieSeries()
        high_quality = sum(1 for match in self.potential_matches if match['score'] >= 80)
        medium_quality = sum(1 for match in self.potential_matches if 50 <= match['score'] < 80)
        low_quality = sum(1 for match in self.potential_matches if match['score'] < 50)

        series.append("High Quality", high_quality)
        series.append("Medium Quality", medium_quality)
        series.append("Low Quality", low_quality)

        chart = QChart()
        chart.addSeries(series)
        chart.setTitle("Match Quality Distribution")

        chartview = QChartView(chart)
        chartview.setRenderHint(QPainter.Antialiasing)

        return chartview

    def create_field_match_rate_chart(self):
        fields = ['twcode', 'jcn', 'nomenclature', 'niin', 'part_no']
        match_rates = [self.calculate_field_match_rate(field) for field in fields]

        series = QBarSeries()
        bar_set = QBarSet("Match Rate")
        bar_set.append(match_rates)
        series.append(bar_set)

        chart = QChart()
        chart.addSeries(series)
        chart.setTitle("Field-specific Match Rates")

        axis_x = QBarCategoryAxis()
        axis_x.append(fields)
        chart.addAxis(axis_x, Qt.AlignBottom)
        series.attachAxis(axis_x)

        axis_y = QValueAxis()
        axis_y.setRange(0, 100)
        chart.addAxis(axis_y, Qt.AlignLeft)
        series.attachAxis(axis_y)

        chartview = QChartView(chart)
        chartview.setRenderHint(QPainter.Antialiasing)

        return chartview

    def calculate_field_match_rate(self, field):
        total = len(self.potential_matches)
        matches = sum(1 for match in self.potential_matches 
                      if str(match['search_record'].get(field, '')).lower() == 
                         str(match['mrl_record'].get(field, '')).lower())
        return (matches / total) * 100 if total > 0 else 0

