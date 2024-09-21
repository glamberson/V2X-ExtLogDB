import sys
import os
import traceback
from PySide6.QtWidgets import (
    QApplication,
    QMainWindow,
    QMessageBox,
    QTableWidgetItem,
    QHeaderView,
    QInputDialog,
    QDialog,
    QVBoxLayout,
    QPushButton,
    QTableWidget,
    QCheckBox,
    QLabel,
    QComboBox
)
from PySide6.QtCore import QFile, QIODevice, Qt, QSettings
from PySide6.QtUiTools import QUiLoader
from PySide6 import QtWidgets
import psycopg2
from psycopg2 import sql
import re
import difflib

print("Script started")

class FieldMappingTool(QMainWindow):
    def __init__(self):
        print("Initializing FieldMappingTool")
        super().__init__()
        self.known_fields = {}  # Initialize known_fields here
        self.field_data_types = {}
        self.unsaved_changes = False
        self.current_mapping_set_name = ""
        self.mappings_loaded = False
        self.previous_report_index = -1
        self.previous_sheet_index = -1
        self.db_connection = None
        try:
            self.load_ui()
            self.setup_ui()
            self.mapping_status_label = QLabel("No mapping set loaded")
            self.ui.verticalLayout.addWidget(self.mapping_status_label)
            self.setup_connections()
            self.connect_to_database()
            self.populate_field_types()
            self.populate_known_fields()
            print("FieldMappingTool initialized")
        except Exception as e:
            print(f"Error in FieldMappingTool initialization: {str(e)}")
            print(traceback.format_exc())
            sys.exit(-1)

    def load_ui(self):
        print("Loading UI")
        ui_file_name = "field_mapping_tool.ui"
        ui_file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ui_file_name)
        print(f"Looking for UI file at: {ui_file_path}")

        if not os.path.exists(ui_file_path):
            print(f"UI file not found at {ui_file_path}")
            sys.exit(-1)

        try:
            from PySide6.QtUiTools import loadUiType

            generated_class, base_class = loadUiType(ui_file_path)
            print("UI type loaded")

            class UiMainWindow(generated_class, base_class):
                def __init__(self):
                    super().__init__()
                    self.setupUi(self)

            self.ui = UiMainWindow()
            print("UI instance created")
            self.setCentralWidget(self.ui)
            print("Central widget set")
        except Exception as e:
            print(f"Error loading UI: {str(e)}")
            print(traceback.format_exc())
            sys.exit(-1)

        print("UI loaded successfully")

    def setup_connections(self):
        print("Setting up connections")
        try:
            self.ui.reportComboBox.currentIndexChanged.connect(self.load_sheets)
            self.ui.sheetComboBox.currentIndexChanged.connect(self.load_column_names)
            self.ui.applyMappingButton.clicked.connect(self.apply_mapping)
            self.ui.saveMappingSetButton.clicked.connect(self.save_mapping_set)
            self.ui.loadMappingSetButton.clicked.connect(self.load_mapping_set)
            self.ui.fieldTypeComboBox.currentIndexChanged.connect(
                self.update_known_fields
            )
            self.ui.columnNamesTable.itemSelectionChanged.connect(
                self.update_mapping_controls
            )
            self.ui.compareMappingsButton.clicked.connect(self.compare_mappings)

            print("Connections set up successfully")
        except Exception as e:
            print(f"Error setting up connections: {str(e)}")
            print(traceback.format_exc())

    def connect_to_database(self):
        print("Connecting to database")
        try:
            self.db_connection = psycopg2.connect(
                dbname="ReportsDB",
                user="postgres",
                password="123456",
                host="cmms-db-01",
                port="5432",
            )
            print("Connected to the database successfully!")
            self.load_reports()
        except (Exception, psycopg2.Error) as error:
            print("Error while connecting to PostgreSQL", error)
            print(traceback.format_exc())
            QMessageBox.critical(self, "Database Connection Error", str(error))

    def setup_ui(self):
        # Make the main window and column_names table bigger
        self.resize(1200, 800)
        self.ui.columnNamesTable.setMinimumHeight(400)
        self.ui.columnNamesTable.setColumnWidth(0, 50)  # Checkbox column
        self.ui.columnNamesTable.setColumnWidth(1, 200)  # Column Name
        self.ui.columnNamesTable.setColumnWidth(2, 100)  # Field Type
        self.ui.columnNamesTable.setColumnWidth(3, 200)  # Mapped Field
        # Make the column_names table columns adjustable
        self.ui.columnNamesTable.horizontalHeader().setSectionResizeMode(
            QHeaderView.Interactive
        )

        # Set the original column_names data to be read-only
        self.ui.columnNamesTable.setEditTriggers(
            QtWidgets.QAbstractItemView.NoEditTriggers
        )

        # Ensure the custom name field is populated with the original field name
        self.ui.columnNamesTable.itemSelectionChanged.connect(self.update_custom_name)

        self.dataTypeComboBox = QComboBox()
        self.dataTypeComboBox.addItems(['VARCHAR', 'TEXT', 'INT', 'MONEY', 'DATE', 'BOOLEAN', 'TIMESTAMPTZ'])
        self.ui.mappingGroupBox.layout().addWidget(QLabel("Data Type:"))
        self.ui.mappingGroupBox.layout().addWidget(self.dataTypeComboBox)

        # Load user's preference
        self.settings = QSettings("YourCompany", "FieldMappingTool")
        apply_default = self.settings.value("apply_default_mappings", True, type=bool)

        # Add a checkbox to apply default mappings
        self.apply_default_checkbox = QCheckBox("Apply default mappings if no existing mappings are found")
        self.apply_default_checkbox.setChecked(apply_default)
        self.ui.verticalLayout.addWidget(self.apply_default_checkbox)

        # Connect checkbox state change to save the preference
        self.apply_default_checkbox.stateChanged.connect(self.save_apply_default_preference)

        # Add mapping status label
        self.mapping_status_label = QLabel("No mapping set loaded")
        self.ui.verticalLayout.addWidget(self.mapping_status_label)

    def save_apply_default_preference(self, state):
        self.settings.setValue("apply_default_mappings", state == Qt.Checked)

    def load_reports(self):
        if not self.db_connection:
            return

        try:
            cursor = self.db_connection.cursor()
            cursor.execute(
                """
                SELECT DISTINCT report_name, report_date 
                FROM raw_egypt_weekly_reports 
                ORDER BY report_date DESC, report_name
            """
            )
            reports = cursor.fetchall()

            self.ui.reportComboBox.clear()
            for report in reports:
                self.ui.reportComboBox.addItem(f"{report[0]} - {report[1]}", report)

            cursor.close()
        except (Exception, psycopg2.Error) as error:
            print("Error while fetching reports:", error)
            print(traceback.format_exc())
            QMessageBox.warning(self, "Database Error", str(error))

    def load_sheets(self, index):
        if index < 0 or not self.db_connection:
            return

        if self.unsaved_changes:
            save_changes = QMessageBox.question(
                self,
                "Unsaved Changes",
                "You have unsaved changes. Do you want to save them before proceeding?",
                QMessageBox.Yes | QMessageBox.No | QMessageBox.Cancel,
                QMessageBox.Yes
            )
            if save_changes == QMessageBox.Yes:
                self.save_mapping_set()
            elif save_changes == QMessageBox.Cancel:
                # Abort loading new sheets
                self.ui.reportComboBox.setCurrentIndex(self.previous_report_index)
                return

        report_data = self.ui.reportComboBox.itemData(index)
        if not report_data:
            return

        report_name, report_date = report_data

        try:
            cursor = self.db_connection.cursor()
            cursor.execute(
                """
                SELECT sheet_name, COUNT(*) as sheet_count
                FROM raw_egypt_weekly_reports
                WHERE report_name = %s AND report_date = %s
                GROUP BY sheet_name
                """,
                (report_name, report_date),
            )
            sheets = cursor.fetchall()

            self.ui.sheetComboBox.clear()
            total_sheets = 0
            for sheet in sheets:
                self.ui.sheetComboBox.addItem(sheet[0], sheet)
                total_sheets += sheet[1]

            self.ui.numSheetsValue.setText(str(total_sheets))

            cursor.close()
            self.previous_report_index = index  # Update previous_report_index
        except (Exception, psycopg2.Error) as error:
            print("Error while fetching sheets:", error)
            print(traceback.format_exc())
            QMessageBox.warning(self, "Database Error", str(error))

    def clear_current_mappings(self):
        for row in range(self.ui.columnNamesTable.rowCount()):
            self.ui.columnNamesTable.item(row, 0).setCheckState(Qt.Unchecked)
            self.ui.columnNamesTable.setItem(row, 2, QTableWidgetItem(""))
            self.ui.columnNamesTable.setItem(row, 3, QTableWidgetItem(""))
        self.mapping_status_label.setText("No mapping set loaded")

    def parse_column_names(self, column_names):
        print(f"Parsing column names: {type(column_names)}")  # Debug print
        if isinstance(column_names, list):
            return [col.strip('"').strip() for col in column_names]
        elif isinstance(column_names, str):
            # Remove curly braces and split the string
            column_names = column_names.strip("{}")
            # Split by comma, but not within double quotes
            columns = re.findall(r'"[^"]*"|\S+', column_names)
            # Remove any remaining quotes and trim whitespace
            return [col.strip('"').strip() for col in columns]
        else:
            print(f"Unexpected type for column_names: {type(column_names)}")
            return []

    def populate_field_types(self):
        field_types = ["mrl", "fulfillment", "additional", "identifier"]
        self.ui.fieldTypeComboBox.addItems(field_types)

    def populate_known_fields(self):
        mrl_fields = [
            "jcn", "twcode", "nomenclature", "cog", "fsc", "niin", "part_no", "qty", "ui",
            "market_research_up", "market_research_ep", "availability_identifier",
            "request_date", "rdd", "pri", "swlin", "hull_or_shop", "suggested_source",
            "mfg_cage", "apl", "nha_equipment_system", "nha_model", "nha_serial",
            "techmanual", "dwg_pc", "requestor_remarks"
        ]
        fulfillment_fields = [
            "shipdoc_tcn", "v2x_ship_no", "booking", "vessel", "container", "carrier",
            "sail_date", "edd_to_ches", "edd_egypt", "rcd_v2x_date", "lot_id", "triwall",
            "lsc_on_hand_date", "arr_lsc_egypt", "milstrip_req_no"
        ]
        self.known_fields = {"mrl": mrl_fields, "fulfillment": fulfillment_fields}
        self.ui.knownFieldComboBox.addItems(mrl_fields + fulfillment_fields)

        # Define data types for each field
        self.field_data_types = {
            # MRL fields
            "jcn": "VARCHAR(50)", "twcode": "VARCHAR(50)", "nomenclature": "TEXT",
            "cog": "VARCHAR(10)", "fsc": "VARCHAR(10)", "niin": "VARCHAR(20)",
            "part_no": "VARCHAR(50)", "qty": "INT", "ui": "VARCHAR(10)",
            "market_research_up": "MONEY", "market_research_ep": "MONEY",
            "availability_identifier": "INT", "request_date": "DATE", "rdd": "DATE",
            "pri": "VARCHAR(10)", "swlin": "VARCHAR(20)", "hull_or_shop": "VARCHAR(20)",
            "suggested_source": "TEXT", "mfg_cage": "VARCHAR(20)", "apl": "VARCHAR(50)",
            "nha_equipment_system": "TEXT", "nha_model": "TEXT", "nha_serial": "TEXT",
            "techmanual": "TEXT", "dwg_pc": "TEXT", "requestor_remarks": "TEXT",
            # Fulfillment fields
            "shipdoc_tcn": "VARCHAR(30)", "v2x_ship_no": "VARCHAR(20)",
            "booking": "VARCHAR(20)", "vessel": "VARCHAR(30)", "container": "VARCHAR(25)",
            "carrier": "VARCHAR(50)", "sail_date": "DATE", "edd_to_ches": "DATE",
            "edd_egypt": "DATE", "rcd_v2x_date": "DATE", "lot_id": "VARCHAR(15)",
            "triwall": "VARCHAR(15)", "lsc_on_hand_date": "DATE", "arr_lsc_egypt": "DATE",
            "milstrip_req_no": "VARCHAR(25)"
        }
    
    def update_data_type_for_field(self, field_name):
        data_type = self.field_data_types.get(field_name, "VARCHAR")
        index = self.dataTypeComboBox.findText(data_type.split('(')[0])
        if index >= 0:
            self.dataTypeComboBox.setCurrentIndex(index)

    def update_known_fields(self):
        field_type = self.ui.fieldTypeComboBox.currentText()
        if field_type in self.known_fields:
            self.ui.knownFieldComboBox.clear()
            self.ui.knownFieldComboBox.addItems(self.known_fields[field_type])
        else:
            self.ui.knownFieldComboBox.clear()

    def update_custom_name(self):
        selected_items = self.ui.columnNamesTable.selectedItems()
        if selected_items:
            original_name = selected_items[0].text()
            self.ui.customNameLineEdit.setText(original_name)

    def update_mapping_controls(self):
        selected_items = self.ui.columnNamesTable.selectedItems()
        if selected_items:
            row = selected_items[0].row()
            field_type_item = self.ui.columnNamesTable.item(row, 2)
            target_field_item = self.ui.columnNamesTable.item(row, 3)

            if field_type_item and target_field_item:
                field_type = field_type_item.text()
                target_field = target_field_item.text()

                self.ui.fieldTypeComboBox.setCurrentText(field_type)
                if field_type in ["mrl", "fulfillment"]:
                    self.ui.knownFieldComboBox.setCurrentText(target_field)
                    self.update_data_type_for_field(target_field)
                    self.update_data_type_combobox(target_field)  # Add this line
                else:
                    self.ui.customNameLineEdit.setText(target_field)
            else:
                self.ui.fieldTypeComboBox.setCurrentIndex(0)
                self.ui.knownFieldComboBox.setCurrentIndex(0)
                self.ui.customNameLineEdit.clear()
                self.dataTypeComboBox.setCurrentIndex(0)

    def update_data_type_combobox(self, field_name):
        data_type = self.field_data_types.get(field_name, "VARCHAR")
        index = self.dataTypeComboBox.findText(data_type.split('(')[0])
        if index >= 0:
            self.dataTypeComboBox.setCurrentIndex(index)

    def apply_mapping(self):
        print("Applying mapping")
        selected_items = self.ui.columnNamesTable.selectedItems()
        if not selected_items:
            QMessageBox.warning(self, "Selection Error", "Please select a field to map.")
            return

        raw_field_name = selected_items[0].text()
        field_type = self.ui.fieldTypeComboBox.currentText()
        target_field_name = (
            self.ui.knownFieldComboBox.currentText()
            if field_type in ["mrl", "fulfillment"]
            else self.ui.customNameLineEdit.text()
        )

        if not target_field_name:
            QMessageBox.warning(
                self,
                "Input Error",
                "Please select a known field or enter a custom name.",
            )
            return

        # Determine the data type
        if target_field_name in self.field_data_types:
            data_type = self.field_data_types[target_field_name]
        else:
            data_type = self.dataTypeComboBox.currentText()

        # Update the columnNamesTable with the mapping
        row = selected_items[0].row()
        self.ui.columnNamesTable.item(row, 0).setCheckState(Qt.Checked)
        self.ui.columnNamesTable.setItem(row, 2, QTableWidgetItem(field_type))
        self.ui.columnNamesTable.setItem(row, 3, QTableWidgetItem(target_field_name))
        self.update_data_type_combobox(target_field_name)
        
        print(f"Mapped {raw_field_name} to {target_field_name} as {field_type} with data type {data_type}")

        # Highlight the mapped row
        self.ui.columnNamesTable.selectRow(row)
        self.ui.columnNamesTable.item(row, 1).setBackground(Qt.yellow)
        self.ui.columnNamesTable.item(row, 2).setBackground(Qt.yellow)
        self.ui.columnNamesTable.item(row, 3).setBackground(Qt.yellow)        

        # Insert or update the mapping in the database
        try:
            cursor = self.db_connection.cursor()
            cursor.execute(
                """
                INSERT INTO field_mappings 
                (raw_data_id, raw_field_name, mapping_type, target_field_name, data_type)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (raw_data_id, raw_field_name) 
                DO UPDATE SET 
                    mapping_type = EXCLUDED.mapping_type, 
                    target_field_name = EXCLUDED.target_field_name,
                    data_type = EXCLUDED.data_type;
                """,
                (self.ui.rawDataIdValue.text(), raw_field_name, field_type, target_field_name, data_type)
            )
            self.db_connection.commit()
            print(f"Inserted/Updated mapping in database: {raw_field_name} -> {target_field_name} ({field_type}, {data_type})")
        except (Exception, psycopg2.Error) as error:
            self.db_connection.rollback()
            error_message = f"Error while inserting/updating mapping: {str(error)}\n\n{traceback.format_exc()}"
            print(error_message)
            QMessageBox.warning(self, "Database Error", error_message)
        
        # If the current mapping set is the default and mappings are modified
        if self.current_mapping_set_name == "Default Mapping":
            save_default = QMessageBox.question(
                self,
                "Save Changes to Default Mapping",
                "You have modified the default mapping. Do you want to save these changes to the default mapping set?",
                QMessageBox.Yes | QMessageBox.No
            )
            if save_default == QMessageBox.Yes:
                self.save_mapping_set()
            else:
                # Optionally, prompt to save as a new mapping set
                pass

        self.unsaved_changes = True
        self.update_mapping_status_label()

    def update_mapping_status_label(self):
        status = f"Loaded mappings from set: {self.current_mapping_set_name}"
        if self.unsaved_changes:
            status += " (unsaved changes)"
        self.mapping_status_label.setText(status)

    def refresh_ui(self):
        self.update_mapping_status_label()
        # Any other UI updates needed
  
    def apply_default_mapping(self):
        # Get the default mapping set ID
        cursor = self.db_connection.cursor()
        cursor.execute(
            """
            SELECT set_id FROM mapping_sets WHERE set_name = 'Default Mapping'
            """
        )
        result = cursor.fetchone()
        if result:
            default_set_id = result[0]
            self.apply_mapping_set(default_set_id, self.ui.rawDataIdValue.text())
        else:
            QMessageBox.warning(self, "Default Mapping Not Found", "No default mapping set found.")

    def apply_mapping_set(self, set_id, raw_data_id):
        try:
            cursor = self.db_connection.cursor()
            cursor.execute(
                """
                SELECT raw_field_name, mapping_type, target_field_name, data_type
                FROM field_mappings
                WHERE set_id = %s
                """,
                (set_id,)
            )
            mappings = cursor.fetchall()
            if mappings:
                # Update the interface with the loaded mappings
                for mapping in mappings:
                    raw_field_name, mapping_type, target_field_name, data_type = mapping
                    for row in range(self.ui.columnNamesTable.rowCount()):
                        if self.ui.columnNamesTable.item(row, 1).text() == raw_field_name:
                            self.ui.columnNamesTable.item(row, 0).setCheckState(Qt.Checked)
                            self.ui.columnNamesTable.setItem(row, 2, QTableWidgetItem(mapping_type))
                            self.ui.columnNamesTable.setItem(row, 3, QTableWidgetItem(target_field_name))
                            break
                # Update current mapping set name
                cursor.execute(
                    """
                    SELECT set_name
                    FROM mapping_sets
                    WHERE set_id = %s
                    """,
                    (set_id,)
                )
                set_name = cursor.fetchone()[0]
                self.current_mapping_set_name = set_name
                self.mapping_status_label.setText(f"Applied mappings from set: {set_name}")
                self.unsaved_changes = False  # No unsaved changes after applying mapping set
            else:
                self.unsaved_changes = False
                self.mapping_status_label.setText("No mappings found in the selected set.")
        except (Exception, psycopg2.Error) as error:
            print("Error while applying mapping set:", error)
            print(traceback.format_exc())
            QMessageBox.warning(self, "Database Error", str(error))
        finally:
            if cursor:
                cursor.close()

    def save_mapping_set(self):
        print("Saving mapping set")
        mapping_set_name = self.ui.setNameLineEdit.text().strip()
        if not mapping_set_name:
            QMessageBox.warning(
                self, "Input Error", "Please enter a name for the mapping set."
            )
            return

        description = self.ui.descriptionLineEdit.text().strip()
        report_type = self.ui.reportTypeLineEdit.text().strip()

        try:
            cursor = self.db_connection.cursor()

            # Insert or update mapping set
            cursor.execute(
                """
                INSERT INTO mapping_sets (set_name, description, report_type)
                VALUES (%s, %s, %s)
                ON CONFLICT (set_name) DO UPDATE
                SET description = EXCLUDED.description, report_type = EXCLUDED.report_type
                RETURNING set_id;
                """,
                (mapping_set_name, description, report_type),
            )
            set_id = cursor.fetchone()[0]
            print(f"Inserted/Updated mapping set with ID: {set_id}")

            # Save individual field mappings
            mappings_inserted = 0
            mappings_updated = 0
            for row in range(self.ui.columnNamesTable.rowCount()):
                raw_field_name = self.ui.columnNamesTable.item(row, 1).text()
                field_type = (
                    self.ui.columnNamesTable.item(row, 2).text()
                    if self.ui.columnNamesTable.item(row, 2)
                    else ""
                )
                target_field_name = (
                    self.ui.columnNamesTable.item(row, 3).text()
                    if self.ui.columnNamesTable.item(row, 3)
                    else ""
                )

                if field_type and target_field_name:
                    cursor.execute(
                        """
                        INSERT INTO field_mappings (raw_data_id, raw_field_name, mapping_type, set_id, target_field_name, data_type)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        ON CONFLICT (raw_data_id, raw_field_name) DO UPDATE
                        SET mapping_type = EXCLUDED.mapping_type,
                            set_id = EXCLUDED.set_id,
                            target_field_name = EXCLUDED.target_field_name,
                            data_type = EXCLUDED.data_type;
                        """,
                        (
                            self.ui.rawDataIdValue.text(),
                            raw_field_name,
                            field_type,
                            set_id,
                            target_field_name,
                            self.field_data_types.get(target_field_name, "VARCHAR")
                        ),
                    )
                    if cursor.rowcount == 1:
                        mappings_inserted += 1
                    else:
                        mappings_updated += 1
                    print(
                        f"Inserted/Updated mapping: {raw_field_name} -> {target_field_name} ({field_type})"
                    )

            self.db_connection.commit()
            print(
                f"Committed {mappings_inserted} new mappings and updated {mappings_updated} existing mappings to the database."
            )
            self.mapping_status_label.setText(f"Saved mappings for set: {set_id}")
            self.unsaved_changes = False
            self.update_mapping_status_label()

            QMessageBox.information(
                self,
                "Success",
                f"Mapping set saved successfully. {mappings_inserted} field mappings inserted, {mappings_updated} updated.",
            )
        except (Exception, psycopg2.Error) as error:
            self.db_connection.rollback()
            error_message = f"Error while saving mapping set: {str(error)}\n\n{traceback.format_exc()}"
            print(error_message)
            QMessageBox.warning(self, "Database Error", error_message)
        finally:
            if cursor:
                cursor.close()

    def load_column_names(self, index):
        if index < 0 or not self.db_connection:
            return

        if self.unsaved_changes:
            save_changes = QMessageBox.question(
                self,
                "Unsaved Changes",
                "You have unsaved changes. Do you want to save them before proceeding?",
                QMessageBox.Yes | QMessageBox.No | QMessageBox.Cancel,
                QMessageBox.Yes
            )
            if save_changes == QMessageBox.Yes:
                self.save_mapping_set()
            elif save_changes == QMessageBox.Cancel:
                # Abort loading new columns
                self.ui.sheetComboBox.setCurrentIndex(self.previous_sheet_index)
                return

        self.clear_current_mappings()

        sheet_data = self.ui.sheetComboBox.itemData(index)
        if not sheet_data:
            return

        sheet_name = sheet_data[0]
        report_data = self.ui.reportComboBox.currentData()
        if not report_data:
            return

        report_name, report_date = report_data

        try:
            cursor = self.db_connection.cursor()
            cursor.execute(
                """
                SELECT raw_data_id, column_names
                FROM raw_egypt_weekly_reports
                WHERE report_name = %s AND report_date = %s AND sheet_name = %s
                LIMIT 1
                """,
                (report_name, report_date, sheet_name),
            )
            result = cursor.fetchone()

            if result:
                raw_data_id, column_names = result
                self.ui.rawDataIdValue.setText(str(raw_data_id))

                print(f"Raw column_names: {column_names}")  # Debug print

                # Parse column_names
                column_names = self.parse_column_names(column_names)

                print(f"Parsed column_names: {column_names}")  # Debug print

                self.ui.columnNamesTable.setRowCount(len(column_names))
                self.ui.columnNamesTable.setColumnCount(4)
                self.ui.columnNamesTable.setHorizontalHeaderLabels(
                    ["Select", "Column Name", "Field Type", "Mapped Field"]
                )

                for i, column_name in enumerate(column_names):
                    checkbox = QTableWidgetItem()
                    checkbox.setFlags(Qt.ItemIsUserCheckable | Qt.ItemIsEnabled)
                    checkbox.setCheckState(Qt.Unchecked)
                    self.ui.columnNamesTable.setItem(i, 0, checkbox)
                    self.ui.columnNamesTable.setItem(i, 1, QTableWidgetItem(column_name))

                print(f"Loaded {len(column_names)} fields.")

                # Attempt to load existing mappings
                self.load_existing_mappings(raw_data_id)

                # If no existing mappings and the checkbox is checked, apply default mappings
                if not self.mappings_loaded and self.apply_default_checkbox.isChecked():
                    self.apply_default_mapping()

                self.previous_sheet_index = index  # Update previous_sheet_index
            else:
                print("No column names found for the selected report and sheet.")

            cursor.close()
        except (Exception, psycopg2.Error) as error:
            print("Error while fetching column names:", error)
            print(traceback.format_exc())
            QMessageBox.warning(self, "Database Error", str(error))

    def load_existing_mappings(self, raw_data_id):
        try:
            cursor = self.db_connection.cursor()
            cursor.execute(
                """
                SELECT raw_field_name, mapping_type, target_field_name, data_type, set_id
                FROM field_mappings
                WHERE raw_data_id = %s
                """,
                (raw_data_id,)
            )
            mappings = cursor.fetchall()
            if mappings:
                self.mappings_loaded = True
                self.unsaved_changes = False  # No unsaved changes after loading
                # Update the interface with the loaded mappings
                for mapping in mappings:
                    raw_field_name, mapping_type, target_field_name, data_type, set_id = mapping
                    for row in range(self.ui.columnNamesTable.rowCount()):
                        if self.ui.columnNamesTable.item(row, 1).text() == raw_field_name:
                            self.ui.columnNamesTable.item(row, 0).setCheckState(Qt.Checked)
                            self.ui.columnNamesTable.setItem(row, 2, QTableWidgetItem(mapping_type))
                            self.ui.columnNamesTable.setItem(row, 3, QTableWidgetItem(target_field_name))
                            break
                # Get the mapping set name
                cursor.execute(
                    """
                    SELECT set_name
                    FROM mapping_sets
                    WHERE set_id = %s
                    """,
                    (set_id,)
                )
                set_name = cursor.fetchone()[0]
                self.current_mapping_set_name = set_name
                self.mapping_status_label.setText(f"Loaded mappings from set: {set_name}")
            else:
                self.mappings_loaded = False
                self.mapping_status_label.setText("No existing mappings found.")
        except (Exception, psycopg2.Error) as error:
            print("Error while loading existing mappings:", error)
            print(traceback.format_exc())
            QMessageBox.warning(self, "Database Error", str(error))
        finally:
            if cursor:
                cursor.close()

    def load_mapping_set(self):
        self.clear_current_mappings()
        print("Loading mapping set")
        try:
            cursor = self.db_connection.cursor()
            cursor.execute(
                "SELECT set_id, set_name FROM mapping_sets ORDER BY set_name"
            )
            mapping_sets = cursor.fetchall()

            if not mapping_sets:
                QMessageBox.information(
                    self, "No Mapping Sets", "No mapping sets found in the database."
                )
                return

            set_names = [f"{set_id}: {set_name}" for set_id, set_name in mapping_sets]
            selected_set, ok = QInputDialog.getItem(
                self,
                "Select Mapping Set",
                "Choose a mapping set to load:",
                set_names,
                0,
                False,
            )

            if ok and selected_set:
                set_id = int(selected_set.split(":")[0])
                self.load_mappings_for_set(set_id)
        except (Exception, psycopg2.Error) as error:
            error_message = f"Error while loading mapping sets: {str(error)}\n\n{traceback.format_exc()}"
            print(error_message)
            QMessageBox.warning(self, "Database Error", error_message)
        finally:
            if cursor:
                cursor.close()

    def load_mappings_for_set(self, set_id):
        try:
            cursor = self.db_connection.cursor()
            cursor.execute(
                """
                SELECT raw_field_name, mapping_type, target_field_name 
                FROM field_mappings 
                WHERE set_id = %s AND raw_data_id = %s
            """,
                (set_id, self.ui.rawDataIdValue.text()),
            )
            mappings = cursor.fetchall()

            for row in range(self.ui.columnNamesTable.rowCount()):
                raw_field_name = self.ui.columnNamesTable.item(row, 1).text()
                mapping = next((m for m in mappings if m[0] == raw_field_name), None)
                if mapping:
                    self.ui.columnNamesTable.item(row, 0).setCheckState(Qt.Checked)
                    self.ui.columnNamesTable.setItem(
                        row, 2, QTableWidgetItem(mapping[1])
                    )
                    self.ui.columnNamesTable.setItem(
                        row, 3, QTableWidgetItem(mapping[2])
                    )
                else:
                    self.ui.columnNamesTable.item(row, 0).setCheckState(Qt.Unchecked)
                    self.ui.columnNamesTable.setItem(row, 2, QTableWidgetItem(""))
                    self.ui.columnNamesTable.setItem(row, 3, QTableWidgetItem(""))

            self.mapping_status_label.setText(f"Proposed mappings from set: {set_id}")

            QMessageBox.information(
                self,
                "Mapping Set Loaded",
                f"Loaded {len(mappings)} mappings from the selected set.",
            )
            self.refresh_ui()
        except (Exception, psycopg2.Error) as error:
            error_message = f"Error while loading mappings for set: {str(error)}\n\n{traceback.format_exc()}"
            print(error_message)
            QMessageBox.warning(self, "Database Error", error_message)
        finally:
            if cursor:
                cursor.close()

    def compare_mappings(self):
        print("Comparing mappings")
        try:
            cursor = self.db_connection.cursor()

            # Get all existing mapping sets
            cursor.execute("SELECT set_id, set_name FROM mapping_sets")
            mapping_sets = cursor.fetchall()

            if not mapping_sets:
                QMessageBox.information(
                    self,
                    "No Mapping Sets",
                    "No existing mapping sets found for comparison.",
                )
                return

            current_columns = [
                self.ui.columnNamesTable.item(row, 1).text()
                for row in range(self.ui.columnNamesTable.rowCount())
            ]

            best_matches = {}
            for set_id, set_name in mapping_sets:
                cursor.execute(
                    """
                    SELECT raw_field_name, mapping_type, target_field_name 
                    FROM field_mappings 
                    WHERE set_id = %s
                """,
                    (set_id,),
                )
                existing_mappings = cursor.fetchall()

                for current_col in current_columns:
                    best_match = self.find_best_match(current_col, existing_mappings)
                    if best_match:
                        if (
                            current_col not in best_matches
                            or best_matches[current_col][1] < best_match[1]
                        ):
                            best_matches[current_col] = (
                                best_match[0],
                                best_match[1],
                                set_name,
                            )

            if not best_matches:
                QMessageBox.information(
                    self, "No Matches", "No suitable matches found for comparison."
                )
                return

            self.display_suggested_mappings(best_matches)

        except (Exception, psycopg2.Error) as error:
            error_message = (
                f"Error while comparing mappings: {str(error)}\n\n{traceback.format_exc()}"
            )
            print(error_message)
            QMessageBox.warning(self, "Comparison Error", error_message)
        finally:
            if cursor:
                cursor.close()

    def toggle_all_checkboxes(self, table, state):
        for row in range(table.rowCount()):
            checkbox = table.cellWidget(row, 0)
            if checkbox and isinstance(checkbox, QCheckBox):
                checkbox.setChecked(state == Qt.Checked)

    def display_suggested_mappings(self, best_matches):
        suggestion_dialog = QDialog(self)
        suggestion_dialog.setWindowTitle("Suggested Mappings")
        layout = QVBoxLayout()

        select_all_checkbox = QCheckBox("Select All")
        layout.addWidget(select_all_checkbox)

        table = QTableWidget()
        table.setColumnCount(6)
        table.setHorizontalHeaderLabels(["Select", "Current Field", "Suggested Field", "Mapping Type", "Target Field", "Mapping Set"])
        table.setRowCount(len(best_matches))

        for row, (current_field, (suggested_field, ratio, set_name)) in enumerate(best_matches.items()):
            checkbox = QCheckBox()
            table.setCellWidget(row, 0, checkbox)
        
            table.setItem(row, 1, QTableWidgetItem(current_field))
            table.setItem(row, 2, QTableWidgetItem(suggested_field[0]))
            table.setItem(row, 3, QTableWidgetItem(suggested_field[1]))
            table.setItem(row, 4, QTableWidgetItem(suggested_field[2]))
            table.setItem(row, 5, QTableWidgetItem(set_name))

        select_all_checkbox.stateChanged.connect(lambda state: self.toggle_all_checkboxes(table, state))

        table.resizeColumnsToContents()
        layout.addWidget(table)

        apply_button = QPushButton("Apply Selected Mappings")
        apply_button.clicked.connect(lambda: self.apply_suggested_mappings(table))
        layout.addWidget(apply_button)

        suggestion_dialog.setLayout(layout)
        suggestion_dialog.exec_()

    def find_best_match(self, current_field, existing_mappings):
        best_match = None
        highest_ratio = 0
        for raw_field, mapping_type, target_field in existing_mappings:
            ratio = difflib.SequenceMatcher(None, current_field.lower(), raw_field.lower()).ratio()
            if ratio > highest_ratio:
                highest_ratio = ratio
                best_match = (raw_field, mapping_type, target_field)
        
        return (best_match, highest_ratio) if best_match and highest_ratio > 0.6 else None


    def apply_suggested_mappings(self, table):
        applied_count = 0
        database_update_count = 0
        try:
            cursor = self.db_connection.cursor()
            for row in range(table.rowCount()):
                checkbox = table.cellWidget(row, 0)
                if checkbox.isChecked():
                    current_field = table.item(row, 1).text()
                    mapping_type = table.item(row, 3).text()
                    target_field = table.item(row, 4).text()
                    data_type = self.field_data_types.get(target_field, "VARCHAR")

                    # Update the UI
                    for i in range(self.ui.columnNamesTable.rowCount()):
                        if self.ui.columnNamesTable.item(i, 1).text() == current_field:
                            self.ui.columnNamesTable.item(i, 0).setCheckState(Qt.Checked)
                            self.ui.columnNamesTable.setItem(i, 2, QTableWidgetItem(mapping_type))
                            self.ui.columnNamesTable.setItem(i, 3, QTableWidgetItem(target_field))
                            applied_count += 1
                            break

                    # Update the database
                    cursor.execute(
                        """
                        INSERT INTO field_mappings (raw_data_id, raw_field_name, mapping_type, target_field_name, data_type)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (raw_data_id, raw_field_name) 
                        DO UPDATE SET 
                            mapping_type = EXCLUDED.mapping_type, 
                            target_field_name = EXCLUDED.target_field_name,
                            data_type = EXCLUDED.data_type;
                        """,
                        (
                            self.ui.rawDataIdValue.text(),
                            current_field,
                            mapping_type,
                            target_field,
                            data_type,
                        ),
                    )
                    database_update_count += 1

            self.db_connection.commit()
            QMessageBox.information(
                self,
                "Mappings Applied",
                f"{applied_count} mappings have been applied to the UI.\n"
                f"{database_update_count} mappings have been updated in the database.",
            )
        except (Exception, psycopg2.Error) as error:
            self.db_connection.rollback()
            error_message = f"Error while applying suggested mappings: {str(error)}\n\n{traceback.format_exc()}"
            print(error_message)
            QMessageBox.warning(self, "Database Error", error_message)
        finally:
            if cursor:
                cursor.close()

        # Update the mapping status label
        self.mapping_status_label.setText(f"Applied {applied_count} suggested mappings")

        # Update the mapping status label
        self.mapping_status_label.setText(f"Applied {applied_count} suggested mappings")


if __name__ == "__main__":
    try:
        print("Creating QApplication")
        app = QApplication(sys.argv)
        print("Creating FieldMappingTool instance")
        window = FieldMappingTool()
        print("Showing window")
        window.show()
        print("Entering event loop")
        sys.exit(app.exec())
    except Exception as e:
        print(f"Unhandled exception: {str(e)}")
        print(traceback.format_exc())
        sys.exit(-1)
