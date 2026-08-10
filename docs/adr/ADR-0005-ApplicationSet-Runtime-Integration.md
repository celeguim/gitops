# ADR-0005 --- ApplicationSet Runtime Integration

**Status:** Accepted\
**Date:** 2026-07-24\
**Authors:** Luiz Celeghin

## Context

ADR-0001 through ADR-0004 define the EMP architecture, catalog model,
rendering pipeline and validation engine.

This ADR defines how EMP integrates with Argo CD while preserving a
strict separation between authoring and runtime artifacts.

------------------------------------------------------------------------

# Decision

Argo CD is the deployment runtime.

EMP is responsible for producing deployment-ready catalogs.

Argo CD MUST consume only rendered artifacts.

------------------------------------------------------------------------

# Runtime Architecture

    Authoring Catalogs
            │
            ▼
    emp catalog validate
            │
            ▼
    emp catalog render
            │
            ▼
    .emp/render/
            │
            ▼
    ApplicationSet
            │
            ▼
    Argo CD
            │
            ▼
    Kubernetes

------------------------------------------------------------------------

# Runtime Responsibilities

## EMP

-   Validate authoring catalogs
-   Resolve references
-   Apply defaults
-   Apply platform policies
-   Generate rendered catalogs

## Argo CD

-   Watch rendered catalogs
-   Generate Applications
-   Reconcile desired state
-   Synchronize Kubernetes resources
-   Report deployment status

EMP never performs reconciliation.

Argo CD never resolves catalog references.

------------------------------------------------------------------------

# Rendered Artifacts

The render output is written to:

    .emp/render/

Properties:

-   Generated only by EMP
-   Ephemeral
-   Never edited manually
-   Safe to regenerate at any time

------------------------------------------------------------------------

# ApplicationSet

ApplicationSets operate exclusively on rendered catalogs.

    Applications
            ×
    Clusters

No ApplicationSet should reference authoring catalogs directly.

------------------------------------------------------------------------

# Deployment Workflow

    Developer
        │
        ▼
    Edit Catalogs
        │
        ▼
    emp catalog validate
        │
        ▼
    emp catalog render
        │
        ▼
    Git Commit
        │
        ▼
    Argo CD detects changes
        │
        ▼
    Application reconciliation

------------------------------------------------------------------------

# Drift Prevention

Authoring catalogs are the single source of truth.

Rendered catalogs are disposable artifacts.

If drift occurs, rendered artifacts are regenerated rather than manually
corrected.

------------------------------------------------------------------------

# Runtime Principles

1.  Authoring catalogs are immutable inputs.
2.  Rendered catalogs are immutable outputs.
3.  ApplicationSets never consume authoring catalogs.
4.  EMP owns model transformation.
5.  Argo CD owns reconciliation.

------------------------------------------------------------------------

# Future Evolution

The runtime model allows future support for:

-   FluxCD
-   Helm-based deployments
-   GitOps Engines
-   Multi-runtime execution
-   Runtime-specific renderers

No changes to the authoring catalogs should be required.

------------------------------------------------------------------------

# Summary

EMP defines the deployment model and produces deterministic runtime
artifacts.

Argo CD consumes those artifacts to reconcile Kubernetes resources.

This separation allows the EMP platform to evolve independently from the
deployment runtime while maintaining a stable authoring experience.

> **EMP defines the intent. Argo CD delivers the intent.**
