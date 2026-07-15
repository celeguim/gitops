#!/usr/bin/env bash
set -euo pipefail
EXPECTED_ENV="${1:?usage: $0 uat|prd}"
NS="${ARGOCD_NAMESPACE:-argocd}"
bad=0
while IFS=$'\t' read -r secret name env cluster_id; do
  [[ -z "$secret" ]] && continue
  if [[ "$env" != "$EXPECTED_ENV" ]]; then
    echo "ERROR secret=$secret cluster=$name environment=$env expected=$EXPECTED_ENV"
    bad=1
  else
    echo "OK secret=$secret cluster=$name environment=$env cluster-id=$cluster_id"
  fi
done < <(
  kubectl -n "$NS" get secret \
    -l argocd.argoproj.io/secret-type=cluster \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.data.name}{"\t"}{.metadata.labels.environment}{"\t"}{.metadata.labels.cluster-id}{"\n"}{end}'
)
exit "$bad"
