import os

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "cmms-db-01"),
    "port": os.environ.get("DB_PORT", "5432"),
    "database": os.environ.get("DB_NAME", "Beta_004"),
    "user": os.environ.get("DB_USER", "login"),
    "password": os.environ.get("DB_PASSWORD", "FOTS-Egypt")
}

# Application configuration
APP_NAME = "External Logistics Database"
COMPANY_NAME = "FOTS-Egypt"
