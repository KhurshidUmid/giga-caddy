#!/bin/bash
# scripts/deploy.sh - Complete deployment automation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
HELM_DIR="${PROJECT_ROOT}/helm"

# Default values
ENVIRONMENT="${1:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="giga-caddy-${ENVIRONMENT}"

# Validation
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Environment must be dev, staging, or prod${NC}"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}Giga-Caddy EKS Deployment Script${NC}"
echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"

# Pre-flight checks
echo -e "\n${BLUE}[1/5] Pre-flight checks...${NC}"

command -v terraform &> /dev/null || { echo "terraform not found"; exit 1; }
command -v helm &> /dev/null || { echo "helm not found"; exit 1; }
command -v kubectl &> /dev/null || { echo "kubectl not found"; exit 1; }
command -v aws &> /dev/null || { echo "aws cli not found"; exit 1; }

# Check AWS credentials
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All required tools found${NC}"
echo -e "${GREEN}✓ AWS credentials valid${NC}"

# Terraform validation
echo -e "\n${BLUE}[2/5] Terraform validation...${NC}"

cd "$TERRAFORM_DIR"

echo "Running terraform format check..."
terraform fmt -check -recursive . || {
    echo -e "${YELLOW}Formatting issues found. Running terraform fmt...${NC}"
    terraform fmt -recursive .
}

echo "Running terraform validate..."
terraform validate || exit 1

echo "Running tflint..."
tflint --init > /dev/null 2>&1 || true
tflint --format compact || exit 1

echo -e "${GREEN}✓ Terraform validation passed${NC}"

# Terraform plan
echo -e "\n${BLUE}[3/5] Terraform planning...${NC}"

if [[ ! -f "environments/${ENVIRONMENT}.tfvars" ]]; then
    echo -e "${RED}Error: environments/${ENVIRONMENT}.tfvars not found${NC}"
    exit 1
fi

echo "Initializing Terraform..."
terraform init -upgrade

echo "Creating Terraform plan..."
terraform plan \
    -var-file="environments/${ENVIRONMENT}.tfvars" \
    -var="route53_zone_id=${ROUTE53_ZONE_ID:-}" \
    -var="letsencrypt_email=${LETSENCRYPT_EMAIL:-}" \
    -out="${ENVIRONMENT}.tfplan" || exit 1

echo -e "${GREEN}✓ Terraform plan created: ${ENVIRONMENT}.tfplan${NC}"

# Security scanning
echo -e "\n${BLUE}[4/5] Security scanning...${NC}"

echo "Running tfsec..."
tfsec . --format sarif > tfsec.sarif || true

if grep -q '"level":"error"' tfsec.sarif 2>/dev/null; then
    echo -e "${YELLOW}Security warnings found. Review tfsec.sarif${NC}"
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        echo -e "${RED}Blocking production deployment due to security issues${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Security scan completed${NC}"

# Helm validation
echo -e "\n${BLUE}[5/5] Helm chart validation...${NC}"

cd "$HELM_DIR/caddy"

echo "Validating Helm charts..."
helm lint . \
    -f values.yaml \
    -f values-${ENVIRONMENT}.yaml || exit 1

echo "Generating manifests..."
helm template caddy . \
    --values values.yaml \
    --values values-${ENVIRONMENT}.yaml \
    > "${PROJECT_ROOT}/manifests-${ENVIRONMENT}.yaml"

echo "Validating Kubernetes manifests..."
kubeval --strict "${PROJECT_ROOT}/manifests-${ENVIRONMENT}.yaml" || exit 1

echo -e "${GREEN}✓ Helm validation passed${NC}"

# Confirmation
echo -e "\n${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}Validation Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the Terraform plan:"
echo "   cd $TERRAFORM_DIR && terraform show ${ENVIRONMENT}.tfplan"
echo ""
echo "2. Apply infrastructure:"
echo "   cd $TERRAFORM_DIR && terraform apply ${ENVIRONMENT}.tfplan"
echo ""
echo "3. Update kubeconfig:"
echo "   aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME"
echo ""
echo "4. Deploy Caddy:"
echo "   ./scripts/verify-cluster.sh"
echo ""
