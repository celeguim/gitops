schema:
# 	python3 tools/schema_compiler.py
	python3 -c 'print("precisa ajustar")'

lint: schema
	helm lint charts/microservice

template: schema
	helm template charts/microservice

validate: schema lint template
