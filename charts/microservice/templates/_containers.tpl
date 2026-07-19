{{/*
Container definition.
Receives:
  root
  container
*/}}

{{- define "microservice.container" }}

- name: app
  image: {{ include "microservice.image" .container.image | quote }}
  imagePullPolicy: {{ .container.image.pullPolicy }}

  ports:
{{ include "microservice.ports" .container.ports | nindent 4 }}

  resources:
{{ include "microservice.resources" .container.resources | nindent 4 }}

{{ include "microservice.httpProbe" (dict
  "type" "readinessProbe"
  "probe" .container.probes.readiness
) | nindent 2 }}

{{ include "microservice.httpProbe" (dict
  "type" "livenessProbe"
  "probe" .container.probes.liveness
) | nindent 2 }}

{{- end }}
