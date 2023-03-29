locals {
  cluster_name = "wasp-sandbox-${random_string.id.result}"

  tags = {
    origin = "terraform"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 19.0.0, < 20.0.0"

  cluster_name                            = local.cluster_name
  cluster_version                         = "1.24"
  cluster_endpoint_private_access         = true
  cluster_endpoint_public_access          = true
  vpc_id                                  = module.vpc.vpc_id
  subnet_ids                              = module.vpc.private_subnets
  cluster_addons                          = local.cluster_addons
  self_managed_node_group_defaults        = local.self_managed_node_group_defaults
  eks_managed_node_group_defaults         = local.eks_managed_node_group_defaults
  eks_managed_node_groups                 = local.eks_managed_node_groups
  cluster_security_group_additional_rules = local.cluster_security_group_additional_rules
  node_security_group_additional_rules    = local.node_security_group_additional_rules
  tags                                    = local.tags
}
