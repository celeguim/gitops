{{/*
------------------------------------------------------------------------------
NAME HELPERS
------------------------------------------------------------------------------

Este helper retorna o nome lógico da aplicação.

Prioridade:

1. .Values.nameOverride
2. .Chart.Name

O resultado é truncado para 63 caracteres conforme RFC1123.

Exemplos:

Chart.Name = microservice
nameOverride = ""

=> microservice

Chart.Name = microservice
nameOverride = app1

=> app1

------------------------------------------------------------------------------*/}}

{{- define "microservice.name" -}}

{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}

{{- end -}}
