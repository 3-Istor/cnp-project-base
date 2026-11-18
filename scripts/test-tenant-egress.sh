#!/usr/bin/env bash
# Replays the CNP-296 reachability checks from inside a tenant app namespace:
# one probe pod as a plain app, one labelled for the RGW. Exits non-zero when
# any destination answers differently from what the egress policy promises.
#
#   scripts/test-tenant-egress.sh <app-namespace> [same-project-url]
#
# Needs kubectl on the target cluster. Run it once with Cilium policy audit
# mode (expect every "blocked" line to fail) and once enforced.
set -euo pipefail

namespace=${1:?usage: $0 <app-namespace> [same-project-url]}
same_project_url=${2:-}

project=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.cnp\.3istor\.com/project}')
if [[ -z $project ]]; then
  echo "namespace $namespace has no cnp.3istor.com/project label: not a tenant namespace" >&2
  exit 2
fi

image=curlimages/curl:8.17.0
suffix=$RANDOM
plain_pod=egress-probe-$suffix
rgw_pod=egress-probe-rgw-$suffix

cleanup() {
  kubectl -n "$namespace" delete pod "$plain_pod" "$rgw_pod" --ignore-not-found --wait=false >/dev/null
}
trap cleanup EXIT

# Restricted pod security and requests: the namespace quota rejects pods without them.
start_probe() {
  local name=$1 rgw_label=$2
  kubectl -n "$namespace" run "$name" --image="$image" --restart=Never \
    --labels="cnp.3istor.com/egress-probe=true${rgw_label}" \
    --overrides='{
      "spec": {
        "securityContext": {"runAsNonRoot": true, "runAsUser": 65532, "seccompProfile": {"type": "RuntimeDefault"}},
        "containers": [{
          "name": "'"$name"'",
          "image": "'"$image"'",
          "command": ["sleep", "600"],
          "securityContext": {"allowPrivilegeEscalation": false, "readOnlyRootFilesystem": true, "capabilities": {"drop": ["ALL"]}},
          "resources": {"requests": {"cpu": "10m", "memory": "16Mi"}, "limits": {"memory": "16Mi"}}
        }]
      }
    }' >/dev/null
}

start_probe "$plain_pod" ""
start_probe "$rgw_pod" ",cnp.3istor.com/egress-rgw=true"
kubectl -n "$namespace" wait --for=condition=Ready "pod/$plain_pod" "pod/$rgw_pod" --timeout=120s >/dev/null

failures=0

# Any HTTP answer, even 4xx, means the connection went through.
check() {
  local pod=$1 expect=$2 url=$3
  local got=blocked
  if kubectl -n "$namespace" exec "$pod" -- curl -sk -o /dev/null --connect-timeout 5 --max-time 8 "$url" 2>/dev/null; then
    got=reachable
  fi
  if [[ $got == "$expect" ]]; then
    printf 'ok    %-9s %-17s %s\n' "$expect" "$pod" "$url"
  else
    printf 'FAIL  want %-9s got %-9s %-17s %s\n' "$expect" "$got" "$pod" "$url"
    failures=$((failures + 1))
  fi
}

check "$plain_pod" reachable "https://example.com"
check "$plain_pod" reachable "https://auth.3istor.com/realms/$project/.well-known/openid-configuration"
if [[ -n $same_project_url ]]; then
  check "$plain_pod" reachable "$same_project_url"
fi

check "$plain_pod" blocked "http://192.168.1.110:7480"
check "$plain_pod" blocked "http://192.168.1.110:5000/v3"
check "$plain_pod" blocked "https://kubernetes.default.svc"
check "$plain_pod" blocked "https://192.168.1.212:6443/version"
check "$plain_pod" blocked "http://vault.vault.svc.cluster.local:8200/v1/sys/health"
check "$plain_pod" blocked "http://keycloakx-http.keycloak.svc.cluster.local/"
check "$plain_pod" blocked "http://169.254.169.254/"

check "$rgw_pod" reachable "http://192.168.1.110:7480"
check "$rgw_pod" blocked "http://192.168.1.110:5000/v3"
check "$rgw_pod" blocked "https://kubernetes.default.svc"

if ((failures > 0)); then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
