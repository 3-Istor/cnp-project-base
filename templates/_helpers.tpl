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
Baseline is enforced: it blocks host access and privileged pods, which would
make a project namespace a way onto the node. Restricted is only audited and
warned until the platform's own images and infra-templates comply.
*/}}
{{- define "cnp-project-base.podSecurityLabels" -}}
pod-security.kubernetes.io/enforce: baseline
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
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

{{/*
Pod Security Standard "restricted", which Kyverno audits in every project
namespace. 65532 is the nonroot user the cloudflared and gatus-sidecar images
already ship with.
*/}}
{{- define "cnp-project-base.restrictedPodSecurityContext" -}}
runAsNonRoot: true
runAsUser: 65532
runAsGroup: 65532
fsGroup: 65532
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{- define "cnp-project-base.restrictedContainerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end }}
