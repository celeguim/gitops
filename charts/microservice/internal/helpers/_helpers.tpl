{{/*
==============================================================================
Enterprise Microservice Helm Chart

This file centralizes reusable helper functions shared by all templates.

Design Principles

- Follow Helm conventions whenever possible.
- Keep helpers small and focused.
- Prefer composition over duplication.
- Maintain a single source of truth.
- Optimize readability over cleverness.
- The chart is generic; applications own configuration.

------------------------------------------------------------------------------
Platform Engineering Team
------------------------------------------------------------------------------
*/}}

{{/*
==============================================================================
NAMESPACE HELPERS
==============================================================================

Return the target namespace.

Priority

1. Values.namespaceOverride
2. Release.Namespace
*/}}
{{- define "microservice.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}


{{/*
==============================================================================
NAME HELPERS
==============================================================================

Return the logical application name.

Priority

1. Values.nameOverride
2. Chart.Name

The result is truncated to 63 characters to comply with RFC1123.
*/}}
{{- define "microservice.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
==============================================================================
FULLNAME HELPERS
==============================================================================

Return the Kubernetes object name.

Priority

1. Values.fullnameOverride
2. include "microservice.name"

Unlike many public Helm charts, we intentionally do not prepend the Helm
Release name because Argo CD Applications already identify the workload.
*/}}
{{- define "microservice.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "microservice.name" . -}}
{{- end -}}
{{- end -}}


{{/*
==============================================================================
CHART HELPERS
==============================================================================

Return chart name and version.

The '+' character is replaced because Kubernetes labels do not allow it.
*/}}
{{- define "microservice.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
==============================================================================
SELECTOR LABEL HELPERS
==============================================================================

Selector labels are intentionally minimal.

They are shared by:

- Deployment.spec.selector.matchLabels
- Pod labels
- Service selectors

IMPORTANT

Selectors are immutable after creation.
Avoid adding labels that may change over time.
*/}}
{{- define "microservice.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice.name" . }}
app.kubernetes.io/instance: {{ include "microservice.fullname" . }}
{{- end -}}


{{/*
==============================================================================
LABEL HELPERS
==============================================================================

Standard Kubernetes labels.

This helper extends selectorLabels instead of duplicating logic.
*/}}
{{- define "microservice.labels" -}}
helm.sh/chart: {{ include "microservice.chart" . }}
{{ include "microservice.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}


{{/*
==============================================================================
SERVICE ACCOUNT HELPERS
==============================================================================

Return the ServiceAccount name.

When serviceAccount.create=true

- use fullname by default

Otherwise

- use the existing ServiceAccount
- fallback to "default"
*/}}
{{- define "microservice.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "microservice.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}


{{/*
==============================================================================
IMAGE HELPERS
==============================================================================

Return the fully qualified container image.

Priority

1. repository:tag

Future versions may support:

- image digest
- registry override
- mirrors
==============================================================================*/}}

{{- define "microservice.image" -}}

{{- printf "%s:%s" .Values.deployment.container.image.repository .Values.deployment.container.image.tag -}}

{{- end -}}

