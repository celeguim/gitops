schema:
	python3 tools/schema_compiler.py

lint: schema
	helm lint .

template: schema
	helm template demo .

validate: schema lint template
