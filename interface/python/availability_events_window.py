import logging
from PySide6.QtWidgets import QMainWindow, QMessageBox, QTableWidgetItem, QDateEdit
from PySide6.QtCore import QFile, Qt, QDate, Signal
from PySide6.QtUiTools import QUiLoader
from database_manager import DatabaseManager

class AvailabilityEventsWindow(QMainWindow):
    window_closed = Signal()

    def __init__(self, db_manager):
        super(AvailabilityEventsWindow, self).__init__()
        self.db_manager = db_manager

        # Load UI
        loader = QUiLoader()
        ui_file = QFile("availability_events_window.ui")
        if not ui_file.exists():
            raise FileNotFoundError("The UI file 'availability_events_window.ui' was not found.")
        ui_file.open(QFile.ReadOnly)
        self.ui = loader.load(ui_file, self)
        ui_file.close()

        self.setCentralWidget(self.ui)
        self.setWindowTitle("Manage Availability Events")

        # Connect signals
        self.ui.addButton.clicked.connect(self.add_event)
        self.ui.updateButton.clicked.connect(self.update_event)
        self.ui.deleteButton.clicked.connect(self.delete_event)
        self.ui.eventsTable.itemSelectionChanged.connect(self.load_selected_event)

        # Initialize
        self.load_events()

    def load_events(self):
        try:
            with self.db_manager.connection.cursor() as cursor:
                cursor.execute("SELECT * FROM availability_events ORDER BY start_date DESC")
                events = cursor.fetchall()

                self.ui.eventsTable.setRowCount(len(events))
                for row, event in enumerate(events):
                    self.ui.eventsTable.setItem(row, 0, QTableWidgetItem(str(event[0])))  # availability_event_id
                    self.ui.eventsTable.setItem(row, 1, QTableWidgetItem(str(event[1])))  # availability_identifier
                    self.ui.eventsTable.setItem(row, 2, QTableWidgetItem(str(event[2])))  # availability_name
                    self.ui.eventsTable.setItem(row, 3, QTableWidgetItem(str(event[3])))  # start_date
                    self.ui.eventsTable.setItem(row, 4, QTableWidgetItem(str(event[4])))  # end_date
        except Exception as e:
            logging.error(f"Error loading availability events: {e}")
            QMessageBox.critical(self, "Error", f"Failed to load availability events: {str(e)}")

    def add_event(self):
        try:
            identifier = self.ui.identifierEdit.text()
            name = self.ui.nameEdit.text()
            start_date = self.ui.startDateEdit.date().toString(Qt.ISODate)
            end_date = self.ui.endDateEdit.date().toString(Qt.ISODate)
            description = self.ui.descriptionEdit.toPlainText()

            with self.db_manager.connection.cursor() as cursor:
                cursor.execute(
                    "INSERT INTO availability_events (availability_identifier, availability_name, start_date, end_date, description, created_by) "
                    "VALUES (%s, %s, %s, %s, %s, %s) RETURNING availability_event_id",
                    (identifier, name, start_date, end_date, description, self.db_manager.user_id)
                )
                new_id = cursor.fetchone()[0]
                self.db_manager.connection.commit()

            QMessageBox.information(self, "Success", f"New availability event added with ID: {new_id}")
            self.load_events()
            self.clear_form()
        except Exception as e:
            logging.error(f"Error adding availability event: {e}")
            QMessageBox.critical(self, "Error", f"Failed to add availability event: {str(e)}")

    def update_event(self):
        try:
            selected_items = self.ui.eventsTable.selectedItems()
            if not selected_items:
                QMessageBox.warning(self, "Warning", "Please select an event to update.")
                return

            event_id = int(self.ui.eventsTable.item(selected_items[0].row(), 0).text())
            identifier = self.ui.identifierEdit.text()
            name = self.ui.nameEdit.text()
            start_date = self.ui.startDateEdit.date().toString(Qt.ISODate)
            end_date = self.ui.endDateEdit.date().toString(Qt.ISODate)
            description = self.ui.descriptionEdit.toPlainText()

            with self.db_manager.connection.cursor() as cursor:
                cursor.execute(
                    "UPDATE availability_events SET availability_identifier = %s, availability_name = %s, "
                    "start_date = %s, end_date = %s, description = %s WHERE availability_event_id = %s",
                    (identifier, name, start_date, end_date, description, event_id)
                )
                self.db_manager.connection.commit()

            QMessageBox.information(self, "Success", f"Availability event with ID {event_id} updated successfully.")
            self.load_events()
            self.clear_form()
        except Exception as e:
            logging.error(f"Error updating availability event: {e}")
            QMessageBox.critical(self, "Error", f"Failed to update availability event: {str(e)}")

    def delete_event(self):
        try:
            selected_items = self.ui.eventsTable.selectedItems()
            if not selected_items:
                QMessageBox.warning(self, "Warning", "Please select an event to delete.")
                return

            event_id = int(self.ui.eventsTable.item(selected_items[0].row(), 0).text())

            confirm = QMessageBox.question(self, "Confirm Deletion", 
                                           f"Are you sure you want to delete the event with ID {event_id}?",
                                           QMessageBox.Yes | QMessageBox.No)
            if confirm == QMessageBox.Yes:
                with self.db_manager.connection.cursor() as cursor:
                    cursor.execute("DELETE FROM availability_events WHERE availability_event_id = %s", (event_id,))
                    self.db_manager.connection.commit()

                QMessageBox.information(self, "Success", f"Availability event with ID {event_id} deleted successfully.")
                self.load_events()
                self.clear_form()
        except Exception as e:
            logging.error(f"Error deleting availability event: {e}")
            QMessageBox.critical(self, "Error", f"Failed to delete availability event: {str(e)}")

    def load_selected_event(self):
        selected_items = self.ui.eventsTable.selectedItems()
        if selected_items:
            row = selected_items[0].row()
            self.ui.identifierEdit.setText(self.ui.eventsTable.item(row, 1).text())
            self.ui.nameEdit.setText(self.ui.eventsTable.item(row, 2).text())
            self.ui.startDateEdit.setDate(QDate.fromString(self.ui.eventsTable.item(row, 3).text(), Qt.ISODate))
            self.ui.endDateEdit.setDate(QDate.fromString(self.ui.eventsTable.item(row, 4).text(), Qt.ISODate))
            
            # Fetch the description from the database
            event_id = int(self.ui.eventsTable.item(row, 0).text())
            with self.db_manager.connection.cursor() as cursor:
                cursor.execute("SELECT description FROM availability_events WHERE availability_event_id = %s", (event_id,))
                description = cursor.fetchone()[0]
                self.ui.descriptionEdit.setPlainText(description if description else "")

    def clear_form(self):
        self.ui.identifierEdit.clear()
        self.ui.nameEdit.clear()
        self.ui.startDateEdit.setDate(QDate.currentDate())
        self.ui.endDateEdit.setDate(QDate.currentDate())
        self.ui.descriptionEdit.clear()

    def closeEvent(self, event):
        self.window_closed.emit()
        super(AvailabilityEventsWindow, self).closeEvent(event)