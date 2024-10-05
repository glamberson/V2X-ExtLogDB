# controllers/match_controller.py

from models.database import DatabaseConnection
import logging

logger = logging.getLogger(__name__)

class MatchController:
    def __init__(self, db_connection: DatabaseConnection):
        """
        Initializes the MatchController with a database connection.

        :param db_connection: An instance of DatabaseConnection.
        """
        self.db = db_connection

def bulk_accept_staged_mrl_only_match(self, staged_ids, order_line_item_ids, match_scores, match_grades, matched_fields, mismatched_fields, report_name, report_date, sheet_name, user_id, role_id):
    try:
        query = """
        CALL bulk_accept_staged_mrl_only_match(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        params = (staged_ids, order_line_item_ids, match_scores, match_grades, matched_fields, mismatched_fields, report_name, report_date, sheet_name, user_id, role_id)
        self.db.execute_query(query, params)
        logger.info(f"Successfully executed bulk_accept_staged_mrl_only_match for staged_ids: {staged_ids}")
    except Exception as e:
        logger.exception(f"Error executing bulk_accept_staged_mrl_only_match: {str(e)}")
        raise

def bulk_accept_staged_mrl_fulfillment_match(self, staged_ids, order_line_item_ids, fulfillment_item_ids, match_scores, match_grades, matched_fields, mismatched_fields, report_name, report_date, sheet_name, user_id, role_id):
    try:
        query = """
        CALL bulk_accept_staged_mrl_fulfillment_match(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        params = (staged_ids, order_line_item_ids, fulfillment_item_ids, match_scores, match_grades, matched_fields, mismatched_fields, report_name, report_date, sheet_name, user_id, role_id)
        self.db.execute_query(query, params)
        logger.info(f"Successfully executed bulk_accept_staged_mrl_fulfillment_match for staged_ids: {staged_ids}")
    except Exception as e:
        logger.exception(f"Error executing bulk_accept_staged_mrl_fulfillment_match: {str(e)}")
        raise
