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
Init Container Security Context - fixed settings for user/system setup
Design: Init Container requires write access to prepare configurations and user setup.
The prepared configuration will be mounted as read-only in the Main Container.
*/}}
{{- define "ssh-workspace.initSecurityContext" -}}
runAsNonRoot: false
readOnlyRootFilesystem: false  # Required for user creation and config preparation
allowPrivilegeEscalation: true  # Required for user/group management
capabilities:
  drop:
    - ALL
  add:
    - SETUID   # Required for useradd
    - SETGID   # Required for groupadd  
    - CHOWN    # Required for file ownership setup
    - DAC_OVERRIDE  # Required for file permission setup
    # SYS_CHROOT not needed for Init Container (user setup only)
{{- end }}

{{/*
Main Container Security Context based on security level and permission strategy
Design: SSH daemon requires root privileges, but permission management varies by strategy.
*/}}
{{- define "ssh-workspace.securityContext" -}}
{{- if eq .Values.security.level "basic" }}
runAsNonRoot: false
{{- else }}
runAsNonRoot: false  # SSH daemon must run as root
{{- if ne .Values.security.level "basic" }}
readOnlyRootFilesystem: true  # Enhanced security: no write access to root filesystem
{{- end }}
{{- if not .Values.user.sudo }}
allowPrivilegeEscalation: false  # Restricted when sudo not required
{{- end }}
capabilities:
  drop:
    - ALL
  add:
    - SETUID      # Required for SSH user switching
    - SETGID      # Required for SSH group switching
    - SYS_CHROOT  # Required for SSH privilege separation
{{- if eq .Values.security.permissionStrategy "explicit" }}
    - CHOWN       # Required for explicit permission management
    - DAC_OVERRIDE # Required for file ownership changes
{{- else }}
    - DAC_OVERRIDE # Required for SSH configuration access with fsGroup
{{- end }}
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
Supports two permission management strategies:
1. fsgroup: Uses Kubernetes fsGroup (SetGID bit behavior)
2. explicit: Manual UID/GID management (traditional Unix permissions)
*/}}
{{- define "ssh-workspace.podSecurityContext" -}}
{{- if eq .Values.security.permissionStrategy "explicit" }}
{{/* Explicit strategy: No fsGroup, rely on manual permission management */}}
runAsUser: 0  # SSH daemon requires root privileges
runAsGroup: 0
runAsNonRoot: false
{{- else }}
{{/* fsGroup strategy: Use Kubernetes fsGroup (default) */}}
fsGroup: {{ .Values.user.gid | default 1000 }}
fsGroupChangePolicy: "OnRootMismatch"
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