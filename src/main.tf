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
  cluster_version                 = "1.23"
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

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    # nginx-ingress requires the cluster to communicate with the ingress controller
    cluster_to_node = {
      description                   = "Cluster to ingress-nginx webhook"
      protocol                      = "-1"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }

    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
