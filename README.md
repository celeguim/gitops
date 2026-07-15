# GitOps v2 — Argo CD, EKS, Helm local e Kustomize

## Topologia

```text
argocd-uat
├── uat-cluster1  [environment=uat, cluster-id=cluster1]
└── uat-cluster2  [environment=uat, cluster-id=cluster2]

argocd-prd
├── prd-cluster1  [environment=prd, cluster-id=cluster1]
└── prd-cluster2  [environment=prd, cluster-id=cluster2]
```

Distribuição:

```text
cluster1 -> app1, app2
cluster2 -> app2
```

## Branches

- `uat`: Argo UAT observa somente `uat`
- `prd`: Argo PRD observa somente `prd`

O `clusterId` é lógico. O Cluster Generator resolve o cluster EKS físico pelos labels do Secret registrado no Argo CD.

## Helm + Kustomize

O chart local está em `charts/microservice`.

Cada app possui uma base Kustomize que chama o chart local via `helmCharts`. O overlay `environment` aplica o patch específico do branch.

## Configuração necessária no Argo CD

Antes do bootstrap, habilite Helm no build do Kustomize:

```bash
kubectl --context ARGO-UAT apply -f argocd/bootstrap/argocd-cm-patch.yaml
kubectl --context ARGO-UAT -n argocd rollout restart deployment argocd-repo-server
```

Repita no Argo PRD.

## Registrar e rotular clusters

Exemplo UAT, após registrar os clusters no Argo:

```bash
kubectl --context ARGO-UAT -n argocd label secret SECRET_CLUSTER1 \
  environment=uat cluster-id=cluster1

kubectl --context ARGO-UAT -n argocd label secret SECRET_CLUSTER2 \
  environment=uat cluster-id=cluster2
```

No PRD use `environment=prd`.

## Repo URL

Troque `https://git.example.com/platform/gitops.git` pela URL real do repositório em `argocd/`.

## Bootstrap

```bash
git checkout uat
kubectl --context ARGO-UAT -n argocd apply -f argocd/bootstrap/root-app.yaml
```

Para PRD:

```bash
git checkout prd
kubectl --context ARGO-PRD -n argocd apply -f argocd/bootstrap/root-app.yaml
```

## Validação

Dependências locais: `helm`, `kustomize`, `yamllint` e `kubeconform`.

```bash
make validate
```

## Isolamento

A fronteira principal não é o branch. São duas instâncias Argo CD separadas e cada uma deve registrar somente os clusters do próprio ambiente. O `AppProject` também limita os destinos pelos nomes físicos dos clusters.

O script abaixo detecta Secret de cluster com label de ambiente incorreto:

```bash
./scripts/check-isolation.sh uat
./scripts/check-isolation.sh prd
```
