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
{{- with .Values.labels }}
{{ toYaml . }}
{{- end }}
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
Security Context based on security level
*/}}
{{- define "ssh-workspace.securityContext" -}}
{{- if eq .Values.security.level "basic" }}
runAsNonRoot: false
{{- else }}
runAsNonRoot: false
readOnlyRootFilesystem: true
{{- if not .Values.user.sudo }}
allowPrivilegeEscalation: false
{{- end }}
capabilities:
  drop:
    - ALL
  add:
    - SETUID
    - SETGID
    - CHOWN
    - DAC_OVERRIDE
    - SYS_CHROOT
{{- if .Values.user.sudo }}
    - SETPCAP
    - SYS_ADMIN
{{- end }}
{{- if eq .Values.security.level "high" }}
seccompProfile:
  type: RuntimeDefault
{{- end }}
{{- end }}
{{- with .Values.security.securityContext }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Pod Security Context
*/}}
{{- define "ssh-workspace.podSecurityContext" -}}
{{- if ne .Values.security.level "basic" }}
fsGroup: {{ .Values.user.gid | default 1000 }}
{{- end }}
{{- with .Values.security.podSecurityContext }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Validate required values
*/}}
{{- define "ssh-workspace.validateValues" -}}
{{- if not .Values.user.name }}
{{- fail "user.name is required" }}
{{- end }}
{{- if not .Values.ssh.publicKeys }}
{{- fail "ssh.publicKeys is required and must contain at least one public key" }}
{{- end }}
{{- end }}

{{/*
Image name
*/}}
{{- define "ssh-workspace.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}