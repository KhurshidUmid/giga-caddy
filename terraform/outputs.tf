output "cluster_name" {
  value = var.cluster_name
}

output "region" {
  value = var.region
}

output "ecr_repository_url" {
  value = aws_ecr_repository.giga_caddy.repository_url
  description = "ECR repository for Caddy image"
}

output "kubeconfig" {
  value = module.eks.kubeconfig
  sensitive = true
}
