{{/*
Pod selector.
*/}}
{{- define "microservice.selector" -}}
app: {{ .Release.Name }}
{{- end }}
