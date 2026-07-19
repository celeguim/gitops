# Enterprise Microservice Platform (EMP)

> A Kubernetes-native GitOps platform for deploying microservices at scale using Helm and Argo CD.

---

## Overview

Enterprise Microservice Platform (EMP) is an opinionated GitOps platform designed to simplify the deployment and lifecycle management of Kubernetes workloads.

EMP combines:

- Helm
- Argo CD
- ApplicationSets
- GitOps
- Multi-cluster deployments

while keeping applications **environment agnostic**.

Applications are defined once and promoted through environments using Git.

---

# Why EMP?

Traditional GitOps repositories usually duplicate application definitions across environments:

apps/
├── dev/
├── uat/
└── prd/

EMP follows a different approach.

Applications are defined only once.

Environments only control deployment targets and promotion.

This reduces duplication, improves consistency, and enables true GitOps promotion workflows.

---

# Design Principles

- Kubernetes Native
- GitOps First
- Helm Minimal
- API First
- Environment Agnostic
- Multi-Cluster Ready

---

# Repository Layout

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

# Architecture

```text
                 Git Repository
                        │
        ┌───────────────┼────────────────┐
        │               │                │
        ▼               ▼                ▼

   Applications     Assignments      Clusters

        └───────────────┬────────────────┘
                        │
                        ▼

                 ApplicationSet

                        │
                        ▼

              Argo CD Applications

                        │
                        ▼

                  Helm Chart

                        │
                        ▼

                  Kubernetes
```

---

# Promotion Flow

Applications are defined once.

Environments decide **where** and **when** they are deployed.

```
Developer

↓

Commit

↓

branch: uat

↓

ArgoCD UAT

↓

Validation

↓

Merge

↓

branch: prd

↓

ArgoCD PRD
```

No deployment manifests are modified during promotion.

Git is the single source of truth.

---

# Repository Responsibilities

## charts/

Reusable Helm charts.

Responsible for **how** applications are deployed.

---

## apps/

Application catalog.

Responsible for **what** is deployed.

Applications are defined only once.

---

## assignments/

Deployment assignments.

Responsible for **where** an application runs.

---

## clusters/

Cluster inventory.

Responsible for **which** clusters exist.

---

## applicationsets/

Automatically generates Argo CD Applications.

---

# Current MVP

Implemented resources:

- Deployment
- Service
- HorizontalPodAutoscaler

---

# Roadmap

- Ingress
- NetworkPolicy
- ConfigMap
- Secret
- ServiceAccount (IRSA)
- PodDisruptionBudget
- ServiceMonitor
- PodMonitor
- Argo Rollouts
- CronJobs
- Jobs

---

# Vision

EMP treats Git as the deployment API.

```
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
```

The same application can be promoted across multiple environments without duplication.

Deploy once.

Promote with Git.
