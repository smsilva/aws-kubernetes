locals {
  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

    instance_types = [
      "m6i.large",
      "m5.large",
      "m5n.large",
      "m5zn.large",
    ]

    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    default_node_group = {
      use_custom_launch_template = false

      disk_size    = 50
      min_size     = 1
      max_size     = 5
      desired_size = 1

      remote_access = {
        ec2_ssh_key               = module.key_pair.key_pair_name
        source_security_group_ids = [aws_security_group.remote_access.id]
      }

      instance_types = [
        "m6i.large",
        "m5.large",
        "m5n.large",
        "m5zn.large",
      ]
    }
  }
}
