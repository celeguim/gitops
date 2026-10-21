# Enterprise Microservice Platform (EMP)

## Architecture

Version: 1.0-alpha

---

# Overview

The Enterprise Microservice Platform (EMP) is a GitOps platform for deploying Kubernetes workloads using:

- Helm
- Argo CD
- ApplicationSets
- Git as the single source of truth

EMP is **not only a Helm Chart**.

It is an opinionated deployment platform that provides:

- reusable Helm components
- GitOps workflow
- promotion between environments
- Kubernetes-native configuration
- multi-cluster support

---

# Design Principles

## Kubernetes Native

Whenever possible, EMP adopts the Kubernetes API directly.

The public API (`values.yaml`) should closely resemble the Kubernetes resource specification.

Example:

```yaml
hpa:
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
```

instead of creating custom abstractions.

---

## Helm Minimal

Helm templates should contain the minimum logic necessary.

Templates should primarily:

- compose resources
- reuse common snippets
- avoid business logic

---

## API First

The `values.yaml` is the public API of the platform.

Changing this API should be considered a breaking change.

Internal helper templates may change freely.

---

## GitOps First

Git is the only source of truth.

No manual kubectl changes are expected in production.

All infrastructure changes must originate from Git.

---

## Composability

Large templates should be composed from reusable helpers.

Example:

Deployment

```
deployment.yaml
    │
    ├── metadata.tpl
    ├── container.tpl
    │      ├── image.tpl
    │      ├── ports.tpl
    │      ├── probes.tpl
    │      └── resources.tpl
    └── selector.tpl
```

---

# Repository Structure

```
gitops/

├── charts/
│   └── microservice/
│
├── apps/
│
├── assignments/
│
├── clusters/
│
└── applicationsets/
```

---

# charts/

Contains reusable Helm Charts.

Example:

```
charts/
    microservice/
```

The chart is generic and environment agnostic.

---

# apps/

Contains the catalog of applications.

Applications are defined only once.

Example:

```
apps/

    customer-api.yaml
    payment-api.yaml
    jvminfo.yaml
```

Applications do not belong to any environment.

They simply describe:

- chart
- namespace
- values
- release name

---

# assignments/

Assignments define where an application should run.

Example:

```
assignments/

    uat/
        customer-api.yaml

    prd/
        customer-api.yaml
```

Assignments are responsible for binding:

Application

↓

Environment

↓

Cluster

The application definition itself is never duplicated.

---

# clusters/

Contains the inventory of Kubernetes clusters.

Example:

```
clusters/

    uat-cluster1.yaml

    uat-cluster2.yaml

    prd-cluster1.yaml
```

Each cluster contains labels used by ApplicationSets.

Example:

```yaml
labels:
  environment: uat
  region: sa-east-1
```

---

# ApplicationSets

ApplicationSets automatically generate Argo CD Applications.

They combine:

Application

+

Assignment

+

Cluster

↓

Argo CD Application

---

# Promotion Model

EMP promotes Git commits, not manifests.

Example workflow:

Developer

↓

commit

↓

branch: uat

↓

ArgoCD UAT

↓

Validation

↓

merge uat → prd

↓

ArgoCD PRD

No YAML changes are required during promotion.

Promotion is performed by Git.

---

# Branch Strategy

Current strategy:

```
uat
prd
```

Each branch represents the desired state of one environment.

Promotion occurs through Git merge.

```
uat
    │
    ▼
Validation
    │
    ▼
merge
    │
    ▼
prd
```

---

# Helper Philosophy

Helpers are divided into three categories.

## Shared Helpers

Reusable by all resources.

Examples:

- metadata.tpl
- labels.tpl
- selector.tpl

---

## Composite Helpers

Compose complex resources.

Example:

container.tpl

---

## Utility Helpers

Render Kubernetes API blocks.

Examples:

- ports.tpl
- probes.tpl
- resources.tpl
- hpa_metrics.tpl

These helpers usually contain little or no logic.

---

# Current MVP

Implemented resources:

- Deployment
- Service
- HorizontalPodAutoscaler

---

# Future Roadmap

Planned resources:

- Ingress
- NetworkPolicy
- ConfigMap
- Secret
- ServiceAccount (IRSA)
- PodDisruptionBudget
- ServiceMonitor
- PodMonitor
- Rollouts
- CronJob
- Job

---

# Non Goals

EMP does not intend to:

- abstract Kubernetes concepts
- replace Kubernetes APIs
- create a proprietary DSL
- hide Kubernetes behavior

The platform embraces Kubernetes instead of wrapping it.

---

# Vision

Enterprise Microservice Platform aims to become a reusable GitOps deployment platform where:

Git

↓

Application

↓

Assignment

↓

Cluster

↓

ApplicationSet

↓

Helm

↓

Kubernetes

This architecture allows multiple environments, multiple clusters, and controlled promotion pipelines while maintaining a single definition for each application.
