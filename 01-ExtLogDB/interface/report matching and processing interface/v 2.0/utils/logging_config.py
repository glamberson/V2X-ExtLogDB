# utils/logging_config.py
import logging
import logging.config

def setup_logging():
    logging.config.dictConfig({
        'version': 1,
        'disable_existing_loggers': False,
        'formatters': {
            'standard': {
                'format': '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
            },
        },
        'handlers': {
            'console': {
                'class': 'logging.StreamHandler',
                'formatter': 'standard',
                'level': 'DEBUG',
            },
        },
        'root': {
            'handlers': ['console'],
            'level': 'INFO',
        },
        'loggers': {
            '__main__': {
                'handlers': ['console'],
                'level': 'DEBUG',
                'propagate': False
            },
            'models': {
                'handlers': ['console'],
                'level': 'DEBUG',
                'propagate': False
            },
            'controllers': {
                'handlers': ['console'],
                'level': 'DEBUG',
                'propagate': False
            },
            'ui': {
                'handlers': ['console'],
                'level': 'DEBUG',
                'propagate': False
            },
        }
    })
