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

{{/*
Postgres identifiers can't contain hyphens; project names can (D-01's registry
allows them). Used as both the per-project database name and its owning role
name on the shared cluster (WS-5).
*/}}
{{- define "cnp-project-base.keycloakDbName" -}}
kc_{{ .Values.projectName | replace "-" "_" }}
{{- end }}

{{/*
The dedicated per-project Keycloak's public issuer — pinned identically for
the browser and for Envoy's SecurityPolicy (R-3: never point either at a
.svc address, or token validation fails at the edge instead of at deploy).
*/}}
{{- define "cnp-project-base.keycloakIssuer" -}}
https://auth-{{ .Values.projectName }}.{{ .Values.domain }}
{{- end }}
