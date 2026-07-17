{{/*
Common labels.
These labels are currently used by all resources.
*/}}

{{- define "microservice.labels" -}}
app: {{ .Release.Name }}
{{- end }}
