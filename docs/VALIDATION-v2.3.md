# GitOps Argo CD v2.3 --- Validação e Troubleshooting

## 1. Objetivo e arquitetura

Este roteiro valida ponta a ponta o modelo GitOps com um Argo CD
exclusivo para UAT e outro exclusivo para PRD. Cada Argo gerencia
somente os clusters do próprio ambiente e lê somente o branch
correspondente.

``` text
Argo UAT -> branch uat -> clusters UAT
Argo PRD -> branch prd -> clusters PRD
```

Laboratório UAT:

``` text
uat-cluster1
├── app1
└── app2

uat-cluster2
└── app2
```

`app1-cluster2` não deve existir.

O branch representa o ambiente. O overlay continua genérico:

``` text
branch uat -> apps/<app>/overlays/environment
branch prd -> apps/<app>/overlays/environment
```

Não criar `overlays/uat` e `overlays/prd` neste modelo.

## 2. Mudança v2.3 --- appPath

Na v2.2 havia colisão com `.path`, objeto interno do Git files generator
com Go Template.

Problema:

``` yaml
path: '{{ .path }}'
```

Erro observado:

``` text
ComparisonError
Failed to load target state
map[basename:cluster1 filename:app1.yaml path:clusters/cluster1 ...]:
app path does not exist
```

Correção v2.3 nos arquivos `clusters/*/*.yaml`:

``` yaml
app: app1
clusterId: cluster1
namespace: app1
appPath: apps/app1/overlays/environment
```

ApplicationSet:

``` yaml
source:
  repoURL: git@github.com:celeguim/gitops.git
  targetRevision: uat
  path: '{{ .appPath }}'
```

Conceitos:

``` text
.path.path = localização do arquivo do Git generator
.appPath   = source path da workload
```

## 3. Pré-requisitos

``` bash
export ARGO_UAT_CONTEXT=docker-desktop

echo "$ARGO_UAT_CONTEXT"
kubectl config get-contexts
argocd context
argocd version
argocd repo list
argocd cluster list
```

O repo deve aparecer como `Successful`.

## 4. Git e branch

``` bash
git branch --show-current
git remote -v
git branch -vv
git ls-remote --heads origin uat
```

Esperado: branch `uat`, remote `git@github.com:celeguim/gitops.git` e
tracking de `origin/uat`.

## 5. Validar overlays

``` bash
find apps -type d | sort
```

Esperado:

``` text
apps/app1/base
apps/app1/overlays/environment
apps/app2/base
apps/app2/overlays/environment
```

Teste negativo:

``` bash
find apps -type d \( -name uat -o -name prd \)
```

Esperado: nenhuma saída.

## 6. Validar appPath

``` bash
grep -R -E '^(path|appPath):' -n clusters
grep -R '^path:' -n clusters
grep -n -E '\.path|appPath' argocd/applicationsets/workloads.yaml
```

Esperado nos metadados:

``` text
clusters/cluster1/app1.yaml:appPath: apps/app1/overlays/environment
clusters/cluster1/app2.yaml:appPath: apps/app2/overlays/environment
clusters/cluster2/app2.yaml:appPath: apps/app2/overlays/environment
```

Deve existir:

``` yaml
path: '{{ .appPath }}'
```

Não deve existir:

``` yaml
path: '{{ .path }}'
```

Teste automático:

``` bash
if grep -q "path: '{{ \.path }}'" argocd/applicationsets/workloads.yaml; then
  echo "FAIL: ApplicationSet still uses .path"
  exit 1
else
  echo "PASS: ApplicationSet uses appPath"
fi
```

## 7. Validar associação app x cluster

``` bash
find clusters -type f -name '*.yaml' | sort
```

Esperado:

``` text
clusters/cluster1/app1.yaml
clusters/cluster1/app2.yaml
clusters/cluster2/app2.yaml
```

Teste negativo:

``` bash
test ! -f clusters/cluster2/app1.yaml \
  && echo "PASS: app1 is not assigned to cluster2" \
  || { echo "FAIL: app1 is assigned to cluster2"; exit 1; }
```

## 8. Validação estática e push

``` bash
make validate
git status
git diff
```

Diff conceitual v2.2 -\> v2.3:

``` diff
-path: apps/app1/overlays/environment
+appPath: apps/app1/overlays/environment
```

``` diff
-path: '{{ .path }}'
+path: '{{ .appPath }}'
```

Publicação:

``` bash
git add .
git commit -m "fix: use appPath for ApplicationSet workload source"
git push
git status
```

## 9. Repo SSH no Argo

``` bash
argocd repo list
```

Se vazio:

``` bash
export GITOPS_REPO="$(git remote get-url origin)"

argocd repo add "$GITOPS_REPO" \
  --ssh-private-key-path ~/.ssh/id_ed25519

argocd repo list
```

Usar a private key, nunca o `.pub`. Em produção, usar credencial GitOps
dedicada e read-only, não chave pessoal.

## 10. Clusters e labels de isolamento

``` bash
argocd cluster list
```

Esperado:

``` text
uat-cluster1
uat-cluster2
```

Labels:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster \
  -L environment,cluster-id
```

Esperado:

``` text
uat  cluster1
uat  cluster2
```

Teste negativo:

``` bash
if kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster \
  -o jsonpath='{range .items[*]}{.metadata.labels.environment}{"\n"}{end}' \
  | grep -qx prd; then
  echo "FAIL: PRD cluster registered in UAT Argo"
  exit 1
else
  echo "PASS: no PRD cluster registered in UAT Argo"
fi
```

## 11. Root App

``` bash
argocd app get platform-root-uat --hard-refresh
```

Esperado:

``` text
Sync Status:   Synced
Health Status: Healthy
AppProject      uat             Synced
ApplicationSet  workloads-uat   Synced Healthy
```

Status via Kubernetes:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get application platform-root-uat \
  -o jsonpath='SYNC={.status.sync.status}{"\n"}HEALTH={.status.health.status}{"\n"}RECONCILED={.status.reconciledAt}{"\n"}REVISION={.status.sync.revision}{"\n"}'
```

Conditions:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get application platform-root-uat \
  -o jsonpath='{range .status.conditions[*]}TYPE={.type}{"\n"}MESSAGE={.message}{"\n\n"}{end}'
```

Em estado saudável, conditions pode estar vazio.

## 12. Comparar revision Argo x Git

``` bash
ARGO_REVISION=$(argocd app get platform-root-uat -o json | jq -r '.status.sync.revision')
GIT_REVISION=$(git rev-parse origin/uat)

echo "ARGO=$ARGO_REVISION"
echo "GIT =$GIT_REVISION"

test "$ARGO_REVISION" = "$GIT_REVISION" \
  && echo "PASS: Argo is using latest UAT commit" \
  || { echo "FAIL: Argo revision differs from origin/uat"; exit 1; }
```

## 13. ApplicationSet e Applications

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get applicationset workloads-uat \
  -o jsonpath='{range .status.conditions[*]}TYPE={.type}{"\n"}STATUS={.status}{"\n"}REASON={.reason}{"\n"}MESSAGE={.message}{"\n\n"}{end}'
```

Visão consolidada:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get applications \
  -o custom-columns='APPLICATION:.metadata.name,PROJECT:.spec.project,DESTINATION:.spec.destination.name,NAMESPACE:.spec.destination.namespace,SYNC:.status.sync.status,HEALTH:.status.health.status'
```

Esperado:

``` text
app1-cluster1       uat       uat-cluster1  app1    Synced  Healthy
app2-cluster1       uat       uat-cluster1  app2    Synced  Healthy
app2-cluster2       uat       uat-cluster2  app2    Synced  Healthy
platform-root-uat   default   <none>         argocd  Synced  Healthy
```

O Matrix deve gerar três Applications, não o produto cartesiano de
quatro.

## 14. Validar source.path da v2.3

``` bash
for app in app1-cluster1 app2-cluster1 app2-cluster2; do
  echo
  echo "===== $app ====="
  kubectl --context "$ARGO_UAT_CONTEXT" \
    -n argocd get application "$app" \
    -o jsonpath='PATH={.spec.source.path}{"\n"}'
done
```

Esperado:

``` text
app1-cluster1 -> apps/app1/overlays/environment
app2-cluster1 -> apps/app2/overlays/environment
app2-cluster2 -> apps/app2/overlays/environment
```

Teste automático:

``` bash
INVALID_PATHS=$(
  kubectl --context "$ARGO_UAT_CONTEXT" -n argocd get applications -o json \
  | jq -r '.items[] | select(.metadata.name != "platform-root-uat") | .spec.source.path' \
  | grep -v '^apps/.*/overlays/environment$' || true
)

if [ -n "$INVALID_PATHS" ]; then
  echo "FAIL: invalid Application source paths"
  echo "$INVALID_PATHS"
  exit 1
else
  echo "PASS: all workloads use overlays/environment"
fi
```

## 15. Teste negativo app1-cluster2

``` bash
if kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get application app1-cluster2 >/dev/null 2>&1; then
  echo "FAIL: app1-cluster2 exists"
  exit 1
else
  echo "PASS: app1-cluster2 does not exist"
fi
```

## 16. Deploy físico no uat-cluster1

No lab, cluster1 é Minikube:

``` bash
kubectl --context minikube get namespace app1 app2
kubectl --context minikube -n app1 get all
kubectl --context minikube -n app2 get all
```

Esperado: app1 e app2.

## 17. Deploy físico no uat-cluster2

No lab, cluster2 é Docker Desktop/in-cluster:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" -n app2 get all
```

Esperado: app2.

Teste negativo:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n app1 get all \
  -l argocd.argoproj.io/instance=app1-cluster2
```

Esperado: `No resources found`.

## 18. Ownership Argo

``` bash
kubectl --context minikube \
  -n app1 get all \
  -l argocd.argoproj.io/instance=app1-cluster1

kubectl --context minikube \
  -n app2 get all \
  -l argocd.argoproj.io/instance=app2-cluster1

kubectl --context "$ARGO_UAT_CONTEXT" \
  -n app2 get all \
  -l argocd.argoproj.io/instance=app2-cluster2
```

## 19. Self-healing

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" -n app2 get deployment

kubectl --context "$ARGO_UAT_CONTEXT" \
  -n app2 scale deployment app2 --replicas=7

kubectl --context "$ARGO_UAT_CONTEXT" \
  -n app2 get deployment app2 -w
```

Com `selfHeal: true`, o número de réplicas deve retornar ao valor do
Git.

``` bash
argocd app get app2-cluster2
```

## 20. Prune

Adicione temporariamente ao Git:

``` yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prune-test
data:
  validation: "v2.3"
```

Inclua no Kustomization, commit e push.

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" -n app2 get configmap prune-test
```

Remova o recurso do Git, commit e push.

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" -n app2 get configmap prune-test
```

Esperado: `NotFound`.

## 21. AppProject e isolamento

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get appproject uat -o yaml
```

Revisar:

``` text
spec.sourceRepos
spec.destinations
```

Evitar em produção:

``` yaml
destinations:
  - server: '*'
    namespace: '*'
```

Teste negativo recomendado: criar uma Application temporária no projeto
`uat` apontando para destino não autorizado. O AppProject deve bloquear
o destino.

## 22. Troubleshooting --- Sync Unknown

Sintoma:

``` text
SYNC=Unknown
HEALTH=Healthy
```

Diagnóstico:

``` bash
argocd app get <application> --hard-refresh
```

Conditions:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get application <application> \
  -o jsonpath='{range .status.conditions[*]}TYPE={.type}{"\n"}MESSAGE={.message}{"\n\n"}{end}'
```

Repo-server:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd logs deployment/argocd-repo-server --since=10m \
  | grep -E -i '<application>|kustomize|manifest|error|failed'
```

Controller:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd logs statefulset/argocd-application-controller --since=10m \
  | grep -E -i '<application>|comparison|manifest|error|failed'
```

Se as Applications corretas já existem, o Matrix provavelmente
funcionou. Investigue `repoURL`, `targetRevision`, `source.path`,
Kustomize, Helm e repo-server.

## 23. Troubleshooting --- app path does not exist

Issue v2.2:

``` text
ComparisonError
map[basename:cluster1 filename:app1.yaml path:clusters/cluster1 ...]:
app path does not exist
```

Causa:

``` yaml
path: '{{ .path }}'
```

Correção:

``` yaml
path: '{{ .appPath }}'
```

Validação:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get application app1-cluster1 \
  -o jsonpath='{.spec.source.path}{"\n"}'
```

Esperado:

``` text
apps/app1/overlays/environment
```

## 24. Troubleshooting --- argocd-cm not found

Sintoma:

``` text
rpc error: code = NotFound desc =
error retrieving argocd-cm:
configmap "argocd-cm" not found
```

Valide:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" -n argocd get configmap argocd-cm

kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get cm argocd-cm \
  -o jsonpath='NAME={.metadata.name}{"\n"}NAMESPACE={.metadata.namespace}{"\n"}LABELS={.metadata.labels}{"\n"}DATA={.data}{"\n"}'
```

Esperado:

``` text
NAME=argocd-cm
NAMESPACE=argocd
LABELS={"app.kubernetes.io/part-of":"argocd"}
DATA={"kustomize.buildOptions":"--enable-helm"}
```

Logs:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd logs deployment/argocd-server --since=10m | tail -100
```

Sinais saudáveis:

``` text
namespace=argocd
Starting configmap/secret informers
Configmap/secret informer synced
argocd serving on port 8080
```

Não recriar o ConfigMap antes de confirmar sua ausência real.

## 25. Troubleshooting --- repo list vazio com SSH

O Git funcionar no Mac não significa que o repo-server possua sua chave.

``` bash
export GITOPS_REPO="$(git remote get-url origin)"

argocd repo add "$GITOPS_REPO" \
  --ssh-private-key-path ~/.ssh/id_ed25519

argocd repo list
```

Esperado: `Successful`.

## 26. Troubleshooting --- Minikube registrado com 127.0.0.1

Erro:

``` text
Get "https://127.0.0.1:<porta>/version":
dial tcp 127.0.0.1:<porta>: connect: connection refused
```

Para o Pod do Argo, `127.0.0.1` é o próprio Pod.

No lab, foi usado:

``` text
https://host.docker.internal:55559
```

Descubra a porta:

``` bash
docker port minikube
```

Teste a partir do cluster do Argo:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd run network-test \
  --rm -it --restart=Never --image=curlimages/curl -- \
  curl -vk --connect-timeout 5 \
  https://host.docker.internal:55559/version
```

## 27. Troubleshooting --- kubeconfig local e host.docker.internal

Erro:

``` text
dial tcp: lookup host.docker.internal: no such host
```

O endpoint acessível pelo Argo dentro de container pode não ser adequado
ao `kubectl` local no Mac.

Para o lab, manter contextos/kubeconfigs separados é preferível. O
endpoint do Argo e o endpoint do `kubectl` local não precisam ser
iguais.

No EKS, o Argo usará o endpoint real da API EKS.

## 28. Troubleshooting --- kubectl exec no Docker Desktop

Erro observado:

``` text
Post "//[::]:<porta>/cri/exec/...":
http: server gave HTTP response to HTTPS client
```

Não tratar esse erro isoladamente como falha do Argo CD.

Alternativas de diagnóstico:

``` bash
kubectl get pod -o yaml
kubectl logs
kubectl auth can-i
kubectl get deployment -o jsonpath=...
```

## 29. Troubleshooting --- port-forward

Comando:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd port-forward svc/argocd-server 8080:443
```

Saída como:

``` text
Forwarding from 127.0.0.1:8080 -> 8080
```

é esperada quando a porta 443 do Service aponta para `targetPort: 8080`.

Diagnóstico local:

``` bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
ps aux | grep '[k]ubectl.*port-forward'
kubectl --context "$ARGO_UAT_CONTEXT" -n argocd get svc argocd-server -o yaml
```

## 30. Troubleshooting --- Helm dentro do Kustomize

Valide:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get configmap argocd-cm \
  -o jsonpath='{.data.kustomize\.buildOptions}{"\n"}'
```

Esperado:

``` text
--enable-helm
```

Configuração:

``` yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: argocd
data:
  kustomize.buildOptions: --enable-helm
```

Quando necessário:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd rollout restart deployment argocd-repo-server
```

## 31. Checklist de aprovação v2.3

``` text
[PASS] make validate
[PASS] branch uat
[PASS] repo SSH Successful
[PASS] no PRD clusters in UAT Argo
[PASS] Root App Synced / Healthy
[PASS] ApplicationSet Healthy
[PASS] app1-cluster1 exists
[PASS] app2-cluster1 exists
[PASS] app2-cluster2 exists
[PASS] app1-cluster2 does not exist
[PASS] all source.path use apps/<app>/overlays/environment
[PASS] cluster1 contains app1 + app2
[PASS] cluster2 contains only app2
[PASS] Argo ownership is correct
[PASS] selfHeal works
[PASS] prune works
[PASS] AppProject blocks invalid destinations
```

## 32. Próxima etapa --- EKS

Ao migrar o lab para EKS, preservar:

``` text
Argo UAT
├── somente clusters UAT
├── somente branch uat
└── AppProject somente destinos UAT

Argo PRD
├── somente clusters PRD
├── somente branch prd
└── AppProject somente destinos PRD
```

Revisar também autenticação EKS, IAM, IRSA/Pod Identity, endpoints
privados/públicos, security groups, NACLs, rotas, DNS, TLS/CA,
credencial Git dedicada, branch protection, PR approval para PRD, HA do
Argo PRD, backup e observabilidade.

O isolamento deve existir em camadas: instância Argo, branch, clusters
registrados e AppProject devem reforçar a mesma fronteira de ambiente.
