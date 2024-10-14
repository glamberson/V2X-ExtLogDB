# controllers/main_controller.py

from models.database import DatabaseConnection
from models.match_finder import MatchFinder
from models.data_models import StagedRecord
from utils.logging_config import get_logger
import re

logger = get_logger(__name__)

def parse_money_value(value):
    if value is not None and value != '':
        # Remove currency symbols, commas, and any non-numeric characters except period and minus sign
        cleaned_value = re.sub(r'[^\d.-]', '', value)
        try:
            return float(cleaned_value)
        except ValueError:
            logger.warning(f"Unable to convert '{value}' to float after cleaning. Setting to 0.0.")
            return 0.0
    else:
        return 0.0

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
        # Pass filters to the database
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
        # Convert field names to lowercase to match dataclass field names
        record_dict = {k.lower(): v for k, v in record_dict.items()}

        # Exclude metadata fields
        metadata_fields = {'created_by', 'created_at', 'updated_by', 'updated_at'}
        record_data = {k: v for k, v in record_dict.items() if k not in metadata_fields}

        # Handle MONEY fields using the helper function
        if 'market_research_up' in record_data:
            value = record_data['market_research_up']
            record_data['market_research_up'] = parse_money_value(value)

        if 'market_research_ep' in record_data:
            value = record_data['market_research_ep']
            record_data['market_research_ep'] = parse_money_value(value)

        # Handle other fields as needed

        return StagedRecord(**record_data)
