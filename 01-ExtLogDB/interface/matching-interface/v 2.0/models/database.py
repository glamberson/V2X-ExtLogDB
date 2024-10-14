# models/database.py

import psycopg2
import psycopg2.extras  # Needed for DictCursor
import logging

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
                password="password",
                host="localhost",
                port="5432"
            )
            logger.info("Database connection successful")
        except (Exception, psycopg2.Error) as error:
            logger.error(f"Error while connecting to PostgreSQL: {error}")
            self.conn = None

    def execute_query(self, query, params=None, fetchall=True):
        if not self.conn:
            logger.error("No database connection")
            return []
        try:
            with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(query, params)
                if cur.description:
                    if fetchall:
                        results = cur.fetchall()
                    else:
                        results = cur.fetchone()
                    return results
                else:
                    self.conn.commit()
                    return []
        except (Exception, psycopg2.Error) as error:
            logger.error(f"Error executing query: {error}")
            logger.debug(f"Query: {query}")
            logger.debug(f"Params: {params}")
            self.conn.rollback()
            return []

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
        column_names = [row['column_name'] for row in results]
        logger.debug(f"Column names: {column_names}")
        return column_names

    def apply_filters(self, filters, report_name, sheet_name):
        base_query = """
        SELECT *
        FROM staged_egypt_weekly_data
        WHERE report_name = %s AND sheet_name = %s
        """
        conditions = []
        params = [report_name, sheet_name]
        for field, operation, value in filters:
            if operation in ['contains', 'starts with', 'ends with', 'equals']:
                if not value:
                    continue  # Skip if value is empty
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
                conditions.append(f"LOWER(CAST({field} AS TEXT)) = LOWER(%s)")
                params.append(value)
            elif operation == 'is null':
                conditions.append(f"{field} IS NULL")
            elif operation == 'is not null':
                conditions.append(f"{field} IS NOT NULL")
        
        # Add mrl_matched filter
        mrl_matched = next((f[2] for f in filters if f[0] == 'mrl_matched'), None)
        if mrl_matched == 'Yes':
            conditions.append("mrl_matched = TRUE")
        elif mrl_matched == 'No':
            conditions.append("mrl_matched = FALSE")
        
        # Add fulfillment_matched filter
        fulfillment_matched = next((f[2] for f in filters if f[0] == 'fulfillment_matched'), None)
        if fulfillment_matched == 'Yes':
            conditions.append("fulfillment_matched = TRUE")
        elif fulfillment_matched == 'No':
            conditions.append("fulfillment_matched = FALSE")

        if conditions:
            base_query += " AND " + " AND ".join(conditions)

        results = self.execute_query(base_query, tuple(params))
        logger.debug(f"Applied filters, fetched {len(results)} rows")
        return results

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
