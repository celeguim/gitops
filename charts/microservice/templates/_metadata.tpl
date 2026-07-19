{{/*
Standard metadata.
*/}}

{{- define "microservice.metadata" -}}
name: {{ .Release.Name }}
labels:
{{ include "microservice.labels" . | nindent 2 }}

{{- with .Values.commonAnnotations }}
annotations:
{{ toYaml . | nindent 2 }}
{{- end }}

{{- end }}
