{{/*
==============================================================================
Enterprise Microservice Platform (EMP)

Reusable helper functions shared across all chart templates.

Design Principles

- Single Source of Truth
- Composition over Duplication
- Kubernetes Native
- GitOps Friendly
- Enterprise Readability

------------------------------------------------------------------------------
Platform Engineering Team
------------------------------------------------------------------------------
*/}}

{{/*
==============================================================================
NAME HELPERS
==============================================================================

Return the logical application name.

Priority

1. Values.nameOverride
2. Chart.Name
*/}}
{{- define "microservice.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
==============================================================================
FULLNAME HELPERS
==============================================================================

Return the Kubernetes object name.

Priority

1. Values.fullnameOverride
2. include "microservice.name"

EMP intentionally does not prepend Release.Name because
Argo CD Applications already provide workload uniqueness.
*/}}
{{- define "microservice.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- include "microservice.name" . }}
{{- end }}
{{- end }}

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
{{- end }}

{{/*
==============================================================================
CHART HELPERS
==============================================================================

Return chart name and version.

Replace '+' because Kubernetes labels do not allow it.
*/}}
{{- define "microservice.chart" -}}
{{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
==============================================================================
SELECTOR LABEL HELPERS
==============================================================================

Minimal immutable labels used by selectors.
*/}}
{{- define "microservice.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice.name" . }}
app.kubernetes.io/instance: {{ include "microservice.fullname" . }}
{{- end }}

{{/*
==============================================================================
LABEL HELPERS
==============================================================================

Standard labels shared by all resources.
*/}}
{{- define "microservice.labels" -}}
helm.sh/chart: {{ include "microservice.chart" . }}
{{ include "microservice.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
==============================================================================
IMAGE HELPERS
==============================================================================

Return the fully-qualified container image.

Future roadmap

- Registry override
- Image digest
- Mirror support
*/}}
{{- define "microservice.image" -}}
{{- printf "%s:%s" .Values.deployment.container.image.repository .Values.deployment.container.image.tag -}}
{{- end }}

{{/*
==============================================================================
SERVICE ACCOUNT HELPERS
==============================================================================

Return the ServiceAccount name.

If create=true

- fullname

Otherwise

- existing ServiceAccount
- default
*/}}
{{- define "microservice.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "microservice.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
==============================================================================
COMMON LABELS
==============================================================================

Reserved for organization-wide labels.
*/}}

{{- define "microservice.commonLabels" -}}
{{- end }}
