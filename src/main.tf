locals {
  name                     = var.cluster_name
  region                   = var.region
  cluster_version          = "1.24"
  install_external_secrets = true

  tags = {
    origin = "terraform"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 19.0.0, < 20.0.0"

  cluster_name                    = local.name
  cluster_version                 = local.cluster_version
  cluster_endpoint_public_access  = true
  cluster_ip_family               = "ipv6"
  create_cni_ipv6_iam_policy      = true
  cluster_addons                  = local.cluster_addons
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  control_plane_subnet_ids        = module.vpc.intra_subnets
  manage_aws_auth_configmap       = true
  aws_auth_roles                  = local.aws_auth_roles
  eks_managed_node_group_defaults = local.eks_managed_node_group_defaults
  eks_managed_node_groups         = local.eks_managed_node_groups
  tags                            = local.tags
}

module "external_secrets" {
  count  = local.install_external_secrets ? 1 : 0
  source = "./helm/modules/external-secrets"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider
  iam_policy_name   = "secretsmanager-docker-hub-read-only"

  depends_on = [
    module.eks,
    module.eks.eks_managed_node_groups
  ]
}
