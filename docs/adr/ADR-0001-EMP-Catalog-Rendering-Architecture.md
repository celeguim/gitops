# ADR-0001 --- EMP Catalog Rendering Architecture

**Status:** Accepted\
**Date:** 2026-07-24\
**Authors:** Luiz Celeghin

## Context

The Enterprise Microservice Platform (EMP) provides a declarative model
for managing Kubernetes application deployments across multiple
environments and clusters.

  ------------------------------------------------------------------------
  Experiment                Architecture                  Result
  ------------------------- ----------------------------- ----------------
  Exp005                    Application × Cluster         PASS

  Exp006                    Application × Environment     PASS

  Exp007                    Application × Cluster         PASS
                            (Cluster enriched with        
                            Environment metadata)         
  ------------------------------------------------------------------------

During Exp006, an important limitation of the Argo CD Matrix Generator
was identified:

> A Matrix Generator supports only two generators.

## Problem Statement

The EMP domain naturally consists of three independent concepts:

    Application
    Environment
    Cluster

Coupling the EMP domain model directly to the ApplicationSet
implementation would make the platform architecture dependent on a
specific deployment engine limitation.

## Decision

EMP introduces a rendering pipeline between the authoring catalogs and
the deployment engine.

    Authoring Catalogs
            │
            ▼
    emp catalog validate
            │
            ▼
    emp catalog render
            │
            ▼
    Rendered Catalogs
            │
            ▼
    Argo CD ApplicationSet
            │
            ▼
    Kubernetes

**EMP models the deployment domain. Argo CD executes the deployment.**

## Authoring Catalogs

    catalog/
    ├── applications/
    ├── environments/
    └── clusters/

Applications describe deployable software.

Environments describe deployment policies.

Clusters describe deployment targets and reference an Environment.

## Rendering

The rendering stage resolves references, validates schemas, applies
defaults and produces deployment-ready catalogs.

Example:

Input:

``` yaml
clusterName: eks-uat-01
server: https://...
environment: uat
```

Rendered:

``` yaml
clusterName: eks-uat-01
server: https://...
project: uat
targetRevision: uat
namespace: default
syncPolicy: automated
```

## Responsibilities

### EMP

-   Catalog validation
-   Schema validation
-   Reference resolution
-   Inheritance
-   Default values
-   Policy enforcement
-   Rendered catalog generation

### Argo CD

-   Application reconciliation
-   Synchronization
-   Kubernetes deployment

## Benefits

-   Clear separation between platform model and deployment engine.
-   Environment configuration defined once.
-   No duplicated metadata across clusters.
-   Simple ApplicationSets.
-   Future deployment engines can reuse rendered catalogs.
-   Clean separation between authoring and runtime artifacts.

## CLI Evolution

``` bash
emp catalog validate
emp catalog render
emp catalog diff
emp catalog graph

emp apps
emp projects
emp repos
emp doctor
```

## Guiding Principles

1.  Argo CD never consumes authoring catalogs directly.
2.  Argo CD consumes only catalogs rendered by EMP.
3.  Authoring catalogs represent business intent.
4.  Rendered catalogs represent deployment intent.
5.  EMP owns the deployment model; Argo CD owns deployment execution.

## Summary

The EMP platform introduces a rendering stage that decouples the
deployment domain from the deployment engine while preserving
independent Application, Environment and Cluster catalogs.
