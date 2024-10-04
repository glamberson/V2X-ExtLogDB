# controllers/main_controller.py

from models.database import DatabaseConnection
from models.match_finder import MatchFinder
from models.data_models import StagedRecord
import logging

logger = logging.getLogger(__name__)

class MainController:
    def __init__(self):
        self.db = DatabaseConnection()
        self.match_finder = MatchFinder(self.db)

    def get_report_names(self):
        return self.db.get_report_names()

    def get_sheet_names(self, report_name):
        return self.db.get_sheet_names(report_name)

    def load_report_data(self, report_name, sheet_name):
        data = self.db.get_report_data(report_name, sheet_name)
        return data

    def find_matches(self, selected_records):
        # Convert selected_records to StagedRecord instances
        staged_records = [self._dict_to_staged_record(record) for record in selected_records]
        potential_matches = self.match_finder.find_potential_matches(staged_records)
        return potential_matches

    def apply_filters(self, filters, report_name, sheet_name):
        # Implement logic to apply custom filters
        filtered_data = self.db.apply_filters(filters, report_name, sheet_name)
        return filtered_data

    def apply_preset_filter(self, preset_name):
        # Implement logic to apply preset filters
        filtered_data = self.db.apply_preset_filter(preset_name)
        return filtered_data

    def validate_sql(self, sql_query):
        # Implement logic to validate the SQL query
        is_valid, message = self.db.validate_sql(sql_query)
        return is_valid, message

    def execute_sql(self, sql_query):
        # Implement logic to execute the SQL query
        result = self.db.execute_sql(sql_query)
        return result

    def _dict_to_staged_record(self, record_dict):
        return StagedRecord(
            staged_id=int(record_dict.get('staged_id', 0)),
            twcode=record_dict.get('twcode', ''),
            jcn=record_dict.get('jcn', ''),
            nomenclature=record_dict.get('nomenclature', ''),
            niin=record_dict.get('niin', ''),
            part_no=record_dict.get('part_no', ''),
            # Add other fields as needed
        )
