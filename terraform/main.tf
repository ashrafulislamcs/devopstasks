# Root module: wires together custom child modules.
# No third-party/community modules used - everything under ./modules is
module "vpc" {
  source = "./modules/vpc"

  environment  = var.environment
  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
}

module "ecr" {
  source = "./modules/ecr"

  environment  = var.environment
  cluster_name = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  environment         = var.environment
  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  node_instance_type  = var.node_instance_type
  node_desired_count  = var.node_desired_count
  node_min_count      = var.node_min_count
  node_max_count      = var.node_max_count
}

module "rds" {
  source = "./modules/rds"

  environment              = var.environment
  cluster_name             = var.cluster_name
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  db_instance_class        = var.db_instance_class
  db_name                  = var.db_name
  db_username              = var.db_username
  eks_node_security_group  = module.eks.node_security_group_id
}

module "monitoring" {
  source = "./modules/monitoring"

  environment  = var.environment
  cluster_name = var.cluster_name
}
