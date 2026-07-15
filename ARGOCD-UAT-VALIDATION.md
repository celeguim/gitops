# Lab de validação --- Argo CD UAT multi-cluster

Este roteiro valida **somente UAT** antes de repetir o modelo em PRD.

## Resultado esperado

Ao final, o Argo CD UAT deve gerar exatamente:

``` text
app1-cluster1 -> uat-cluster1
app2-cluster1 -> uat-cluster1
app2-cluster2 -> uat-cluster2
```

Não deve existir:

``` text
app1-cluster2
```

A distribuição vem dos arquivos Git:

``` text
clusters/cluster1/app1.yaml
clusters/cluster1/app2.yaml
clusters/cluster2/app2.yaml
```

------------------------------------------------------------------------

## Regra do teste

Execute **uma etapa por vez**.

Se uma etapa falhar, pare e corrija antes de continuar.

Defina os contextos reais abaixo. Não copie literalmente `ARGO-UAT`,
`UAT-CLUSTER1` e `UAT-CLUSTER2` sem conferir o seu kubeconfig.

------------------------------------------------------------------------

# Etapa 1 --- Conferir o branch UAT

``` bash
git checkout uat
git status
git branch -v
```

Esperado:

``` text
On branch uat
```

Confirme também:

``` bash
git log -1 --oneline
```

------------------------------------------------------------------------

# Etapa 2 --- Validar o repositório local

``` bash
make validate
```

Esperado:

``` text
1 chart(s) linted, 0 chart(s) failed
Rendering app1
...
Rendering app2
...
Validation completed successfully
```

Não continue se houver erro.

------------------------------------------------------------------------

# Etapa 3 --- Conferir os contextos Kubernetes

``` bash
kubectl config get-contexts
```

Identifique:

``` text
Argo CD UAT
uat-cluster1
uat-cluster2
```

Opcionalmente, defina variáveis para facilitar o lab:

``` bash
export ARGO_UAT_CONTEXT="docker-desktop"
export UAT_CLUSTER1_CONTEXT="minikube"
export UAT_CLUSTER2_CONTEXT="docker-desktop"
```

Valide:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" cluster-info
kubectl --context "$UAT_CLUSTER1_CONTEXT" cluster-info
kubectl --context "$UAT_CLUSTER2_CONTEXT" cluster-info
```

------------------------------------------------------------------------

# Etapa 4 --- Confirmar o Argo CD UAT

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get pods
```

Esperado: componentes principais do Argo CD em `Running` ou `Completed`,
conforme o tipo de workload.

Confira a versão:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get deployment argocd-server \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Registre a versão encontrada:

``` text
Argo CD version: ______________________
```

------------------------------------------------------------------------

# Etapa 5 --- Conferir clusters já registrados no Argo

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster
```

Para visualizar nome e labels:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster \
  -o custom-columns='SECRET:.metadata.name,ENV:.metadata.labels.environment,CLUSTER_ID:.metadata.labels.cluster-id'
```

Neste ponto queremos identificar os Secrets correspondentes a:

``` text
uat-cluster1
uat-cluster2
```

Se os clusters ainda não estiverem registrados, **pare aqui**.

O próximo passo será registrar os EKS no Argo CD usando a estratégia de
autenticação já adotada no ambiente.

------------------------------------------------------------------------

# Etapa 6 --- Descobrir o nome real registrado no Argo

O nome usado em `AppProject.spec.destinations[].name` precisa casar com
o nome do cluster conhecido pelo Argo CD.

Execute:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster \
  -o jsonpath='{range .items[*]}{"SECRET="}{.metadata.name}{" NAME="}{.data.name}{"\n"}{end}'
```

Atenção: `.data.name` está em base64.

Para decodificar individualmente:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get secret NOME_DO_SECRET \
  -o jsonpath='{.data.name}' | base64 -d

echo
```

Esperado:

``` text
uat-cluster1
```

e:

``` text
uat-cluster2
```

Se os nomes forem diferentes, **não altere o cluster ainda**. Ajuste o
modelo GitOps ou confirme a convenção de nomes antes de continuar.

------------------------------------------------------------------------

# Etapa 7 --- Aplicar labels nos Secrets dos clusters

Primeiro descubra os nomes dos Secrets:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster
```

Defina:

``` bash
export UAT_CLUSTER1_SECRET="SECRET-REAL-DO-CLUSTER1"
export UAT_CLUSTER2_SECRET="SECRET-REAL-DO-CLUSTER2"
```

Aplique os labels:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd label secret "$UAT_CLUSTER1_SECRET" \
  environment=uat \
  cluster-id=cluster1 \
  --overwrite
```

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd label secret "$UAT_CLUSTER2_SECRET" \
  environment=uat \
  cluster-id=cluster2 \
  --overwrite
```

Valide:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster \
  -L environment,cluster-id
```

Esperado:

``` text
uat-cluster1 -> environment=uat cluster-id=cluster1
uat-cluster2 -> environment=uat cluster-id=cluster2
```

------------------------------------------------------------------------

# Etapa 8 --- Executar o check de isolamento

O script usa o contexto Kubernetes corrente. Portanto, selecione
explicitamente o Argo UAT antes de executá-lo:

``` bash
kubectl config use-context "$ARGO_UAT_CONTEXT"
```

Agora:

``` bash
./scripts/check-isolation.sh uat
```

Esperado:

``` text
OK: ...
OK: ...
```

Não deve existir cluster Secret com:

``` text
environment=prd
```

no Argo UAT.

Depois do teste, se necessário, retorne ao contexto anterior
manualmente.

------------------------------------------------------------------------

# Etapa 9 --- Configurar Kustomize com Helm no Argo CD

Confira o valor atual:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get configmap argocd-cm \
  -o jsonpath='{.data.kustomize\.buildOptions}{"\n"}'
```

Aplique o patch do repo:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  apply -f argocd/bootstrap/argocd-cm-patch.yaml
```

Confira novamente:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get configmap argocd-cm \
  -o jsonpath='{.data.kustomize\.buildOptions}{"\n"}'
```

Esperado:

``` text
--enable-helm
```

Reinicie o repo-server:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd rollout restart deployment argocd-repo-server
```

Acompanhe:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd rollout status deployment argocd-repo-server
```

------------------------------------------------------------------------

# Etapa 10 --- Ajustar a URL real do repositório

Localize a URL fictícia:

``` bash
grep -R "git.example.com/platform/gitops.git" \
  -n argocd
```

No branch `uat`, ajuste os arquivos para a URL Git real.

Confira:

``` bash
grep -R "repoURL:" \
  -n argocd
```

Os arquivos principais são:

``` text
argocd/projects/environment-project.yaml
argocd/applicationsets/workloads.yaml
argocd/bootstrap/root-app.yaml
```

Faça commit e push no branch `uat`:

``` bash
git status
git add argocd
git commit -m "chore: configure UAT GitOps repository"
git push origin uat
```

Confirme que o Argo CD UAT consegue acessar o repositório antes do
bootstrap.

------------------------------------------------------------------------

# Etapa 11 --- Conferir o AppProject antes do bootstrap

``` bash
cat argocd/projects/environment-project.yaml
```

Esperado:

``` yaml
destinations:
  - namespace: '*'
    name: uat-cluster1
  - namespace: '*'
    name: uat-cluster2
```

Confirme que os nomes são exatamente os nomes registrados no Argo CD.

------------------------------------------------------------------------

# Etapa 12 --- Conferir o ApplicationSet antes do bootstrap

``` bash
cat argocd/applicationsets/workloads.yaml
```

Pontos obrigatórios:

``` yaml
revision: uat
```

``` yaml
matchLabels:
  environment: uat
  cluster-id: '{{ .clusterId }}'
```

``` yaml
targetRevision: uat
```

``` yaml
destination:
  name: '{{ .name }}'
  namespace: '{{ .namespace }}'
```

------------------------------------------------------------------------

# Etapa 13 --- Aplicar somente o Root App

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd apply \
  -f argocd/bootstrap/root-app.yaml
```

Confira:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get application platform-root-uat
```

Depois:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get application platform-root-uat \
  -o wide
```

------------------------------------------------------------------------

# Etapa 14 --- Confirmar criação do AppProject

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get appproject uat
```

Confira destinos:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get appproject uat \
  -o yaml
```

Esperado:

``` text
uat-cluster1
uat-cluster2
```

Nenhum destino PRD deve existir.

------------------------------------------------------------------------

# Etapa 15 --- Confirmar criação do ApplicationSet

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get applicationset workloads-uat
```

Veja as condições:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get applicationset workloads-uat \
  -o yaml
```

Ou:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd describe applicationset workloads-uat
```

Se houver erro de generator, template ou Git, **pare aqui** e capture o
output do `describe`.

------------------------------------------------------------------------

# Etapa 16 --- Validar Applications geradas

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get applications
```

Esperado:

``` text
app1-cluster1
app2-cluster1
app2-cluster2
platform-root-uat
```

Não deve existir:

``` text
app1-cluster2
```

Validação objetiva:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get applications \
  -o custom-columns='APPLICATION:.metadata.name,PROJECT:.spec.project,DESTINATION:.spec.destination.name,NAMESPACE:.spec.destination.namespace'
```

Esperado:

``` text
app1-cluster1   uat   uat-cluster1   app1
app2-cluster1   uat   uat-cluster1   app2
app2-cluster2   uat   uat-cluster2   app2
```

O Root App também aparecerá na listagem com o projeto `default`.

------------------------------------------------------------------------

# Etapa 17 --- Validar que app1 não foi para cluster2

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get application app1-cluster2
```

Esperado:

``` text
Error from server (NotFound)
```

Esse teste comprova que a presença ou ausência do arquivo em `clusters/`
controla a distribuição das aplicações.

------------------------------------------------------------------------

# Etapa 18 --- Validar recursos nos clusters EKS

No `uat-cluster1`:

``` bash
kubectl --context "$UAT_CLUSTER1_CONTEXT" \
  -n app1 get deployment,service
```

``` bash
kubectl --context "$UAT_CLUSTER1_CONTEXT" \
  -n app2 get deployment,service
```

No `uat-cluster2`:

``` bash
kubectl --context "$UAT_CLUSTER2_CONTEXT" \
  -n app2 get deployment,service
```

Teste negativo:

``` bash
kubectl --context "$UAT_CLUSTER2_CONTEXT" \
  -n app1 get deployment
```

Esperado: namespace/recurso inexistente.

------------------------------------------------------------------------

# Etapa 19 --- Validar o patch UAT

App1:

``` bash
kubectl --context "$UAT_CLUSTER1_CONTEXT" \
  -n app1 get deployment app1 \
  -o jsonpath='{.spec.replicas}{"\n"}'
```

Esperado:

``` text
2
```

Confira as variáveis:

``` bash
kubectl --context "$UAT_CLUSTER1_CONTEXT" \
  -n app1 get deployment app1 \
  -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}'
```

Esperado:

``` text
ENVIRONMENT=uat
LOG_LEVEL=DEBUG
```

------------------------------------------------------------------------

# Etapa 20 --- Resultado da validação UAT

Marque os itens concluídos:

``` text
[ ] make validate passou
[ ] Argo CD UAT saudável
[ ] uat-cluster1 registrado
[ ] uat-cluster2 registrado
[ ] labels environment/cluster-id corretos
[ ] check-isolation.sh passou
[ ] --enable-helm configurado
[ ] repo UAT acessível pelo Argo
[ ] platform-root-uat criado
[ ] AppProject uat criado
[ ] ApplicationSet workloads-uat criado
[ ] app1-cluster1 criado
[ ] app2-cluster1 criado
[ ] app2-cluster2 criado
[ ] app1-cluster2 NÃO criado
[ ] app1 presente em uat-cluster1
[ ] app2 presente em uat-cluster1
[ ] app2 presente em uat-cluster2
[ ] app1 ausente de uat-cluster2
[ ] ENVIRONMENT=uat
[ ] LOG_LEVEL=DEBUG
[ ] replicas=2
```

## Em caso de erro no ApplicationSet

Cole a saída completa destes comandos:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd describe applicationset workloads-uat
```

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get applicationset workloads-uat \
  -o yaml
```

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd logs deployment/argocd-applicationset-controller \
  --tail=200
```

Não avance para PRD até o teste UAT passar integralmente.
