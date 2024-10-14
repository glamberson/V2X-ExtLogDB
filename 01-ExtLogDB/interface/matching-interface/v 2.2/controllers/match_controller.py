# controllers/match_controller.py

from models.database import DatabaseConnection
from utils.logging_config import get_logger

logger = get_logger(__name__)

def bulk_process_matches(matches, threshold):
    logger.info("Starting bulk processing of matches")
    processed_matches = []
    for match in matches:
        logger.debug(f"Processing match: {match}")
        score = calculate_match_score(match)
        logger.debug(f"Calculated score for match: {score}")
        if score >= threshold:
            logger.info(f"Match accepted: {match} with score {score}")
            processed_matches.append(match)
        else:
            logger.info(f"Match rejected: {match} with score {score}")
    
    if not processed_matches:
        logger.warning("No matches met the required threshold. Please review matching logic or configuration.")
    else:
        logger.info(f"Number of matches processed successfully: {len(processed_matches)}")

    logger.info("Bulk processing completed")
    return processed_matches

def calculate_match_score(match):
    try:
        twcode_score = match['TWCODE'] * 0.4
        jcn_score = match['JCN'] * 0.2
        nomenclature_score = match['Nomenclature'] * 0.2
        niin_score = match['NIIN'] * 0.1
        part_number_score = match['PartNumber'] * 0.1
    except KeyError as e:
        logger.error(f"KeyError encountered: Missing key {e} in match: {match}")
        raise

    logger.debug(f"TWCODE score: {twcode_score}")
    logger.debug(f"JCN score: {jcn_score}")
    logger.debug(f"Nomenclature score: {nomenclature_score}")
    logger.debug(f"NIIN score: {niin_score}")
    logger.debug(f"Part Number score: {part_number_score}")

    total_score = twcode_score + jcn_score + nomenclature_score + niin_score + part_number_score
    logger.debug(f"Total aggregated score: {total_score}")
    return total_score

class MatchController:
    def __init__(self, db_connection: DatabaseConnection):
        self.db = db_connection

    def bulk_accept_staged_mrl_only_match(self, staged_ids, order_line_item_ids, match_scores, match_grades, matched_fields, mismatched_fields, report_name, report_date, sheet_name, user_id, role_id):
        query = """
        CALL bulk_accept_staged_mrl_only_match(%s::INT[], %s::INT[], %s::DECIMAL[], %s::TEXT[], %s::TEXT[], %s::TEXT[], %s, %s, %s, %s, %s)
        """
        params = (
            staged_ids,
            order_line_item_ids,
            match_scores,
            match_grades,
            matched_fields,
            mismatched_fields,
            report_name,
            report_date,
            sheet_name,
            user_id,
            role_id
        )
        self.db.execute_query(query, params)

    def bulk_accept_staged_mrl_fulfillment_match(self, staged_ids, order_line_item_ids, fulfillment_item_ids, match_scores, match_grades, matched_fields, mismatched_fields, report_name, report_date, sheet_name, user_id, role_id):
        query = """
        CALL bulk_accept_staged_mrl_fulfillment_match(%s::INT[], %s::INT[], %s::INT[], %s::DECIMAL[], %s::TEXT[], %s::TEXT[], %s::TEXT[], %s, %s, %s, %s, %s)
        """
        params = (
            staged_ids,
            order_line_item_ids,
            fulfillment_item_ids,
            match_scores,
            match_grades,
            matched_fields,  # Now list of strings representing array literals
            mismatched_fields,  # Now list of strings representing array literals
            report_name,
            report_date,
            sheet_name,
            user_id,
            role_id
        )
        self.db.execute_query(query, params)

    def mark_as_processed(self, staged_id):
        query = """
        UPDATE staged_egypt_weekly_data
        SET processing_complete = TRUE
        WHERE staged_id = %s
        """
        self.db.execute_query(query, (staged_id,))

    def delete_invalid_record(self, staged_id):
        query = """
        DELETE FROM staged_egypt_weekly_data
        WHERE staged_id = %s
        """
        self.db.execute_query(query, (staged_id,))