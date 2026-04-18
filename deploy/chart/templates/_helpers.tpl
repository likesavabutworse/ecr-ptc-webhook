{{/* Chart name truncated to DNS label length. */}}
{{- define "ecr-ptc-webhook.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Fully qualified release name. */}}
{{- define "ecr-ptc-webhook.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "ecr-ptc-webhook.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ecr-ptc-webhook.labels" -}}
helm.sh/chart: {{ include "ecr-ptc-webhook.chart" . }}
{{ include "ecr-ptc-webhook.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "ecr-ptc-webhook.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ecr-ptc-webhook.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "ecr-ptc-webhook.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "ecr-ptc-webhook.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* Secret name holding the serving certificate. */}}
{{- define "ecr-ptc-webhook.tlsSecretName" -}}
{{- if eq .Values.tls.mode "existingSecret" -}}
{{- required "tls.existingSecret.name is required when tls.mode=existingSecret" .Values.tls.existingSecret.name -}}
{{- else -}}
{{- printf "%s-tls" (include "ecr-ptc-webhook.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "ecr-ptc-webhook.selfSignedIssuerName" -}}
{{- printf "%s-selfsigned" (include "ecr-ptc-webhook.fullname" .) -}}
{{- end -}}

{{- define "ecr-ptc-webhook.certificateName" -}}
{{- printf "%s-cert" (include "ecr-ptc-webhook.fullname" .) -}}
{{- end -}}
