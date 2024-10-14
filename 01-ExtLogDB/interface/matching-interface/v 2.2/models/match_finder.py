# models/match_finder.py

from models.data_models import StagedRecord, MRLRecord, Match
from models.database import DatabaseConnection
from Levenshtein import ratio
from utils.logging_config import get_logger
import re

logger = get_logger(__name__)

class MatchFinder:
    def __init__(self, db_connection: DatabaseConnection):
        self.db = db_connection

    def find_potential_matches(self, search_records):
        potential_matches = []
        for search_record in search_records:
            logger.debug(f"Searching for matches for record: {search_record.twcode}, JCN: {search_record.jcn}")

            # Query to find potential matches and retrieve the fulfillment_item_id when there's exactly one
            query = """
            SELECT mrl.*, fi.fulfillment_item_id,
                   COUNT(fi.fulfillment_item_id) OVER (PARTITION BY mrl.order_line_item_id) AS fulfillment_count
            FROM mrl_line_items mrl
            LEFT JOIN fulfillment_items fi ON fi.order_line_item_id = mrl.order_line_item_id
            WHERE mrl.twcode = %s AND mrl.jcn = %s
            AND NOT EXISTS (
                SELECT 1 FROM staged_egypt_weekly_data s
                WHERE s.jcn = mrl.jcn
                AND s.twcode = mrl.twcode
                AND (s.mrl_matched = TRUE OR s.fulfillment_matched = TRUE)
            )
            """
            params = (search_record.twcode, search_record.jcn)
            results = self.db.execute_query(query, params)

            if results:
                for result in results:
                    fulfillment_count = result['fulfillment_count']
                    multiple_fulfillments = fulfillment_count > 1
                    mrl_record = self._dict_to_mrl_record(result)
                    mrl_record.multiple_fulfillments = multiple_fulfillments
                    # Include fulfillment_item_id if there is exactly one fulfillment record
                    if not multiple_fulfillments:
                        mrl_record.fulfillment_item_id = result['fulfillment_item_id']
                    else:
                        mrl_record.fulfillment_item_id = None
                    logger.debug(f"Retrieved MRL Record with Order Line Item ID: {mrl_record.order_line_item_id}, Fulfillment Item ID: {mrl_record.fulfillment_item_id}, Multiple Fulfillments: {multiple_fulfillments}")

                    score, field_scores = self.calculate_match_score(search_record, mrl_record)
                    potential_matches.append(Match(
                        search_record=search_record,
                        mrl_record=mrl_record,
                        score=score,
                        field_scores=field_scores
                    ))
            else:
                logger.debug(f"No potential matches found for TWCODE: {search_record.twcode} and JCN: {search_record.jcn}")
        return potential_matches

    def calculate_match_score(self, search_record: StagedRecord, mrl_record: MRLRecord):
        weights = {
            'twcode': 40,
            'jcn': 20,
            'nomenclature': 20,
            'niin': 10,
            'part_no': 10
        }

        field_scores = {}
        total_score = 0
        max_score = sum(weights.values())

        logger.debug(f"Calculating match score for Staged ID {search_record.staged_id}")

        for field, weight in weights.items():
            search_value = getattr(search_record, field, '') or ''
            mrl_value = getattr(mrl_record, field, '') or ''

            search_value = str(search_value).lower().strip()
            mrl_value = str(mrl_value).lower().strip()

            logger.debug(f"Comparing field '{field}': search='{search_value}', mrl='{mrl_value}'")

            if field == 'nomenclature':
                similarity = ratio(search_value, mrl_value)
                field_score = similarity * 100
                field_scores[field] = field_score
                total_score += similarity * weight
                logger.debug(f"Nomenclature similarity: {similarity}, field score: {field_score}")
            elif search_value and mrl_value and search_value == mrl_value:
                field_scores[field] = 100
                total_score += weight
                logger.debug(f"Exact match for field '{field}', added {weight} to total score")
            else:
                field_scores[field] = 0
                logger.debug(f"No match for field '{field}'")

        normalized_score = (total_score / max_score) * 100
        logger.debug(f"Total score: {total_score}, Normalized score: {normalized_score}")

        return round(normalized_score, 2), field_scores

    def _dict_to_mrl_record(self, record_dict):
        import re  # Ensure you have imported the 're' module at the top

        # Lowercase keys to match dataclass field names
        record_dict = {k.lower(): v for k, v in record_dict.items()}

        # Get the set of field names defined in the MRLRecord dataclass
        mrl_record_fields = set(MRLRecord.__dataclass_fields__.keys())

        # Include only the fields that are defined in MRLRecord
        record_data = {k: v for k, v in record_dict.items() if k in mrl_record_fields}

        # Convert MONEY fields to float
        money_fields = ['market_research_up', 'market_research_ep']
        for field in money_fields:
            if field in record_data and record_data[field] is not None:
                # Remove dollar signs and commas, then convert to float
                record_data[field] = float(re.sub(r'[$,]', '', str(record_data[field])))

        return MRLRecord(**record_data)