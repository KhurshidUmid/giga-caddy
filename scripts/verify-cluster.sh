#!/bin/bash
# scripts/verify-cluster.sh - Post-deployment verification

set -euo pipefail

ENVIRONMENT="${1:-dev}"
CLUSTER_NAME="giga-caddy-${ENVIRONMENT}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "🔍 Verifying EKS cluster deployment..."

# Check cluster exists
if ! aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION > /dev/null 2>&1; then
    echo "❌ Cluster not found: $CLUSTER_NAME"
    exit 1
fi

echo "✓ Cluster found: $CLUSTER_NAME"

# Update kubeconfig
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Check nodes
NODES=$(kubectl get nodes --no-headers | wc -l)
if [ $NODES -lt 1 ]; then
    echo "⚠️  No nodes found in cluster"
    exit 1
fi
echo "✓ Nodes ready: $NODES"

# Check add-ons
echo ""
echo "📦 Checking add-ons..."

addons=("ingress-nginx" "cert-manager" "external-dns" "kube-system" "amazon-cloudwatch")
for addon_ns in "${addons[@]}"; do
    PODS=$(kubectl get pods -n "$addon_ns" --no-headers 2>/dev/null | wc -l)
    if [ $PODS -gt 0 ]; then
        echo "✓ $addon_ns: $PODS pods"
    fi
done

# Check certificates
echo ""
echo "🔐 Checking certificates..."
kubectl get clusterissuer
kubectl get certificate -A

# Deploy Caddy if not exists
echo ""
echo "🚀 Deploying Caddy..."

HELM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helm"

kubectl create namespace caddy-${ENVIRONMENT} --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install caddy $HELM_DIR/caddy \
    --namespace caddy-${ENVIRONMENT} \
    --values $HELM_DIR/caddy/values.yaml \
    --values $HELM_DIR/caddy/values-${ENVIRONMENT}.yaml \
    --timeout 5m \
    --wait \
    --atomic

echo "✓ Caddy deployed"

# Verify Caddy
echo ""
echo "✅ Deployment verification complete!"
echo ""
echo "Access your service:"
kubectl get ingress -n caddy-${ENVIRONMENT}
kubectl get svc -n ingress-nginx

echo ""
echo "Test access (wait 30 seconds for DNS):"
DOMAIN=$(kubectl get ingress -n caddy-${ENVIRONMENT} -o jsonpath='{.items[0].spec.rules[0].host}')
echo "curl https://$DOMAIN"
