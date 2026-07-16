{{/*
==============================================================================
CONTAINER HELPERS
==============================================================================

Render the primary application container.

Input

root       -> Helm root context

container  -> Container configuration

==============================================================================*/}}

{{- define "microservice.container" -}}

{{- $root := .root -}}
{{- $container := .container -}}

- name: {{ include "microservice.name" $root }}

  image: {{ include "microservice.image" $root | quote }}

  imagePullPolicy: {{ $container.image.pullPolicy }}

{{- with $container.resources }}

  resources:
{{ toYaml . | nindent 4 }}

{{- end }}

{{- with $container.env }}

  env:
{{ toYaml . | nindent 4 }}

{{- end }}

{{- with $container.envFrom }}

  envFrom:
{{ toYaml . | nindent 4 }}

{{- end }}

{{ include "microservice.probes" (dict
    "root" $root
    "probes" $container.probes
) | nindent 2 }}

{{- end }}

