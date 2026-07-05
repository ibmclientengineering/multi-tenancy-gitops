#!/usr/bin/env bash
# One-command GitOps bootstrap for CP4I on OpenShift.
# Prereqs: oc logged in as cluster-admin; IBM_ENTITLEMENT_KEY exported (never committed).
#   export IBM_ENTITLEMENT_KEY=<key>
#   ./scripts/install.sh
set -euo pipefail
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
: "${IBM_ENTITLEMENT_KEY:?Set IBM_ENTITLEMENT_KEY (from myibm.ibm.com container library) and re-run}"
oc whoami >/dev/null || { echo "oc is not logged in"; exit 1; }

echo "==> 1/5 IBM Operator Catalog"
oc apply -f - <<'YAML'
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: IBM Operator Catalog
  image: icr.io/cpopen/ibm-operator-catalog:latest
  publisher: IBM
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 45m
YAML

echo "==> 2/5 OpenShift GitOps operator (skips if present)"
oc get csv -n openshift-operators 2>/dev/null | grep -q openshift-gitops-operator || oc apply -f - <<'YAML'
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  installPlanApproval: Automatic
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
YAML
echo "    waiting for the default Argo instance..."
for i in $(seq 1 30); do
  oc get argocd openshift-gitops -n openshift-gitops >/dev/null 2>&1 && break
  oc wait --for=condition=Established crd/argocds.argoproj.io --timeout=20s >/dev/null 2>&1 || true
done

echo "==> 3/5 Toolkit RBAC + Argo health checks (patch-in-place; safe on shared clusters)"
oc apply -f "${SCRIPTDIR}/../setup/ocp4x/custom-argocd-app-controller-clusterrole.yaml"
oc apply -f "${SCRIPTDIR}/../setup/ocp4x/custom-argocd-app-controller-clusterrolebinding.yaml"
if [ -f "${SCRIPTDIR}/../setup/ocp4x/argocd-healthchecks-patch.json" ]; then
  oc patch argocd openshift-gitops -n openshift-gitops --type=merge \
    --patch-file "${SCRIPTDIR}/../setup/ocp4x/argocd-healthchecks-patch.json"
fi

echo "==> 4/5 Entitlement key -> Secrets (tools, ibm-common-services)"
for ns in tools ibm-common-services; do
  oc get ns "$ns" >/dev/null 2>&1 || oc create ns "$ns"
  oc create secret docker-registry ibm-entitlement-key -n "$ns" \
    --docker-server=cp.icr.io --docker-username=cp \
    --docker-password="${IBM_ENTITLEMENT_KEY}" \
    --dry-run=client -o yaml | oc apply -f -
done

echo "==> 5/5 Bootstrap (Argo takes it from here)"
oc apply -f "${SCRIPTDIR}/../0-bootstrap/single-cluster/bootstrap.yaml"
echo
echo "Watch: oc get applications.argoproj.io -n openshift-gitops -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status"
echo "Platform UI appears as a Route in 'tools' when PlatformNavigator is Ready (~10-15 min)."
