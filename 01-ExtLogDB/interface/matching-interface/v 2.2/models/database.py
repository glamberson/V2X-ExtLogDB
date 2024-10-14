# models/database.py

import psycopg2
import psycopg2.extras  # Needed for DictCursor
from psycopg2.extras import Json
from utils.logging_config import get_logger

logger = get_logger(__name__)

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
            self.conn = None

    def execute_query(self, query, params=None):
        try:
            logger.info(f"Executing query: {query} with params: {params}")
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute(query, params)
                if cursor.description:  # If it's a SELECT query
                    results = cursor.fetchall()
                    logger.debug(f"Number of records retrieved: {len(results)}")
                    return results
                else:
                    self.conn.commit()
                    logger.debug("Query executed successfully with no result set")
                    return None
        except Exception as e:
            logger.error(f"Error executing query: {e}")
            self.conn.rollback()
            raise
            
    def get_report_names(self):
        query = "SELECT DISTINCT report_name FROM staged_egypt_weekly_data ORDER BY report_name DESC"
        results = self.execute_query(query)
        report_names = [str(row['report_name']) for row in results]
        logger.debug(f"Fetched report names: {report_names}")
        return report_names

    def get_sheet_names(self, report_name):
        query = "SELECT DISTINCT sheet_name FROM staged_egypt_weekly_data WHERE report_name = %s ORDER BY sheet_name"
        results = self.execute_query(query, (report_name,))
        sheet_names = [row['sheet_name'] for row in results]
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
        if results:
            column_names = [row['column_name'] for row in results]
            logger.debug(f"Column names: {column_names}")
            return column_names
        else:
            logger.error("Failed to fetch column names from the database")
            return []

    def apply_filters(self, filters, report_name, sheet_name):
        base_query = """
        SELECT *
        FROM staged_egypt_weekly_data
        WHERE report_name = %s AND sheet_name = %s
        """
        conditions = []
        params = [report_name, sheet_name]
        
        # Define fields that are numeric and boolean
        numeric_fields = set()  # Add numeric fields here if any
        boolean_fields = {'mrl_matched', 'fulfillment_matched', 'processing_completed'}  # Add all boolean fields
        
        for field, operation, value in filters:
            # Skip filters with empty values, unless the value is 0 (to handle numeric fields)
            if operation in ['contains', 'starts with', 'ends with', 'equals', 'equals_or_null']:
                if value is None or (isinstance(value, str) and not value.strip()):
                    continue  # Skip if value is empty or whitespace

            # Handle the operations
            if operation == 'contains':
                conditions.append(f"LOWER(CAST({field} AS TEXT)) LIKE LOWER(%s)")
                params.append(f"%{value}%")
            elif operation == 'starts with':
                conditions.append(f"LOWER(CAST({field} AS TEXT)) LIKE LOWER(%s)")
                params.append(f"{value}%")
            elif operation == 'ends with':
                conditions.append(f"LOWER(CAST({field} AS TEXT)) LIKE LOWER(%s)")
                params.append(f"%{value}")
            elif operation == 'equals':
                if field in numeric_fields:
                    conditions.append(f"{field} = %s")
                    params.append(value)
                elif field in boolean_fields:
                    # Convert value to boolean
                    if isinstance(value, int):
                        value = bool(value)
                    elif isinstance(value, str):
                        value = value.strip().lower()
                        if value in ('true', 't', 'yes', '1'):
                            value = True
                        elif value in ('false', 'f', 'no', '0'):
                            value = False
                        else:
                            # Invalid boolean value; skip this filter or raise an error
                            logger.warning(f"Invalid boolean value for field '{field}': {value}")
                            continue
                    conditions.append(f"{field} = %s")
                    params.append(value)
                else:
                    conditions.append(f"LOWER(CAST({field} AS TEXT)) = LOWER(%s)")
                    params.append(value)
            elif operation == 'equals_or_null':
                if field in numeric_fields:
                    conditions.append(f"({field} = %s OR {field} IS NULL)")
                    params.append(value)
                elif field in boolean_fields:
                    # Convert value to boolean
                    if isinstance(value, int):
                        value = bool(value)
                    elif isinstance(value, str):
                        value = value.strip().lower()
                        if value in ('true', 't', 'yes', '1'):
                            value = True
                        elif value in ('false', 'f', 'no', '0'):
                            value = False
                        else:
                            logger.warning(f"Invalid boolean value for field '{field}': {value}")
                            continue
                    conditions.append(f"({field} = %s OR {field} IS NULL)")
                    params.append(value)
                else:
                    conditions.append(f"(LOWER(CAST({field} AS TEXT)) = LOWER(%s) OR {field} IS NULL)")
                    params.append(value)
            elif operation == 'is null':
                conditions.append(f"{field} IS NULL")
            elif operation == 'is not null':
                conditions.append(f"{field} IS NOT NULL")
            else:
                # Handle other operations or raise an error
                logger.warning(f"Unsupported operation '{operation}' for field '{field}'")
                continue

        # Assemble the full query
        if conditions:
            full_query = base_query + " AND " + " AND ".join(conditions)
        else:
            full_query = base_query

        logger.debug(f"Executing query: {full_query} with params: {params}")

        # Execute the query with the parameters using a cursor
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(full_query, params)
                records = cur.fetchall()
                return records
        except Exception as e:
            logger.error(f"Error applying filters: {str(e)}")
            raise

    def apply_preset_filter(self, preset_name):
        query = """
        SELECT *
        FROM staged_egypt_weekly_data
        WHERE 1=1
        """
        params = []
        if preset_name == "Filter 1":
            query += " AND niin IS NOT NULL"
        elif preset_name == "Filter 2":
            query += " AND part_no IS NOT NULL"
        elif preset_name == "Filter 3":
            query += " AND LOWER(nomenclature) LIKE LOWER(%s)"
            params.append('%engine%')

        results = self.execute_query(query, params)
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
        params = (staged_ids, report_name, report_date, sheet_name)
        self.execute_query(query, params)
        logger.info(f"Bulk accepted MRL only match for staged_ids: {staged_ids}")

    def bulk_accept_staged_mrl_fulfillment_match(self, staged_ids, report_name, report_date, sheet_name):
        query = """
        CALL bulk_accept_staged_mrl_fulfillment_match(%s, %s, %s, %s)
        """
        params = (staged_ids, report_name, report_date, sheet_name)
        self.execute_query(query, params)
        logger.info(f"Bulk accepted MRL and Fulfillment match for staged_ids: {staged_ids}")

    # Remove methods related to matching logic from DatabaseConnection
    # These methods should be in models/match_finder.py

    def __del__(self):
        if self.conn:
            self.conn.close()
            logger.info("Database connection closed")
