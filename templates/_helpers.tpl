{{/*
The project's system namespace.
*/}}
{{- define "cnp-project-base.systemNamespace" -}}
{{ .Values.projectName }}-system
{{- end }}

{{/*
Uniform markers, per D-13. "Find everything belonging to project X" has to be a
query, not guesswork — a cleanup job that guesses is a cleanup job that deletes
the wrong thing.
*/}}
{{- define "cnp-project-base.labels" -}}
cnp.3istor.com/project: {{ .Values.projectName | quote }}
cnp.3istor.com/cloud: {{ .Values.targetCloud | quote }}
{{- end }}

{{/*
Where this project's HTTPRoutes attach.

Defaults to the shared gateway, which is where every existing project attaches
today. A project with features.gateway enabled attaches to its own Gateway in
its own system namespace instead (D-05).
*/}}
{{- define "cnp-project-base.gatewayRef" -}}
{{- if .Values.features.gateway -}}
- name: {{ .Values.projectName }}-gateway
  namespace: {{ include "cnp-project-base.systemNamespace" . }}
{{- else -}}
- name: {{ .Values.gateway.shared.name }}
  namespace: {{ .Values.gateway.shared.namespace }}
{{- end -}}
{{- end }}
