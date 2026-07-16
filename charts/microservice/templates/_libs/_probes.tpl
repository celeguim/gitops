{{/*
==============================================================================
PROBE HELPERS
==============================================================================

Input

root

probes

==============================================================================*/}}

{{- define "microservice.probes" -}}

{{- $probes := .probes -}}

{{- if $probes.startup.enabled }}

startupProbe:

  httpGet:

    path: {{ $probes.startup.path }}

    port: {{ $probes.startup.port }}

  initialDelaySeconds: {{ $probes.startup.initialDelaySeconds }}
  periodSeconds: {{ $probes.startup.periodSeconds }}
  timeoutSeconds: {{ $probes.startup.timeoutSeconds }}
  successThreshold: {{ $probes.startup.successThreshold }}
  failureThreshold: {{ $probes.startup.failureThreshold }}

{{- end }}

{{- if $probes.readiness.enabled }}

readinessProbe:

  httpGet:

    path: {{ $probes.readiness.path }}

    port: {{ $probes.readiness.port }}

  initialDelaySeconds: {{ $probes.readiness.initialDelaySeconds }}
  periodSeconds: {{ $probes.readiness.periodSeconds }}
  timeoutSeconds: {{ $probes.readiness.timeoutSeconds }}
  successThreshold: {{ $probes.readiness.successThreshold }}
  failureThreshold: {{ $probes.readiness.failureThreshold }}

{{- end }}

{{- if $probes.liveness.enabled }}

livenessProbe:

  httpGet:

    path: {{ $probes.liveness.path }}

    port: {{ $probes.liveness.port }}

  initialDelaySeconds: {{ $probes.liveness.initialDelaySeconds }}
  periodSeconds: {{ $probes.liveness.periodSeconds }}
  timeoutSeconds: {{ $probes.liveness.timeoutSeconds }}
  successThreshold: {{ $probes.liveness.successThreshold }}
  failureThreshold: {{ $probes.liveness.failureThreshold }}

{{- end }}

{{- end }}

