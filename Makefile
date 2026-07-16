.PHONY: validate render-app1 render-app2
validate:
	./scripts/validate.sh

render-app1:
	kustomize build --enable-helm apps/app1/overlays/environment

render-app2:
	kustomize build --enable-helm apps/app2/overlays/environment

schema:
	python tools/build_schema.py

validate:
    helm lint

schema:
    python tools/build_schema.py

render:
    helm template

docs:
    python tools/build_docs.py

test:
    ./tests/run.sh

release:
    helm package
