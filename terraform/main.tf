module "api" {
  source = "./modules/api"
  eks_cluster_name = var.eks_cluster_name
  rds_cluster_name = var.rds_cluster_name
  db_user = var.db_user
  db_password = var.db_password
  ecr_repository_name = var.ecr_repository_name
}
