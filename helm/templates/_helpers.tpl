{{/*
Expand the name of the chart.
*/}}
{{- define "ssh-workspace.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ssh-workspace.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "ssh-workspace.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ssh-workspace.labels" -}}
helm.sh/chart: {{ include "ssh-workspace.chart" . }}
{{ include "ssh-workspace.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ssh-workspace.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ssh-workspace.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ssh-workspace.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ssh-workspace.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Get the primary SSH user from userManagement configuration
*/}}
{{- define "ssh-workspace.primaryUser" -}}
{{- if and .Values.userManagement.configMapBased.enabled .Values.userManagement.configMapBased.users }}
{{- index .Values.userManagement.configMapBased.users 0 | toYaml }}
{{- else }}
{{- dict "name" "developer" "uid" 1000 "gid" 1000 "home" "/home/developer" | toYaml }}
{{- end }}
{{- end }}

{{/*
Get the primary SSH username
*/}}
{{- define "ssh-workspace.primaryUsername" -}}
{{- $user := include "ssh-workspace.primaryUser" . | fromYaml }}
{{- $user.name }}
{{- end }}

{{/*
Get the primary SSH user UID
*/}}
{{- define "ssh-workspace.primaryUserUID" -}}
{{- $user := include "ssh-workspace.primaryUser" . | fromYaml }}
{{- $user.uid }}
{{- end }}

{{/*
Get the primary SSH user GID
*/}}
{{- define "ssh-workspace.primaryUserGID" -}}
{{- $user := include "ssh-workspace.primaryUser" . | fromYaml }}
{{- $user.gid }}
{{- end }}

{{/*
Get the primary SSH user home directory
*/}}
{{- define "ssh-workspace.primaryUserHome" -}}
{{- $user := include "ssh-workspace.primaryUser" . | fromYaml }}
{{- $user.home | default (printf "/home/%s" $user.name) }}
{{- end }}