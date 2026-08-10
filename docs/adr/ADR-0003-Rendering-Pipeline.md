# ADR-0003 --- Rendering Pipeline

**Status:** Accepted\
**Date:** 2026-07-24\
**Authors:** Luiz Celeghin

## Context

ADR-0001 introduced the EMP Rendering Architecture.

ADR-0002 defined the catalog schemas and reference model.

This ADR defines the rendering pipeline executed by
`emp catalog render`.

------------------------------------------------------------------------

# Decision

Rendering is a deterministic pipeline that transforms authoring catalogs
into deployment-ready catalogs.

The renderer is the only component responsible for transforming the
deployment model.

Deployment engines consume only rendered artifacts.

------------------------------------------------------------------------

# Rendering Pipeline

    Load Catalogs
          │
          ▼
    Validate Schemas
          │
          ▼
    Build Reference Index
          │
          ▼
    Resolve References
          │
          ▼
    Apply Defaults
          │
          ▼
    Apply Policies
          │
          ▼
    Generate Rendered Catalogs
          │
          ▼
    Emit Artifacts

Each stage has a single responsibility.

------------------------------------------------------------------------

# Pipeline Stages

## 1. Load Catalogs

Load all catalog definitions from:

    catalog/
    ├── applications/
    ├── environments/
    └── clusters/

No transformation occurs during this stage.

------------------------------------------------------------------------

## 2. Validate Schemas

Validate:

-   apiVersion
-   kind
-   required fields
-   field types
-   duplicate object names

Rendering MUST stop if validation fails.

------------------------------------------------------------------------

## 3. Build Reference Index

Create an in-memory index for fast reference resolution.

Example:

    Environment
    ───────────
    uat → environments/uat.yaml
    prd → environments/prd.yaml

------------------------------------------------------------------------

## 4. Resolve References

Resolve references between catalogs.

Example:

    cluster.environment
            │
            ▼
    environment.name

After this stage, no unresolved references remain.

------------------------------------------------------------------------

## 5. Apply Defaults

Apply platform defaults only when values are omitted.

Examples:

-   namespace
-   syncPolicy
-   retry policy
-   labels
-   annotations

Defaults must never overwrite explicitly defined values.

------------------------------------------------------------------------

## 6. Apply Policies

Evaluate platform policies before artifacts are generated.

Examples:

-   required labels
-   naming conventions
-   forbidden configurations
-   deployment restrictions

Policy violations stop rendering.

------------------------------------------------------------------------

## 7. Generate Rendered Catalogs

Produce deployment-ready catalogs.

Rendered catalogs contain:

-   no references
-   no inheritance
-   no unresolved defaults

They represent the complete deployment intent.

------------------------------------------------------------------------

## 8. Emit Artifacts

Write rendered artifacts to:

    .emp/render/

The output directory is ephemeral and must never be edited manually.

------------------------------------------------------------------------

# Deterministic Rendering

Given identical inputs, the renderer MUST always produce identical
outputs.

Rendering must be:

-   deterministic
-   idempotent
-   reproducible

------------------------------------------------------------------------

# Error Handling

Errors stop rendering immediately.

Warnings may be collected and displayed without preventing output.

Example:

    ERROR
    -----
    Environment "uat2" not found.

    WARNING
    -------
    Environment "dev" is defined but never referenced.

------------------------------------------------------------------------

# Future Extensions

The rendering pipeline is designed to support future stages such as:

-   overlay processing
-   variable interpolation
-   dependency graph generation
-   secret resolution
-   plugin execution
-   custom policy engines

These stages should be inserted without changing the overall pipeline
architecture.

------------------------------------------------------------------------

# Guiding Principles

1.  One stage, one responsibility.
2.  Rendering is deterministic.
3.  Rendering never mutates authoring catalogs.
4.  Only rendered artifacts are consumed by deployment engines.
5.  Every rendered artifact must be fully self-contained.

------------------------------------------------------------------------

# Summary

The rendering pipeline is the architectural boundary between the EMP
domain model and deployment execution.

It transforms independent platform catalogs into deterministic
deployment artifacts while enforcing validation, defaults and platform
policies.
