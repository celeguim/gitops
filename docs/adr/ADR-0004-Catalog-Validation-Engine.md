# ADR-0004 --- Catalog Validation Engine

**Status:** Accepted\
**Date:** 2026-07-24\
**Authors:** Luiz Celeghin

## Context

ADR-0001 established the EMP architecture.

ADR-0002 defined the catalog model.

ADR-0003 defined the rendering pipeline.

This ADR specifies the validation engine executed by
`emp catalog validate`.

------------------------------------------------------------------------

# Decision

Validation is an independent pipeline executed before rendering.

Its purpose is to detect structural, semantic and policy issues as early
as possible.

Validation never modifies catalogs.

------------------------------------------------------------------------

# Validation Pipeline

    Load Catalogs
          │
          ▼
    Schema Validation
          │
          ▼
    Reference Validation
          │
          ▼
    Semantic Validation
          │
          ▼
    Policy Validation
          │
          ▼
    Validation Report

------------------------------------------------------------------------

# Validation Categories

## 1. Schema Validation

Checks:

-   apiVersion
-   kind
-   required fields
-   field types
-   duplicate object names

Example:

    ERROR
    Application "billing" is missing field "chart".

------------------------------------------------------------------------

## 2. Reference Validation

Checks relationships between catalogs.

Examples:

-   Cluster references an existing Environment.
-   Application valuesFile exists.
-   Charts exist.

Example:

    ERROR
    Cluster "eks-uat-01" references unknown Environment "uat2".

------------------------------------------------------------------------

## 3. Semantic Validation

Checks whether the model is logically consistent.

Examples:

-   duplicate release names
-   duplicate cluster names
-   duplicate application names
-   conflicting namespaces

------------------------------------------------------------------------

## 4. Policy Validation

Evaluates platform governance rules.

Examples:

-   naming conventions
-   mandatory labels
-   reserved environments
-   forbidden target revisions
-   platform compliance rules

Policies are extensible and may evolve independently from catalog
schemas.

------------------------------------------------------------------------

# Severity Levels

The validation engine produces three levels:

## Error

Rendering must stop.

## Warning

Rendering may continue.

## Info

Informational recommendations.

Example:

    ERROR
    Environment "prd" not found.

    WARNING
    Environment "dev" is defined but never used.

    INFO
    Application "billing" uses default namespace.

------------------------------------------------------------------------

# CLI Behaviour

    emp catalog validate

Expected output:

    ✓ 12 Applications
    ✓ 4 Environments
    ✓ 8 Clusters

    Errors:   0
    Warnings: 2
    Info:     5

Exit codes:

  Code   Meaning
  ------ ---------------------------
  0      Validation successful
  1      Validation failed
  2      Internal validation error

------------------------------------------------------------------------

# Validation Principles

1.  Validate before rendering.
2.  Fail fast on structural errors.
3.  Continue collecting warnings whenever possible.
4.  Validation must be deterministic.
5.  Validation must never modify source catalogs.

------------------------------------------------------------------------

# Extensibility

Future validators may include:

-   custom plugins
-   security policies
-   Kubernetes best practices
-   Helm chart validation
-   organization-specific rules

Validators should be composable without changing the core engine.

------------------------------------------------------------------------

# Summary

The Catalog Validation Engine ensures that authoring catalogs are
structurally correct, internally consistent and compliant with platform
policies before they enter the rendering pipeline.

Validation is the first quality gate of the EMP platform.
