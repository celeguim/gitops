# Enterprise Microservice Platform (EMP)

                              Git Repository
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
      argocd/                    charts/                    apps/
          │                          │                          │
     Root Apps              Enterprise Chart            Application Config
          │                          │                          │
          └───────────────┬──────────┴──────────┬───────────────┘
                          │                     │
                     ApplicationSet       Kustomize + Helm
                          │                     │
                          └──────────────┬──────┘
                                         │
                                      Argo CD
                                         │
                                   Kubernetes
                                   
## Overview

The Enterprise Microservice Platform (EMP) is a GitOps platform designed to
standardize Kubernetes application deployments across multiple environments and
multiple clusters.

EMP combines:

- Argo CD
- Helm
- Kustomize

to provide a scalable, reusable and secure deployment model.

---

## Architecture

EMP follows a Hub-and-Spoke architecture.

Each environment owns its own Argo CD instance.

Example

Production

ArgoCD(PRD)

↓

Cluster1

Cluster2

Cluster3

...

User Acceptance Test

ArgoCD(UAT)

↓

Cluster1

Cluster2

...

---

## Design Principles

Platform First

GitOps First

Convention over Configuration

Single Source of Truth

Stable API

Kubernetes Native

Readability First

---

## Repository Structure

argocd/

charts/

apps/

clusters/

docs/

---

## Roadmap

v3.0

Enterprise Chart

v3.1

Monitoring

v3.2

Security

v3.3

Progressive Delivery

v4.0

Enterprise Platform
