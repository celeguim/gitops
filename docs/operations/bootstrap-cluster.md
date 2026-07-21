# Bootstrap Cluster

## Objetivo

Preparar um novo cluster Kubernetes para ser utilizado pelo EMP.

## Pré-requisitos

- kubectl
- kubeconfig do cluster
- Acesso administrativo ao cluster
- ArgoCD instalado

## Passo 1

Renomear:

- Cluster
- Context
- User

Utilizar sempre o mesmo identificador.

Exemplo:

lab-server145

## Passo 2

Salvar em

~/.kube/clusters/

## Passo 3

Fazer merge

...

## Passo 4

Validar

kubectl config get-contexts

## Passo 5

Registrar

argocd cluster add ...

## Resultado esperado

argocd cluster list