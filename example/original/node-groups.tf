locals {
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
    green = {
      min_size     = 1
      max_size     = 5
      desired_size = 1

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
    }
  }
}
