{{/*
Container ports.
Receives:
  . = deployment.container.ports
*/}}

{{- define "microservice.ports" -}}

- name: http
  containerPort: {{ .http.containerPort }}
  protocol: TCP

{{- with .management }}
- name: management
  containerPort: {{ .containerPort }}
  protocol: TCP
{{- end }}

{{- end }}
