#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-local-cicd}"

k3d cluster create "${CLUSTER_NAME}" \
  --servers 1 \
  --agents 2 \
  --port "8080:30080@server:0" \
  --port "8443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:*"

kubectl config use-context "k3d-${CLUSTER_NAME}"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl -n argocd rollout status deployment/argocd-server --timeout=300s

echo "ArgoCD admin initial password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo

echo "Run this in another terminal to open ArgoCD locally:"
echo "kubectl -n argocd port-forward svc/argocd-server 8081:443"
echo "After syncing the app, call the API at: http://localhost:8080/api/version"
