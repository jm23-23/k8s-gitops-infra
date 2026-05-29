#!/usr/bin/env bash
# One-shot bootstrap for a fresh Docker Desktop Kubernetes cluster.
# Installs ArgoCD via Helm, then applies the App-of-Apps root.
# ArgoCD then self-manages via bootstrap/argocd.yaml.

set -euo pipefail

ARGOCD_NAMESPACE="argocd"
ARGOCD_CHART_VERSION="9.5.16"
ARGOCD_HELM_REPO="https://argoproj.github.io/argo-helm"

for cmd in kubectl helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: '$cmd' not found in PATH" >&2
    exit 1
  fi
done

echo ">> Adding argo helm repo"
helm repo add argo "$ARGOCD_HELM_REPO" >/dev/null
helm repo update argo >/dev/null

echo ">> Installing ArgoCD (chart $ARGOCD_CHART_VERSION) into namespace $ARGOCD_NAMESPACE"
helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NAMESPACE" \
  --create-namespace \
  --version "$ARGOCD_CHART_VERSION" \
  --wait

echo ">> Waiting for argocd-server to be Available"
kubectl wait --for=condition=Available --timeout=300s \
  deployment/argocd-server -n "$ARGOCD_NAMESPACE"

echo ">> Applying root App-of-Apps bootstrap.yaml"
kubectl apply -f "$(dirname "$0")/bootstrap.yaml"

echo
echo "Done. Initial admin password:"
kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
echo "Port-forward UI:  kubectl -n $ARGOCD_NAMESPACE port-forward svc/argocd-server 8080:443"
