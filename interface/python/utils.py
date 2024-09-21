import json
import pandas as pd
from datetime import datetime, date
import numpy as np

class DateTimeEncoder(json.JSONEncoder):
    def default(self, obj):
        if pd.isnull(obj):
            return None
        elif isinstance(obj, (datetime, date, pd.Timestamp)):
            return obj.isoformat()
        elif isinstance(obj, (np.integer, int)):
            return int(obj)
        elif isinstance(obj, (np.floating, float)):
            return float(obj)
        else:
            return super(DateTimeEncoder, self).default(obj)
