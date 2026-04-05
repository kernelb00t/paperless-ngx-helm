{{/*
Expand the name of the chart.
*/}}
{{- define "paperless-ngx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "paperless-ngx.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart label.
*/}}
{{- define "paperless-ngx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "paperless-ngx.labels" -}}
helm.sh/chart: {{ include "paperless-ngx.chart" . }}
{{ include "paperless-ngx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "paperless-ngx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "paperless-ngx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component selector labels (component-specific)
*/}}
{{- define "paperless-ngx.componentLabels" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
app.kubernetes.io/name: {{ include "paperless-ngx.name" $root }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "paperless-ngx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "paperless-ngx.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Paperless image tag – fallback to Chart.AppVersion
*/}}
{{- define "paperless-ngx.imageTag" -}}
{{- default .Chart.AppVersion .Values.paperless.image.tag }}
{{- end }}

{{/*
Name of the Paperless secret
*/}}
{{- define "paperless-ngx.secretName" -}}
{{- if .Values.paperless.existingSecret }}
{{- .Values.paperless.existingSecret }}
{{- else }}
{{- printf "%s-paperless" (include "paperless-ngx.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Full name of the CloudNativePG Cluster
*/}}
{{- define "paperless-ngx.postgresClusterName" -}}
{{- if .Values.cnpg.clusterName }}
{{- .Values.cnpg.clusterName }}
{{- else }}
{{- printf "%s-postgres" (include "paperless-ngx.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Service name for PostgreSQL (CNPG creates a service named <cluster>-rw for the primary)
*/}}
{{- define "paperless-ngx.postgresServiceName" -}}
{{- printf "%s-rw" (include "paperless-ngx.postgresClusterName" .) }}
{{- end }}

{{/*
Redis service name
*/}}
{{- define "paperless-ngx.redisServiceName" -}}
{{- printf "%s-redis" (include "paperless-ngx.fullname" .) }}
{{- end }}

{{/*
Gotenberg service name
*/}}
{{- define "paperless-ngx.gotenbergServiceName" -}}
{{- printf "%s-gotenberg" (include "paperless-ngx.fullname" .) }}
{{- end }}

{{/*
Tika service name
*/}}
{{- define "paperless-ngx.tikaServiceName" -}}
{{- printf "%s-tika" (include "paperless-ngx.fullname" .) }}
{{- end }}

{{/*
Image pull secrets as a list of imagePullSecrets
*/}}
{{- define "paperless-ngx.imagePullSecrets" -}}
{{- if .Values.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate required values – called from a top-level template to produce early errors.
*/}}
{{- define "paperless-ngx.validate" -}}
{{- if and (not .Values.paperless.existingSecret) (not .Values.paperless.secrets.PAPERLESS_SECRET_KEY) }}
{{- fail "paperless.secrets.PAPERLESS_SECRET_KEY must be set. Generate one with: openssl rand -hex 32" }}
{{- end }}
{{- if and (not .Values.paperless.existingSecret) (not .Values.paperless.secrets.PAPERLESS_ADMIN_PASSWORD) }}
{{- fail "paperless.secrets.PAPERLESS_ADMIN_PASSWORD must be set." }}
{{- end }}
{{- end }}
