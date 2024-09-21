import psycopg2
from psycopg2.extras import DictCursor
import json
from config import DB_CONFIG
import logging
import pandas as pd  # Make sure pandas is imported
import datetime
import math
import numpy as np  # Ensure numpy is imported for type handling
from utils import DateTimeEncoder

class DatabaseManager:
    def __init__(self):
        self.connection = None
        self.session_id = None
        self.user_id = None
        self.role_id = None
        self.db_role_name = None

    def connect(self):
        try:
            self.connection = psycopg2.connect(**DB_CONFIG)
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

                    # Set the user role
                    cursor.execute(
                        "SELECT set_user_role(%s)",
                        (self.db_role_name,)
                    )
                    self.connection.commit()

                    logging.info(f"User {username} logged in successfully.")

                    # Set session variables in PostgreSQL
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
            with self.connection.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Validate session and permission
                cursor.execute(
                    "SELECT is_valid FROM validate_session_and_permission(%s, %s);",
                    (self.session_id, function_name)
                )
                validation_result = cursor.fetchone()

                if not validation_result or not validation_result['is_valid']:
                    raise PermissionError(f"Invalid session or insufficient permissions for {function_name}")

                # Prepare the SQL command with explicit type casts
                if parameter_types and len(parameter_types) == len(args):
                    placeholders = ', '.join([f'%s::{ptype}' for ptype in parameter_types])
                else:
                    placeholders = ', '.join(['%s'] * len(args))

                # Prepare the CALL statement
                sql = f"CALL {function_name}({placeholders}, %s);"  # Add a placeholder for the OUT parameter

                # Append None for the OUT parameter
                args = args + (None,)

                # Execute the CALL statement
                cursor.execute(sql, args)

                # Fetch the OUT parameters
                result = cursor.fetchone()

                self.connection.commit()

                if result and 'summary' in result and result['summary']:
                    # Check if 'summary' is a string or dict
                    if isinstance(result['summary'], str):
                        # Parse the JSON summary string into a Python dictionary
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
        logging.debug(f"Prepared JSON data for insert_mrl_line_items_efficient: {json_data[:500]}...")  # Log first 500 chars

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
        logging.debug(f"Prepared JSON data for update_fulfillment_records_efficient: {json_data[:500]}...")  # Log first 500 chars

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