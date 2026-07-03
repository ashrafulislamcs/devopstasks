output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS control plane API endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_backend_repo_url" {
  description = "ECR repository URL for the backend image"
  value       = module.ecr.backend_repo_url
}

output "ecr_frontend_repo_url" {
  description = "ECR repository URL for the frontend image"
  value       = module.ecr.frontend_repo_url
}

output "vpc_id" {
  description = "VPC ID used by the cluster and database"
  value       = module.vpc.vpc_id
}

output "rds_endpoint" {
  description = "Private RDS endpoint (not publicly reachable)"
  value       = module.rds.db_endpoint
  sensitive   = true
}
