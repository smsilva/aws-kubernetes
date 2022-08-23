module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 3.0.0, < 4.0.0"

  name               = var.vpc_name
  cidr               = var.vpc_cidr
  azs                = var.vpc_azs
  private_subnets    = var.vpc_private_subnets
  public_subnets     = var.vpc_public_subnets
  enable_nat_gateway = var.vpc_enable_nat_gateway
  tags               = var.vpc_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 18.0.0, < 19.0.0"

  cluster_name                    = "wasp-sandbox-${random_string.id.result}"
  cluster_version                 = "1.22"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }

    kube-proxy = {}

    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  self_managed_node_group_defaults = {
    instance_type                          = "m6i.large"
    update_launch_template_default_version = true

    iam_role_additional_policies = [
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ]
  }

  eks_managed_node_group_defaults = {
    disk_size = 50

    instance_types = [
      "m6i.large",
      "m5.large",
      "m5n.large",
      "m5zn.large"
    ]
  }

  eks_managed_node_groups = {
    blue = {}

    green = {
      min_size     = 1
      max_size     = 10
      desired_size = 2

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
