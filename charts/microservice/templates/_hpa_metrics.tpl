{{/*
HPA metrics.
Receives:
  hpa.metrics
*/}}
{{- define "microservice.hpaMetrics" -}}
{{ toYaml . }}
{{- end }}
