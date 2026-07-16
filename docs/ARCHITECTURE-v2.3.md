# Arquitetura GitOps com Argo CD --- v2.3

## 1. Visão geral

Este documento descreve a arquitetura GitOps definida para gerenciamento
de workloads Kubernetes em ambientes UAT e PRD.

A solução foi desenhada para atender ao requisito principal de
isolamento:

> UAT não pode gerenciar recursos de PRD e PRD não pode gerenciar
> recursos de UAT.

A arquitetura utiliza instâncias independentes do Argo CD, branches Git
dedicados por ambiente, clusters registrados e classificados por labels,
ApplicationSet para geração dinâmica das Applications, AppProject como
barreira adicional de autorização, Helm para templates reutilizáveis e
Kustomize para composição e customização do desired state.

O modelo foi inicialmente validado em laboratório utilizando Docker
Desktop Kubernetes e Minikube. Após a validação funcional, o mesmo
conceito será transportado para Amazon EKS.

## 2. Requisitos arquiteturais

Os requisitos considerados foram:

-   ambientes UAT e PRD completamente separados no plano de
    gerenciamento GitOps;
-   uma instância Argo CD para UAT;
-   uma instância Argo CD para PRD;
-   cada Argo CD gerenciando múltiplos clusters;
-   previsão de aproximadamente cinco clusters por ambiente;
-   aplicações distribuídas seletivamente entre os clusters;
-   ausência de produto cartesiano automático entre aplicações e
    clusters;
-   branches `uat` e `prd` já existentes e representando o desired state
    de cada ambiente;
-   charts Helm locais;
-   Kustomize com base comum e patch por ambiente;
-   possibilidade de evolução do laboratório local para EKS;
-   automação e validação em CI;
-   facilidade de auditoria da relação aplicação x cluster.

## 3. Arquitetura escolhida: Hub-Spoke

Foi adotado um modelo Hub-Spoke de gerenciamento GitOps.

``` text
                         Git Repository
                              |
                  +-----------+-----------+
                  |                       |
              branch uat               branch prd
                  |                       |
                  v                       v
             Argo CD UAT              Argo CD PRD
                HUB                       HUB
                  |                       |
        +---------+---------+   +---------+---------+
        |         |         |   |         |         |
      UAT C1    UAT C2    UAT Cn       PRD C1    PRD C2    PRD Cn
      SPOKE     SPOKE      SPOKE        SPOKE     SPOKE      SPOKE
```

Cada instância Argo CD representa um Hub.

Os clusters Kubernetes gerenciados são os Spokes.

O Argo UAT registra exclusivamente clusters UAT.

O Argo PRD registra exclusivamente clusters PRD.

O isolamento não depende somente do branch Git. Ele é aplicado em
múltiplas camadas:

``` text
1. Instância Argo CD
2. Branch Git
3. Clusters registrados
4. Labels dos cluster Secrets
5. Cluster generator
6. AppProject
7. Políticas de acesso ao Git
```

Essa abordagem implementa defesa em profundidade.

## 4. Por que dois Argo CDs

Uma alternativa seria utilizar uma única instalação Argo CD para todos
os ambientes.

Esse modelo foi descartado para o cenário atual porque uma falha de
configuração, permissão ou ApplicationSet poderia ampliar o blast radius
entre UAT e PRD.

Com duas instâncias:

``` text
Argo UAT
  |
  +-- credenciais UAT
  +-- clusters UAT
  +-- branch uat
  +-- AppProject UAT

Argo PRD
  |
  +-- credenciais PRD
  +-- clusters PRD
  +-- branch prd
  +-- AppProject PRD
```

Mesmo que o ApplicationSet de UAT seja configurado incorretamente, a
instância não deveria possuir credenciais ou destinos autorizados para
PRD.

A separação também permite políticas operacionais diferentes.

Exemplo:

``` text
UAT
- sync automatizado
- selfHeal habilitado
- janela de mudança mais flexível

PRD
- branch protection
- Pull Request obrigatório
- aprovação
- Sync Windows
- RBAC mais restritivo
```

## 5. Fluxo GitOps

O fluxo lógico é:

``` text
Developer / Platform Team
          |
          v
       Git change
          |
          v
       Pull Request
          |
          v
     branch uat/prd
          |
          v
       Root App
          |
          v
      ApplicationSet
          |
          v
  Applications generated
          |
          v
     Target clusters
```

Não é necessário aplicar manualmente cada Application.

O Root App gerencia os componentes declarativos do próprio modelo
GitOps.

## 6. App of Apps / Root Application

Cada ambiente possui uma Root Application.

Exemplo UAT:

``` text
platform-root-uat
```

A Root Application aponta para:

``` text
repo:   git@github.com:celeguim/gitops.git
branch: uat
path:   argocd/root
```

A Root Application gerencia:

``` text
AppProject uat
ApplicationSet workloads-uat
```

Fluxo:

``` text
platform-root-uat
        |
        +-- AppProject/uAT
        |
        +-- ApplicationSet/workloads-uat
```

O Root App permite bootstrap simples e mantém a configuração do Argo
declarativa.

Após o bootstrap inicial, alterações no ApplicationSet e AppProject são
reconciliadas pelo próprio Argo.

## 7. Estrutura do repositório

A estrutura lógica adotada é semelhante a:

``` text
gitops/
├── .github/
│   └── workflows/
│       └── validate.yaml
├── argocd/
│   ├── bootstrap/
│   │   └── root-app.yaml
│   ├── root/
│   │   └── kustomization.yaml
│   ├── projects/
│   │   └── environment-project.yaml
│   └── applicationsets/
│       └── workloads.yaml
├── apps/
│   ├── app1/
│   │   ├── base/
│   │   └── overlays/
│   │       └── environment/
│   └── app2/
│       ├── base/
│       └── overlays/
│           └── environment/
├── charts/
│   └── microservice/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── clusters/
│   ├── cluster1/
│   │   ├── app1.yaml
│   │   └── app2.yaml
│   └── cluster2/
│       └── app2.yaml
├── docs/
├── Makefile
└── README.md
```

Cada diretório possui uma responsabilidade clara.

``` text
argocd/   = configuração do plano GitOps
apps/     = desired state das aplicações
charts/   = templates Helm reutilizáveis
clusters/ = associação explícita app x cluster
docs/     = arquitetura, testes e operação
```

## 8. Branch por ambiente

O projeto já possuía os branches:

``` text
uat
prd
```

Foi decidido utilizar o branch como dimensão de ambiente.

Assim:

``` text
targetRevision: uat
```

significa que o Argo UAT lê exclusivamente o desired state UAT.

Da mesma forma:

``` text
targetRevision: prd
```

é utilizado pelo Argo PRD.

O mesmo path lógico pode existir nos dois branches:

``` text
apps/app1/overlays/environment
```

No branch UAT, o conteúdo representa UAT.

No branch PRD, o conteúdo representa PRD.

``` text
branch uat
└── apps/app1/overlays/environment
    └── configuração UAT

branch prd
└── apps/app1/overlays/environment
    └── configuração PRD
```

Foi deliberadamente evitado o modelo:

``` text
branch uat + overlays/uat
branch prd + overlays/prd
```

porque isso representaria o ambiente duas vezes.

## 9. Por que Helm + Kustomize

Helm e Kustomize possuem responsabilidades diferentes no projeto.

O Helm é utilizado como engine de template.

O Kustomize é utilizado como engine de composição do desired state.

``` text
Helm
  |
  +-- Deployment template
  +-- Service template
  +-- Configurable values
  +-- reusable microservice chart

Kustomize
  |
  +-- base
  +-- overlay
  +-- patches
  +-- environment composition
```

O fluxo de renderização é:

``` text
Application
    |
    v
Kustomize overlay
    |
    v
Helm chart local
    |
    v
Rendered Kubernetes manifests
```

### Vantagens do Helm

-   templates reutilizáveis;
-   padronização de Deployment e Service;
-   valores parametrizáveis;
-   redução de YAML duplicado;
-   evolução centralizada do padrão de microsserviço.

### Vantagens do Kustomize

-   composição declarativa;
-   patches nativos;
-   separação entre base e overlay;
-   fácil inspeção do desired state;
-   integração nativa com Argo CD.

### Por que não usar somente Helm

Somente Helm concentraria template, valores de aplicação e diferenças
ambientais no mesmo mecanismo.

O objetivo do projeto é manter o chart como padrão técnico reutilizável
e usar o Kustomize para compor a aplicação.

### Por que não usar somente Kustomize

Somente Kustomize exigiria maior repetição estrutural para aplicações
com padrão semelhante.

O chart `microservice` centraliza o padrão comum.

### Configuração necessária no Argo

Para Kustomize renderizar Helm:

``` yaml
data:
  kustomize.buildOptions: --enable-helm
```

Validação:

``` bash
kubectl -n argocd get configmap argocd-cm \
  -o jsonpath='{.data.kustomize\.buildOptions}{"\n"}'
```

Esperado:

``` text
--enable-helm
```

## 10. Associação explícita aplicação x cluster

Um requisito importante era permitir que cada cluster executasse somente
determinadas aplicações.

Exemplo:

``` text
cluster1 = app1 + app2
cluster2 = app2
```

Foi evitado um ApplicationSet que produzisse:

``` text
apps x clusters
```

porque isso geraria:

``` text
app1-cluster1
app1-cluster2
app2-cluster1
app2-cluster2
```

O resultado correto é:

``` text
app1-cluster1
app2-cluster1
app2-cluster2
```

A associação é declarada em arquivos Git.

Exemplo:

``` yaml
app: app1
clusterId: cluster1
namespace: app1
appPath: apps/app1/overlays/environment
```

O arquivo existe em:

``` text
clusters/cluster1/app1.yaml
```

Para habilitar app1 no cluster2, seria criado:

``` text
clusters/cluster2/app1.yaml
```

Isso torna a distribuição de workloads explícita, versionável e
auditável.

## 11. ApplicationSet

O ApplicationSet utiliza os metadados Git e os clusters registrados no
Argo.

Conceitualmente:

``` text
Git files generator
        |
        | app
        | clusterId
        | namespace
        | appPath
        v
Matrix generator
        ^
        | name
        | environment
        | cluster-id
        |
Cluster generator
```

A combinação deve ocorrer somente quando o arquivo de associação e o
cluster selecionado representam o mesmo `clusterId` e ambiente.

O template gera Applications como:

``` text
<app>-<clusterId>
```

Exemplos:

``` text
app1-cluster1
app2-cluster1
app2-cluster2
```

## 12. Labels dos clusters

O Argo CD representa clusters externos por Secrets no namespace
`argocd`.

Foram adotadas labels:

``` yaml
environment: uat
cluster-id: cluster1
```

ou:

``` yaml
environment: uat
cluster-id: cluster2
```

Validação:

``` bash
kubectl -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster \
  -L environment,cluster-id
```

Essas labels são utilizadas pelo Cluster generator.

O nome físico do cluster pode mudar sem alterar o identificador lógico
utilizado nos arquivos de associação.

Exemplo futuro EKS:

``` text
physical name: eks-ms-uat-sp-01
cluster-id:    cluster1
environment:   uat
```

## 13. AppProject como barreira de segurança

O ApplicationSet controla o que deve ser gerado.

O AppProject controla o que é autorizado.

Esses controles não devem ser confundidos.

``` text
ApplicationSet
    |
    +-- generation policy

AppProject
    |
    +-- authorization boundary
```

O AppProject deve restringir:

``` text
sourceRepos
destinations
clusterResourceWhitelist/Blacklist
namespaceResourceWhitelist/Blacklist
```

Uma configuração ampla como:

``` yaml
destinations:
  - server: '*'
    namespace: '*'
```

deve ser evitada em produção.

O projeto UAT deve autorizar somente destinos UAT.

O projeto PRD deve autorizar somente destinos PRD.

Assim, mesmo uma Application criada incorretamente deve ser bloqueada
pelo AppProject.

## 14. Bootstrap

O bootstrap é uma das poucas operações imperativas do modelo.

Exemplo:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  apply -f argocd/bootstrap/root-app.yaml
```

Depois disso:

``` text
kubectl apply Root App
        |
        v
Root App reconciles Git
        |
        +-- AppProject
        |
        +-- ApplicationSet
                |
                v
           Applications
                |
                v
             workloads
```

Alterações normais devem ocorrer via Git.

Não é necessário reaplicar manualmente o ApplicationSet após cada
commit.

## 15. Fluxo de mudança

Exemplo UAT:

``` bash
git checkout uat
```

Alterar desired state.

Validar:

``` bash
make validate
```

Revisar:

``` bash
git diff
git status
```

Publicar:

``` bash
git add .
git commit -m "feat: update app configuration"
git push
```

Observar:

``` bash
argocd app get platform-root-uat --hard-refresh
```

E:

``` bash
kubectl -n argocd get applications
```

## 16. Dificuldade: YAML lint e Helm templates

Durante a validação, `yamllint` reportou erros como:

``` text
too many spaces inside braces (braces)
```

em templates Helm.

Exemplo problemático:

``` yaml
name: {{ .Values.name }}
```

Dependendo da regra do linter, expressões Go Template dentro de YAML
podem gerar falsos positivos ou exigir ajuste de configuração.

Também foi observado:

``` text
truthy value should be one of [false, true]
```

em GitHub Actions para a chave:

``` yaml
on:
```

Isso ocorre porque YAML 1.1 pode interpretar `on` como valor booleano.

A solução é configurar o linter de forma compatível com arquivos Helm e
GitHub Actions, sem transformar a validação em uma fonte de falsos
positivos.

O princípio adotado foi:

``` text
lint deve detectar erro real
não deve impedir template válido por desconhecer a DSL embutida
```

## 17. Dificuldade: dependência PyYAML no make validate

Foi observado:

``` text
ModuleNotFoundError: No module named 'yaml'
```

O target de validação utilizava Python com:

``` python
import yaml
```

mas o ambiente não possuía PyYAML.

A validação foi ajustada para garantir dependências ou evitar
dependência implícita não documentada.

Lição arquitetural:

``` text
um comando de validação deve ser reproduzível
```

O ambiente local e o CI devem executar as mesmas validações.

## 18. Dificuldade: cluster Minikube registrado com localhost

O kubeconfig do Minikube apresentava:

``` text
https://127.0.0.1:55559
```

Ao executar:

``` bash
argocd cluster add minikube --name uat-cluster1
```

o Argo retornou:

``` text
failed to get server version
Get "https://127.0.0.1:55559/version":
dial tcp 127.0.0.1:55559:
connect: connection refused
```

A causa é de perspectiva de rede.

``` text
Mac:
127.0.0.1 = Mac

Argo Pod:
127.0.0.1 = próprio Pod
```

O endpoint do kubeconfig funcionava para o Mac, mas não para o Argo
dentro do Docker Desktop Kubernetes.

## 19. Solução de conectividade do Minikube

Foi identificado o mapeamento:

``` bash
docker port minikube
```

Resultado:

``` text
8443/tcp -> 127.0.0.1:55559
```

A conectividade a partir do cluster do Argo foi validada usando:

``` text
https://host.docker.internal:55559
```

Teste:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd run network-test \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl \
  -- \
  curl -vk --connect-timeout 5 \
  https://host.docker.internal:55559/version
```

A API retornou HTTP 200 e a versão Kubernetes.

Essa solução é específica do laboratório Docker Desktop/Minikube.

No EKS, o Argo utilizará o endpoint real da API EKS.

## 20. Dificuldade: kubeconfig compartilhado entre Mac e Argo

Ao alterar o kubeconfig para:

``` text
host.docker.internal
```

o `kubectl` local apresentou:

``` text
lookup host.docker.internal: no such host
```

A conclusão foi que o endpoint ideal para o Argo não precisa ser o mesmo
endpoint ideal para o operador no Mac.

Para laboratório, é preferível manter:

``` text
context/kubeconfig local
context/kubeconfig de registro no Argo
```

ou preservar uma cópia do endpoint local.

Essa dificuldade não representa uma limitação arquitetural para EKS.

## 21. Dificuldade: repo SSH não cadastrado no Argo

O Git local funcionava por SSH, porém:

``` bash
argocd repo list
```

estava vazio.

O Argo CD não herda automaticamente as credenciais SSH do Mac.

Foi necessário cadastrar o repo:

``` bash
export GITOPS_REPO="$(git remote get-url origin)"

argocd repo add "$GITOPS_REPO" \
  --ssh-private-key-path ~/.ssh/id_ed25519
```

Após isso:

``` bash
argocd repo list
```

retornou:

``` text
Successful
```

Para EKS/produção, a recomendação é utilizar uma credencial Git dedicada
e read-only.

## 22. Dificuldade: Root App Unknown

Inicialmente:

``` text
SYNC=Unknown
HEALTH=Unknown
```

O diagnóstico foi feito com:

``` bash
argocd app get platform-root-uat --hard-refresh
```

e inspeção de:

``` bash
kubectl -n argocd get application platform-root-uat -o yaml
```

Após estabilização da configuração e acesso ao repo, o Root App ficou:

``` text
Sync Status:   Synced
Health Status: Healthy
```

Gerenciando:

``` text
AppProject uat
ApplicationSet workloads-uat
```

## 23. Dificuldade: argocd-cm not found pela CLI

Foi observado:

``` text
rpc error: code = NotFound desc =
error retrieving argocd-cm:
configmap "argocd-cm" not found
```

Apesar de:

``` bash
kubectl -n argocd get configmap argocd-cm
```

confirmar a existência do ConfigMap.

A investigação incluiu:

``` bash
argocd context
argocd version
kubectl get deployment argocd-server
kubectl logs deployment/argocd-server
```

Os logs mostraram:

``` text
namespace=argocd
Starting configmap/secret informers
Configmap/secret informer synced
```

Após a estabilização do server/informers e uso correto do
contexto/port-forward, a CLI voltou a responder.

Lição: não recriar recursos imediatamente quando CLI e Kubernetes API
apresentam visões divergentes. Primeiro validar contexto, namespace,
server e logs.

## 24. Dificuldade: kubectl exec no Docker Desktop

Foi observado:

``` text
error sending request:
Post "//[::]:56055/cri/exec/...":
http: server gave HTTP response to HTTPS client
```

Esse problema ocorreu no caminho `kubectl exec` do laboratório.

Foram utilizadas alternativas:

``` bash
kubectl logs
kubectl get -o yaml
kubectl get -o jsonpath
kubectl auth can-i
```

O problema não foi considerado falha do Argo CD.

## 25. Dificuldade principal da v2.2: .path

As Applications foram geradas corretamente:

``` text
app1-cluster1
app2-cluster1
app2-cluster2
```

Porém apresentavam:

``` text
SYNC=Unknown
HEALTH=Healthy
```

O comando:

``` bash
argocd app get app1-cluster1 --hard-refresh
```

mostrou:

``` text
ComparisonError
Failed to load target state
...
map[basename:cluster1 ... path:clusters/cluster1 ...]:
app path does not exist
```

O ApplicationSet utilizava:

``` yaml
path: '{{ .path }}'
```

Com `goTemplate: true`, `.path` era um objeto do Git generator.

A correção foi criar um parâmetro de domínio explícito:

``` yaml
appPath: apps/app1/overlays/environment
```

e utilizar:

``` yaml
path: '{{ .appPath }}'
```

Essa alteração originou a v2.3.

## 26. Por que appPath é melhor

Além de corrigir o bug, `appPath` melhora a semântica.

Antes:

``` text
path
```

poderia significar:

``` text
path do arquivo Git
path do overlay
path do chart
path do Application source
```

Agora:

``` text
appPath
```

significa especificamente:

``` text
source path da workload
```

O princípio é evitar nomes de domínio que colidam com parâmetros
automáticos de generators ou engines de template.

## 27. Comandos úteis --- Argo CD

Contextos:

``` bash
argocd context
```

Versão:

``` bash
argocd version
```

Repos:

``` bash
argocd repo list
```

Clusters:

``` bash
argocd cluster list
```

Applications:

``` bash
argocd app list
```

Detalhes:

``` bash
argocd app get platform-root-uat
argocd app get app1-cluster1
```

Hard refresh:

``` bash
argocd app get app1-cluster1 --hard-refresh
```

## 28. Comandos úteis --- Kubernetes e Argo

Applications:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get applications
```

ApplicationSets:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get applicationsets
```

AppProjects:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get appprojects
```

Cluster Secrets:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster \
  -L environment,cluster-id
```

Application source:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get application app1-cluster1 \
  -o jsonpath='REPO={.spec.source.repoURL}{"\n"}REVISION={.spec.source.targetRevision}{"\n"}PATH={.spec.source.path}{"\n"}'
```

Conditions:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd get application app1-cluster1 \
  -o jsonpath='{range .status.conditions[*]}TYPE={.type}{"\n"}MESSAGE={.message}{"\n\n"}{end}'
```

## 29. Comandos úteis --- logs

Argo server:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd logs deployment/argocd-server --since=10m
```

Repo server:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd logs deployment/argocd-repo-server --since=10m
```

Application controller:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd logs statefulset/argocd-application-controller --since=10m
```

ApplicationSet controller:

``` bash
kubectl --context "$ARGO_UAT_CONTEXT" \
  -n argocd logs deployment/argocd-applicationset-controller --since=10m
```

Filtro:

``` bash
kubectl -n argocd logs deployment/argocd-repo-server --since=10m \
  | grep -E -i 'error|failed|manifest|kustomize|helm'
```

## 30. Comandos úteis --- Git

Branch:

``` bash
git branch --show-current
```

Tracking:

``` bash
git branch -vv
```

Remote:

``` bash
git remote -v
```

Revisão remota:

``` bash
git ls-remote --heads origin uat
```

Diff:

``` bash
git diff
```

Últimos commits:

``` bash
git log --oneline --decorate -10
```

Comparar Argo e Git:

``` bash
ARGO_REVISION=$(argocd app get platform-root-uat -o json | jq -r '.status.sync.revision')
GIT_REVISION=$(git rev-parse origin/uat)

echo "ARGO=$ARGO_REVISION"
echo "GIT =$GIT_REVISION"
```

## 31. Comandos úteis --- renderização local

Validação geral:

``` bash
make validate
```

Kustomize:

``` bash
kubectl kustomize apps/app1/overlays/environment --enable-helm
```

Ou:

``` bash
kustomize build apps/app1/overlays/environment --enable-helm
```

Helm:

``` bash
helm lint charts/microservice
```

Renderização Helm:

``` bash
helm template app1 charts/microservice
```

Busca de paths:

``` bash
grep -R -E 'appPath|\.path' -n clusters argocd
```

## 32. Estado validado no laboratório

Até a v2.3, o laboratório comprovou:

``` text
[OK] Argo UAT separado
[OK] branch uat
[OK] Root App
[OK] AppProject
[OK] ApplicationSet
[OK] repo privado SSH
[OK] cluster externo registrado
[OK] cluster in-cluster registrado
[OK] labels environment e cluster-id
[OK] associação seletiva app x cluster
[OK] três Applications exatas
[OK] app1-cluster2 não gerada
[OK] Helm local
[OK] Kustomize com --enable-helm
[OK] conceito overlays/environment preservado
[OK] bug .path identificado
[OK] appPath definido na v2.3
```

Os testes de runtime, self-healing, prune e bloqueio de destino pelo
AppProject fazem parte do roteiro formal `VALIDATION-v2.3.md`.

## 33. Evolução para Amazon EKS

A arquitetura lógica não deve mudar ao migrar para EKS.

O laboratório:

``` text
Docker Desktop Argo UAT
        |
        +-- Minikube
        +-- Docker Desktop in-cluster
```

será substituído por:

``` text
Argo UAT on EKS
        |
        +-- uat-cluster1 EKS
        +-- uat-cluster2 EKS
        +-- ...
        +-- uat-cluster5 EKS
```

e:

``` text
Argo PRD on EKS
        |
        +-- prd-cluster1 EKS
        +-- prd-cluster2 EKS
        +-- ...
        +-- prd-cluster5 EKS
```

Itens adicionais para EKS:

-   estratégia de autenticação entre Argo e EKS;
-   IAM;
-   IRSA ou EKS Pod Identity conforme componentes integrados;
-   endpoint privado/público da API;
-   conectividade entre Hub e Spokes;
-   VPC, Transit Gateway ou peering conforme topologia;
-   security groups;
-   NACLs;
-   route tables;
-   DNS;
-   certificados e CA;
-   HA do Argo PRD;
-   Redis HA quando aplicável;
-   backup;
-   disaster recovery;
-   métricas e alertas;
-   SSO;
-   RBAC;
-   credencial Git dedicada;
-   branch protection.

## 34. Decisões recomendadas para PRD

Para PRD, recomenda-se:

``` text
branch prd protected
Pull Request obrigatório
minimum reviewers
CODEOWNERS
proibição de force push
credencial Git read-only no Argo
SSO no Argo
RBAC por grupo
AppProject restritivo
Sync Windows quando necessário
HA
backup testado
observabilidade
```

O Argo não deve possuir capacidade de escrever no repositório Git.

Git é a origem do desired state.

## 35. Princípios finais da arquitetura

A arquitetura foi construída sobre os seguintes princípios:

### Isolamento por design

UAT e PRD possuem Hubs independentes.

### Git como source of truth

Mudanças normais ocorrem via commit e Pull Request.

### Associação explícita

Uma aplicação só vai para um cluster quando a relação existe em
`clusters/<clusterId>/<app>.yaml`.

### Defesa em profundidade

Branch, Argo, cluster registration, labels e AppProject reforçam a
fronteira ambiental.

### Reuso sem duplicação excessiva

Helm fornece templates comuns.

Kustomize compõe o desired state.

### Ambiente representado uma vez

O branch representa UAT ou PRD.

O overlay permanece `environment`.

### Operação auditável

A distribuição app x cluster pode ser determinada inspecionando o Git.

### Evolução incremental

A arquitetura foi validada localmente antes da adoção no EKS.

## 36. Conclusão

O modelo Hub-Spoke com uma instância Argo CD por ambiente atende ao
requisito de isolamento e permite escalar o gerenciamento para múltiplos
clusters.

A combinação Root App + ApplicationSet + AppProject separa bootstrap,
geração e autorização.

A combinação Helm + Kustomize separa template reutilizável de composição
ambiental.

Os branches `uat` e `prd` permanecem como fronteiras de desired state,
enquanto `overlays/environment` evita duplicar a representação do
ambiente.

A principal dificuldade técnica da v2.2, a colisão do parâmetro `.path`
com o objeto do Git files generator em Go Template, levou à introdução
de `appPath` na v2.3.

O laboratório também demonstrou a importância de analisar conectividade
a partir da perspectiva do Argo Hub. O problema de `127.0.0.1` no
Minikube não era uma falha do Kubernetes ou Argo, mas uma diferença de
perspectiva de rede entre o Mac e os Pods do Docker Desktop.

Com a v2.3, a arquitetura possui uma base clara para validação final de
runtime e posterior migração para Amazon EKS.
