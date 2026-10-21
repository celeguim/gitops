{{/*
Container resources.
Receives:
  . = deployment.container.resources
*/}}

{{- define "microservice.resources" -}}
{{- with . }}
{{- toYaml . }}
{{- end }}
{{- end }}
