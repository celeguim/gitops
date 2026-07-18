{{/*
Render a HTTP probe.
Arguments:
- type: readinessProbe | livenessProbe | startupProbe
- probe: probe configuration
*/}}

{{- define "microservice.httpProbe" -}}
{{- $type := .type -}}
{{- $probe := .probe -}}

{{- if $probe.enabled }}
{{ $type }}:
  httpGet:
    path: {{ $probe.path }}
    port: {{ $probe.port }}
  initialDelaySeconds: {{ default 0 $probe.initialDelaySeconds }}
  periodSeconds: {{ default 10 $probe.periodSeconds }}
  timeoutSeconds: {{ default 1 $probe.timeoutSeconds }}
  successThreshold: {{ default 1 $probe.successThreshold }}
  failureThreshold: {{ default 3 $probe.failureThreshold }}
{{- end }}

{{- end }}
