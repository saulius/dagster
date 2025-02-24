{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "dagster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dagster.fullname" -}}
{{- if .Values.global.fullnameOverride -}}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.global.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

# Image utils
{{- define "image.name" }}
{{- .repository -}}:{{- .tag -}}
{{- end }}

{{- define "dagster.dagit.dagitCommand" -}}
{{- $userDeployments := index .Values "dagster-user-deployments" }}
{{- if $userDeployments.enabled }}
dagit -h 0.0.0.0 -p 80 -w /dagster-workspace/workspace.yaml
{{- else -}}
dagit -h 0.0.0.0 -p 80
{{- end -}}
{{- end -}}

{{- define "dagster.dagit.fullname" -}}
{{- $name := default "dagit" .Values.dagit.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dagster.dagit.migrate" -}}
{{- $name := default "dagit" .Values.dagit.nameOverride -}}
{{- printf "%s-%s-instance-migrate" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dagster.workers.fullname" -}}
{{- $celeryK8sRunLauncherConfig := .Values.runLauncher.config.celeryK8sRunLauncher }}
{{- $name := $celeryK8sRunLauncherConfig.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dagster.flower.fullname" -}}
{{- $name := default "flower" .Values.flower.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "dagster.rabbitmq.fullname" -}}
{{- $name := default "rabbitmq" .Values.rabbitmq.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified postgresql name or use the `postgresqlHost` value if defined.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "dagster.postgresql.fullname" -}}
{{- if .Values.postgresql.postgresqlHost }}
    {{- .Values.postgresql.postgresqlHost -}}
{{- else }}
    {{- $name := default "postgresql" .Values.postgresql.nameOverride -}}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "dagster.postgresql.pgisready" -}}
until pg_isready -h {{ include "dagster.postgresql.host" . }} -p {{ .Values.postgresql.service.port }} -U {{ .Values.postgresql.postgresqlUsername }}; do echo waiting for database; sleep 2; done;
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "dagster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "dagster.labels" -}}
helm.sh/chart: {{ include "dagster.chart" . }}
{{ include "dagster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "dagster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "dagster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "dagster.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "dagster.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Set postgres host
See: https://github.com/helm/charts/blob/61c2cc0db49b06b948f90c8e44e9143d7bab430d/stable/sentry/templates/_helpers.tpl#L59-L68
*/}}
{{- define "dagster.postgresql.host" -}}
{{- if .Values.postgresql.enabled -}}
{{- template "dagster.postgresql.fullname" . -}}
{{- else -}}
{{- .Values.postgresql.postgresqlHost | quote -}}
{{- end -}}
{{- end -}}

{{- define "dagster.postgresql.secretName" -}}
{{- if .Values.global.postgresqlSecretName }}
{{- .Values.global.postgresqlSecretName }}
{{- else }}
{{- printf "%s-postgresql-secret" (include "dagster.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Celery options
*/}}
{{- define "dagster.celery.broker_url" -}}
{{- if .Values.rabbitmq.enabled -}}
pyamqp://{{ .Values.rabbitmq.rabbitmq.username }}:{{ .Values.rabbitmq.rabbitmq.password }}@{{ include "dagster.rabbitmq.fullname" . }}:{{ .Values.rabbitmq.service.port }}//
{{- else if .Values.redis.enabled -}}
redis://{{ .Values.redis.host }}:{{ .Values.redis.port }}/{{ .Values.redis.brokerDbNumber | default 0}}
{{- end -}}
{{- end -}}

{{- define "dagster.celery.backend_url" -}}
{{- if .Values.rabbitmq.enabled -}}
rpc://
{{- else if .Values.redis.enabled -}}
redis://{{ .Values.redis.host }}:{{ .Values.redis.port }}/{{ .Values.redis.backendDbNumber | default 0}}
{{- end -}}
{{- end -}}

{{/*
This environment shared across all containers.

This includes Dagit, Celery Workers, Run Master, and Step Execution containers.
*/}}
{{- define "dagster.shared_env" -}}
DAGSTER_HOME: {{ .Values.global.dagsterHome | quote }}
DAGSTER_K8S_CELERY_BROKER: "{{ template "dagster.celery.broker_url" . }}"
DAGSTER_K8S_CELERY_BACKEND: "{{ template "dagster.celery.backend_url" . }}"
DAGSTER_K8S_PG_PASSWORD_SECRET: {{ include "dagster.postgresql.secretName" . | quote }}
DAGSTER_K8S_INSTANCE_CONFIG_MAP: "{{ template "dagster.fullname" .}}-instance"
DAGSTER_K8S_PIPELINE_RUN_NAMESPACE: "{{ .Release.Namespace }}"
DAGSTER_K8S_PIPELINE_RUN_ENV_CONFIGMAP: "{{ template "dagster.fullname" . }}-pipeline-env"
DAGSTER_K8S_PIPELINE_RUN_IMAGE: "{{- .Values.pipelineRun.image.repository -}}:{{- .Values.pipelineRun.image.tag -}}"
DAGSTER_K8S_PIPELINE_RUN_IMAGE_PULL_POLICY: "{{ .Values.pipelineRun.image.pullPolicy }}"
{{- end -}}
