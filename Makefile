schema:
	python3 tools/build_schema.py

lint:
	helm lint .

template:
	helm template demo .

validate: schema lint template
