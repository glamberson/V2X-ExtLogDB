import psycopg2
from psycopg2 import sql
import logging
from Levenshtein import ratio

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

class DatabaseConnection:
    def __init__(self):
        self.conn = None
        self.connect()

    def connect(self):
        try:
            self.conn = psycopg2.connect(
                dbname="ExtLogDB",
                user="postgres",
                password="123456",
                host="cmms-db-01",
                port="5432"
            )
            logger.info("Database connection successful")
        except (Exception, psycopg2.Error) as error:
            logger.error(f"Error while connecting to PostgreSQL: {error}")

    def execute_query(self, query, params=None):
        if not self.conn:
            logger.error("No database connection")
            return []

        try:
            with self.conn.cursor() as cur:
                cur.execute(query, params)
                return cur.fetchall()
        except (Exception, psycopg2.Error) as error:
            logger.error(f"Error executing query: {error}")
            logger.error(f"Query: {query}")
            logger.error(f"Params: {params}")
            self.conn.rollback()  # Roll back the failed transaction
            return []

    def get_report_names(self):
        query = "SELECT DISTINCT report_name FROM staged_egypt_weekly_data ORDER BY report_name DESC"
        results = self.execute_query(query)
        report_names = [str(name[0]) for name in results]
        logger.debug(f"Fetched report names: {report_names}")
        return report_names

    def get_sheet_names(self, report_name):
        query = "SELECT DISTINCT sheet_name FROM staged_egypt_weekly_data WHERE report_name = %s ORDER BY sheet_name"
        results = self.execute_query(query, (report_name,))
        sheet_names = [sheet[0] for sheet in results]
        logger.debug(f"Fetched sheet names for report {report_name}: {sheet_names}")
        return sheet_names

    def get_report_data(self, report_name, sheet_name):
        query = """
        SELECT *
        FROM staged_egypt_weekly_data
        WHERE report_name = %s AND sheet_name = %s
        """
        results = self.execute_query(query, (report_name, sheet_name))
        logger.debug(f"Fetched {len(results)} rows for report {report_name}, sheet {sheet_name}")
        return results

    def get_column_names(self):
        query = """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'staged_egypt_weekly_data'
        ORDER BY ordinal_position
        """
        results = self.execute_query(query)
        return [col[0] for col in results]

    def apply_filters(self, filters, report_name, sheet_name):
        base_query = """
        SELECT *
        FROM staged_egypt_weekly_data
        WHERE report_name = %s AND sheet_name = %s
        """
        conditions = []
        params = [report_name, sheet_name]
        for field, operation, value in filters:
            if value:  # Only add condition if value is not empty
                if operation == 'contains':
                    conditions.append(f"LOWER({field}::text) LIKE LOWER(%s)")
                    params.append(f"%{value}%")
                elif operation == 'starts with':
                    conditions.append(f"LOWER({field}::text) LIKE LOWER(%s)")
                    params.append(f"{value}%")
                elif operation == 'ends with':
                    conditions.append(f"LOWER({field}::text) LIKE LOWER(%s)")
                    params.append(f"%{value}")
                elif operation == 'equals':
                    conditions.append(f"LOWER({field}::text) = LOWER(%s)")
                    params.append(value)
            elif operation == 'is null':
                conditions.append(f"{field} IS NULL")
            elif operation == 'is not null':
                conditions.append(f"{field} IS NOT NULL")

        # Add mrl_processed filter
        mrl_processed = next((f[2] for f in filters if f[0] == 'mrl_processed'), None)
        if mrl_processed == 'Yes':
            conditions.append("mrl_processed = TRUE")
        elif mrl_processed == 'No':
            conditions.append("mrl_processed = FALSE")

        # Add fulfillment_processed filter
        fulfillment_processed = next((f[2] for f in filters if f[0] == 'fulfillment_processed'), None)
        if fulfillment_processed == 'Yes':
            conditions.append("fulfillment_processed = TRUE")
        elif fulfillment_processed == 'No':
            conditions.append("fulfillment_processed = FALSE")

        if conditions:
            base_query += " AND " + " AND ".join(conditions)

        results = self.execute_query(base_query, tuple(params))
        logger.debug(f"Applied filters, fetched {len(results)} rows")
        return results

    def apply_preset_filter(self, preset_name):
        # This is a placeholder. You should implement your preset filters here.
        query = """
        SELECT *
        FROM staged_egypt_weekly_data
        WHERE 1=1
        """
        if preset_name == "Filter 1":
            query += " AND niin IS NOT NULL"
        elif preset_name == "Filter 2":
            query += " AND part_no IS NOT NULL"
        elif preset_name == "Filter 3":
            query += " AND LOWER(nomenclature) LIKE LOWER('%engine%')"

        results = self.execute_query(query)
        logger.debug(f"Applied preset filter '{preset_name}', fetched {len(results)} rows")
        return results

    def validate_sql(self, sql_query):
        try:
            with self.conn.cursor() as cur:
                cur.execute("EXPLAIN " + sql_query)
            return True, "SQL query is valid"
        except (Exception, psycopg2.Error) as error:
            return False, str(error)

    def execute_sql(self, sql_query):
        try:
            results = self.execute_query(sql_query)
            logger.debug(f"Executed custom SQL query, fetched {len(results)} rows")
            return results
        except (Exception, psycopg2.Error) as error:
            logger.error(f"Error executing custom SQL query: {error}")
            return []

    def bulk_accept_staged_mrl_only_match(self, staged_ids, report_name, report_date, sheet_name):
        query = """
        CALL bulk_accept_staged_mrl_only_match(%s, %s, %s, %s)
        """
        self.execute_query(query, (staged_ids, report_name, report_date, sheet_name))

    def bulk_accept_staged_mrl_fulfillment_match(self, staged_ids, report_name, report_date, sheet_name):
        query = """
        CALL bulk_accept_staged_mrl_fulfillment_match(%s, %s, %s, %s)
        """
        self.execute_query(query, (staged_ids, report_name, report_date, sheet_name))

    def bulk_accept_mrl(self, staged_ids):
        query = """
        CALL link_records(%s, %s, %s, %s)
        """
        self.execute_query(query, (staged_ids, self.current_user_id, self.current_role_id, 'Bulk Accept MRL'))

    def bulk_accept_both(self, staged_ids):
        query = """
        CALL link_and_update_records(%s, %s, %s, %s)
        """
        self.execute_query(query, (staged_ids, self.current_user_id, self.current_role_id, 'Bulk Accept MRL+Fulfillment'))

    def find_potential_matches(self, search_records):
        potential_matches = []
        for search_record in search_records:
            logger.debug(f"Searching for matches for record: {search_record['twcode']}")
            
            query = """
            SELECT * FROM MRL_line_items
            WHERE twcode = %s
            AND NOT EXISTS (
                SELECT 1 FROM staged_egypt_weekly_data
                WHERE jcn = MRL_line_items.jcn
                AND twcode = MRL_line_items.twcode
                AND (mrl_processed = TRUE OR fulfillment_processed = TRUE)
            )
            """
            params = (search_record.get('twcode'),)
            results = self.execute_query(query, params)
            
            if not results:
                logger.debug(f"No exact TWCODE match found for {search_record['twcode']}")
                # If no match by TWCODE, try other fields
                query = """
                SELECT * FROM MRL_line_items
                WHERE jcn = %s OR niin = %s OR part_no = %s
                """
                params = (search_record.get('jcn'), search_record.get('niin'), search_record.get('part_no'))
                results = self.execute_query(query, params)
            
            logger.debug(f"Found {len(results)} potential matches for search record: {search_record['twcode']}")
            
            for mrl_record in results:
                mrl_dict = dict(zip(self.get_mrl_column_names(), mrl_record))
                score, field_scores = self.calculate_match_score(search_record, mrl_dict)
                potential_matches.append({
                    'search_record': search_record,  # This includes the report_date
                    'mrl_record': mrl_dict,
                    'score': score,
                    'field_scores': field_scores
                })
        
        return potential_matches

    def calculate_match_score(self, search_record, mrl_record):
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
            search_value = str(search_record.get(field, '')).lower().strip()
            mrl_value = str(mrl_record.get(field, '')).lower().strip()
            
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
    
    def get_mrl_column_names(self):
        query = """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'mrl_line_items'
        ORDER BY ordinal_position
        """
        results = self.execute_query(query)
        column_names = [col[0] for col in results]
        logger.debug(f"MRL column names: {column_names}")  # Add this line to log the column names
        return column_names

    def __del__(self):
        if self.conn:
            self.conn.close()
            logger.info("Database connection closed")