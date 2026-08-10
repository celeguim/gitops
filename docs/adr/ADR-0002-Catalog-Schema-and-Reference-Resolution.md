# ADR-0002 --- Catalog Schema and Reference Resolution

**Status:** Accepted\
**Date:** 2026-07-24\
**Authors:** Luiz Celeghin

## Context

ADR-0001 introduced the concept of **Authoring Catalogs** and the **EMP
Rendering Pipeline**.

This ADR defines the structure of those catalogs and how references
between them are resolved during `emp catalog render`.

------------------------------------------------------------------------

## Decision

EMP defines three independent catalog types:

    Applications
    Environments
    Clusters

Each catalog has a single responsibility and may reference another
catalog, but never duplicates its data.

------------------------------------------------------------------------

# Applications

Applications describe deployable software only.

Example:

``` yaml
appName: billing

chart: charts/microservice

releaseName: billing

valuesFile: applications/billing/values.yaml
```

Applications MUST NOT define:

-   environment
-   cluster
-   project
-   targetRevision

------------------------------------------------------------------------

# Environments

Environments define deployment policy.

Example:

``` yaml
name: uat

project: uat

targetRevision: uat

namespace: default

syncPolicy: automated
```

Environments MUST NOT contain cluster-specific information.

------------------------------------------------------------------------

# Clusters

Clusters define deployment targets.

Example:

``` yaml
clusterName: eks-uat-01

server: https://...

environment: uat
```

Clusters reference an Environment but never duplicate its configuration.

------------------------------------------------------------------------

# Reference Resolution

The rendering pipeline resolves references in the following order:

    Applications
            │
            ▼
    Environments
            │
            ▼
    Clusters
            │
            ▼
    Rendered Catalogs

For every cluster:

1.  Load the referenced Environment.
2.  Validate that it exists.
3.  Merge environment attributes into the cluster.
4.  Produce a resolved deployment target.

Example:

Input:

``` yaml
clusterName: eks-uat-01
environment: uat
```

Environment:

``` yaml
name: uat
project: uat
targetRevision: uat
namespace: default
```

Rendered:

``` yaml
clusterName: eks-uat-01
server: https://...
project: uat
targetRevision: uat
namespace: default
```

------------------------------------------------------------------------

# Validation Rules

The renderer MUST fail when:

-   an Environment does not exist;
-   duplicate catalog names are found;
-   mandatory fields are missing;
-   invalid references are detected.

Warnings MAY be produced for:

-   unused environments;
-   unused applications;
-   deprecated schema versions.

------------------------------------------------------------------------

# Schema Evolution

Every catalog SHOULD support a schema version.

Example:

``` yaml
apiVersion: emp.io/v1alpha1
kind: Environment
```

This allows future evolution without breaking compatibility.

------------------------------------------------------------------------

# Guiding Principles

1.  Every catalog has one responsibility.
2.  References replace duplication.
3.  Rendering resolves references.
4.  Rendered catalogs contain no unresolved references.
5.  Deployment engines consume only rendered catalogs.

------------------------------------------------------------------------

# Summary

EMP catalogs describe the deployment domain using independent concepts.

The rendering pipeline transforms those catalogs into a fully resolved
deployment model suitable for execution by Argo CD or any future
deployment engine.
