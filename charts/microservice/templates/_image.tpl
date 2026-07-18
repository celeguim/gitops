{{/*
Container image reference.
*/}}

{{- define "microservice.image" -}}
{{- printf "%s:%s" .repository .tag -}}
{{- end }}
