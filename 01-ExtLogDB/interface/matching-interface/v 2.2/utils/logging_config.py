# utils/logging_config.py

import logging
import os
from logging.handlers import RotatingFileHandler

def get_logger(name=None):
    """
    Returns a logger with the specified name, configured with the project's logging settings.
    """
    logger = logging.getLogger(name)
    if not logger.handlers:
        logger.setLevel(logging.DEBUG)
        
        # Create console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.DEBUG)  # Adjust the level if needed
        console_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        console_handler.setFormatter(console_formatter)
        logger.addHandler(console_handler)
        
        # Ensure the log directory exists
        log_directory = 'logs'
        if not os.path.exists(log_directory):
            os.makedirs(log_directory, exist_ok=True)
        
        # Create file handler with rotation
        log_file = os.path.join(log_directory, 'application.log')
        file_handler = RotatingFileHandler(log_file, maxBytes=5 * 1024 * 1024, backupCount=5)
        file_handler.setLevel(logging.DEBUG)  # Adjust the level if needed
        file_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        file_handler.setFormatter(file_formatter)
        logger.addHandler(file_handler)
        
    return logger
