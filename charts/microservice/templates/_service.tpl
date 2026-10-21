{{/*
Service ports.
Receives:
  service.ports
*/}}
{{- define "microservice.servicePorts" -}}
{{- range . }}
- name: {{ .name }}
  port: {{ .port }}
  targetPort: {{ .targetPort }}
  protocol: {{ default "TCP" .protocol }}
{{- end }}
{{- end }}
