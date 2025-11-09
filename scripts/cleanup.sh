#!/bin/bash
# scripts/cleanup.sh - Destroy infrastructure

set -euo pipefail

ENVIRONMENT="${1:-dev}"
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/terraform"

echo "⚠️  WARNING: This will destroy ALL infrastructure for $ENVIRONMENT"
read -p "Type 'yes' to confirm: " -r
[[ $REPLY =~ ^[Yy][Ee][Ss]$ ]] || exit 1

echo "Destroying Helm releases..."
helm uninstall caddy -n caddy-${ENVIRONMENT} --wait 2>/dev/null || true

echo "Destroying infrastructure..."
cd $TERRAFORM_DIR
terraform destroy -var-file="environments/${ENVIRONMENT}.tfvars" -auto-approve

echo "✓ Cleanup complete"
