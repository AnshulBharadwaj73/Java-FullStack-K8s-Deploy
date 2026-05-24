module "vpc" {
  source = "./module"

  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  eks_cluster_name   = var.eks_cluster_name
  single_nat_gateway = var.single_nat_gateway
  tags               = var.tags
}
