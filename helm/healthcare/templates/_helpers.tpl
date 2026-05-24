{{/* Common labels for resources, expects a dict: { name: ..., root: $ } */}}
{{- define "healthcare.labels" -}}
app: {{ .name }}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: healthcare
{{- end -}}