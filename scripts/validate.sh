#!/usr/bin/env bash
set -euo pipefail
command -v helm >/dev/null
command -v kustomize >/dev/null
command -v yamllint >/dev/null
command -v kubeconform >/dev/null

helm lint charts/microservice

find . -type f \( -name '*.yaml' -o -name '*.yml' \) \
  ! -path './.git/*' -print0 | xargs -0 yamllint -c .yamllint

for app in app1 app2; do
  echo "Rendering $app"
  kustomize build --enable-helm "apps/$app/overlays/environment" \
    | kubeconform -strict -summary -ignore-missing-schemas
done

echo "Validating Argo CD YAML syntax"
python3 - <<'PY'
from pathlib import Path
import yaml
for p in Path("argocd").rglob("*.yaml"):
    list(yaml.safe_load_all(p.read_text()))
    print(f"OK YAML: {p}")
PY
