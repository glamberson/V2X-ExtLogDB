# models/match_finder.py

from models.data_models import StagedRecord, MRLRecord, Match
from models.database import DatabaseConnection
from Levenshtein import ratio
import logging

logger = logging.getLogger(__name__)

class MatchFinder:
    def __init__(self, db_connection: DatabaseConnection):
        self.db = db_connection

    def find_potential_matches(self, search_records):
        potential_matches = []
        for search_record in search_records:
            logger.debug(f"Searching for matches for record: {search_record.twcode}")

            # First, try to match by twcode
            query = """
            SELECT * FROM mrl_line_items
            WHERE twcode = %s
            AND NOT EXISTS (
                SELECT 1 FROM staged_egypt_weekly_data
                WHERE jcn = mrl_line_items.jcn
                AND twcode = mrl_line_items.twcode
                AND (mrl_matched = TRUE OR fulfillment_matched = TRUE)
            )
            """
            params = (search_record.twcode,)
            results = self.db.execute_query(query, params)

            if not results:
                logger.debug(f"No exact TWCODE match found for {search_record.twcode}")
                # If no match by TWCODE, try other fields
                query = """
                SELECT * FROM mrl_line_items
                WHERE jcn = %s OR niin = %s OR part_no = %s
                """
                params = (search_record.jcn, search_record.niin, search_record.part_no)
                results = self.db.execute_query(query, params)

            logger.debug(f"Found {len(results)} potential matches for search record: {search_record.twcode}")

            for result in results:
                mrl_record = self._dict_to_mrl_record(result)
                score, field_scores = self.calculate_match_score(search_record, mrl_record)
                potential_matches.append(Match(
                    search_record=search_record,
                    mrl_record=mrl_record,
                    score=score,
                    field_scores=field_scores
                ))

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

        for field, weight in weights.items():
            search_value = getattr(search_record, field, '').lower().strip()
            mrl_value = getattr(mrl_record, field, '').lower().strip()

            logger.debug(f"Comparing {field}: search='{search_value}', mrl='{mrl_value}'")

            if field == 'nomenclature':
                similarity = ratio(search_value, mrl_value)
                field_scores[field] = similarity * 100
                total_score += similarity * weight
            elif search_value and mrl_value and search_value == mrl_value:
                field_scores[field] = 100
                total_score += weight
            else:
                field_scores[field] = 0

        normalized_score = (total_score / max_score) * 100
        return round(normalized_score, 2), field_scores

    def _dict_to_mrl_record(self, record_dict):
        return MRLRecord(
            mrl_id=record_dict.get('mrl_id', 0),
            twcode=record_dict.get('twcode', ''),
            jcn=record_dict.get('jcn', ''),
            nomenclature=record_dict.get('nomenclature', ''),
            niin=record_dict.get('niin', ''),
            part_no=record_dict.get('part_no', ''),
            # Add other fields as needed
        )
