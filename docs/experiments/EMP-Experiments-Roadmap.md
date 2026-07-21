# EMP Experiments Roadmap

## Methodology

Every experiment follows the same lifecycle:

``` text
Question
    ↓
Hypothesis
    ↓
Implementation
    ↓
Execution
    ↓
Results
    ↓
Analysis
    ↓
Conclusion
    ↓
Decision
```

Only one experiment should be active at a time.

------------------------------------------------------------------------

# Experiment 001 -- List Generator

**Question:** Can the List Generator create Applications from a static
list?

**Status:** ✅ Completed

**Key Learnings** - Basic ApplicationSet operation - Go Template
fundamentals - Variable mapping - Minimal ApplicationSet structure

------------------------------------------------------------------------

# Experiment 002 -- Git Directory Generator

**Question:** Can the Git Directory Generator discover applications from
the repository structure?

**Status:** ✅ Completed

**Key Learnings** - Automatic directory discovery - Use of `.path` -
Generator-provided variables - One Application per directory

------------------------------------------------------------------------

# Experiment 003 -- Git Files Generator

**Question:** Can the Git Files Generator create Applications from
declarative YAML files?

**Status:** ✅ Completed

**Key Learnings** - Declarative application catalog - Custom metadata -
Reserved variable collision (`path`) - Correct Go Template syntax
(`{{ .variable }}`)

------------------------------------------------------------------------

# Experiment 004 -- Combining Generators

**Question:** Can different generators be combined to enrich Application
definitions?

## Hypothesis

Combining generators allows separation of concerns while keeping the
platform declarative.

## Goals

-   Understand Matrix Generator behavior.
-   Combine two independent data sources.
-   Evaluate whether this approach simplifies multi-cluster and
    multi-environment deployments.
-   Identify limitations and trade-offs.

## Candidate Scenarios

-   Applications × Clusters
-   Files × Clusters
-   Git Directories × List

## Deliverables

-   Working ApplicationSet
-   Experiment report
-   Lessons learned
-   Architecture decision

------------------------------------------------------------------------

# Backlog

-   Experiment 005 -- Cluster Generator
-   Experiment 006 -- Multi Environment
-   Experiment 007 -- Application Metadata
-   Experiment 008 -- Application Catalog
-   Experiment 009 -- Promotion Strategy
-   Experiment 010 -- Platform Architecture
