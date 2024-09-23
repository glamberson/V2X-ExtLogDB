import psycopg2
from psycopg2.extras import DictCursor, RealDictCursor
import json
import logging
import pandas as pd
import datetime
import math
import numpy as np
from utils import DateTimeEncoder
from config import FIELD_MAX_LENGTHS

class DatabaseManager:
    def __init__(self, db_config):
        self.connection = None
        self.session_id = None
        self.user_id = None
        self.role_id = None
        self.db_role_name = None
        self.db_config = db_config

    def connect(self):
        try:
            self.connection = psycopg2.connect(
                **self.db_config,
                connect_timeout=15
            )
            logging.info("Database connection established.")
            return True
        except psycopg2.Error as error:
            logging.error(f"Error connecting to PostgreSQL database: {error}")
            self.connection = None
            return False

    def login(self, username, password):
        if not self.connection:
            return False

        try:
            with self.connection.cursor(cursor_factory=DictCursor) as cursor:
                cursor.execute(
                    "SELECT * FROM login_wrapper(%s, %s, %s)",
                    (username, password, "1 hour")
                )
                result = cursor.fetchone()

                if result and result['session_id']:
                    self.session_id = result['session_id']
                    self.user_id = result['login_user_id']
                    self.role_id = result['login_role_id']
                    self.db_role_name = result['login_db_role_name']

                    cursor.execute(
                        "SELECT set_user_role(%s)",
                        (self.db_role_name,)
                    )
                    self.connection.commit()

                    logging.info(f"User {username} logged in successfully.")
                    self.set_session_variables(self.user_id, self.role_id)
                    return True
                else:
                    self.connection.rollback()
                    logging.warning(f"Login failed for user {username}.")
                    return False

        except psycopg2.Error as error:
            self.connection.rollback()
            logging.error(f"Error during login for user {username}: {error}")
            return False

    def set_session_variables(self, user_id, role_id):
        if not self.connection:
            raise Exception("Database connection not established.")

        try:
            with self.connection.cursor() as cursor:
                cursor.execute("SET myapp.user_id = %s;", (user_id,))
                cursor.execute("SET myapp.role_id = %s;", (role_id,))
                self.connection.commit()
                logging.debug(f"Session variables set: user_id={user_id}, role_id={role_id}")
        except psycopg2.Error as e:
            self.connection.rollback()
            logging.error(f"Error setting session variables: {e}")
            raise

    def execute_protected_function(self, function_name, *args, parameter_types=None):
        if not self.connection:
            raise Exception("Database connection not established.")

        try:
            with self.connection.cursor(cursor_factory=RealDictCursor) as cursor:
                cursor.execute(
                    "SELECT is_valid FROM validate_session_and_permission(%s, %s);",
                    (self.session_id, function_name)
                )
                validation_result = cursor.fetchone()

                if not validation_result or not validation_result['is_valid']:
                    raise PermissionError(f"Invalid session or insufficient permissions for {function_name}")

                if parameter_types and len(parameter_types) == len(args):
                    placeholders = ', '.join([f'%s::{ptype}' for ptype in parameter_types])
                else:
                    placeholders = ', '.join(['%s'] * len(args))

                sql = f"CALL {function_name}({placeholders}, %s);"
                args = args + (None,)

                cursor.execute(sql, args)
                result = cursor.fetchone()

                self.connection.commit()

                if result and 'summary' in result and result['summary']:
                    if isinstance(result['summary'], str):
                        summary = json.loads(result['summary'])
                    elif isinstance(result['summary'], dict):
                        summary = result['summary']
                    else:
                        raise Exception("Unexpected type for summary")
                    return summary
                else:
                    raise Exception(f"No OUT parameter 'summary' returned from {function_name}.")

        except PermissionError as pe:
            self.connection.rollback()
            logging.error(f"Permission error: {pe}")
            raise
        except psycopg2.Error as e:
            self.connection.rollback()
            logging.error(f"Database error in {function_name}: {e}")
            raise
        except json.JSONDecodeError as je:
            self.connection.rollback()
            logging.error(f"JSON decode error in {function_name}: {je}")
            raise
        except Exception as e:
            self.connection.rollback()
            logging.error(f"Unexpected error in {function_name}: {e}")
            raise

    def renew_session(self):
        if not self.session_id:
            logging.warning("No session ID available to renew.")
            return False

        try:
            with self.connection.cursor() as cursor:
                cursor.execute("SELECT renew_session(%s, %s)", (self.session_id, '1 hour'))
                result = cursor.fetchone()[0]
                self.connection.commit()
                if not result:
                    raise Exception("Failed to renew session")
                logging.info("Session renewed successfully.")
                return True
        except psycopg2.Error as e:
            self.connection.rollback()
            logging.error(f"Error renewing session: {e}")
            return False

    def insert_mrl_line_items_efficient(self, batch_data, update_source):
        if not isinstance(batch_data, list):
            raise ValueError("batch_data must be a list of dictionaries")

        json_data = json.dumps(batch_data, cls=DateTimeEncoder)
        logging.debug(f"Prepared JSON data for insert_mrl_line_items_efficient: {json_data[:500]}...")

        try:
            summary = self.execute_protected_function(
                'insert_mrl_line_items_efficient',
                json_data,
                update_source,
                parameter_types=['jsonb', 'text']
            )
            logging.debug(f"Stored procedure insert_mrl_line_items_efficient called successfully.")

            if summary:
                logging.info(f"Insert summary: {json.dumps(summary, indent=2)}")
                return summary
            else:
                raise Exception("No summary returned from insert_mrl_line_items_efficient")
        except Exception as e:
            logging.error(f"Error in insert_mrl_line_items_efficient: {e}")
            raise

    def update_fulfillment_records_efficient(self, batch_data, update_source):
        if not isinstance(batch_data, list):
            raise ValueError("batch_data must be a list of dictionaries")

        json_data = json.dumps(batch_data, cls=DateTimeEncoder)
        logging.debug(f"Prepared JSON data for update_fulfillment_records_efficient: {json_data[:500]}...")

        try:
            summary = self.execute_protected_function(
                'update_fulfillment_items_efficient',
                json_data,
                update_source,
                parameter_types=['jsonb', 'text']
            )
            logging.debug("Stored procedure update_fulfillment_items_efficient called successfully.")

            if summary:
                logging.info(f"Update summary: {json.dumps(summary, indent=2)}")
                return summary
            else:
                raise Exception("No summary returned from update_fulfillment_items_efficient")
        except Exception as e:
            logging.error(f"Error in update_fulfillment_records_efficient: {e}")
            raise