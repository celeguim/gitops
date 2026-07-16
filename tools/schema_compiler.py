import os

import yaml

root = yaml.safe_load(open(os.path.join(os.path.dirname(__file__), "schema.yaml")))
