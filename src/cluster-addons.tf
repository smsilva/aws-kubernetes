locals {
  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }

    kube-proxy = {}

    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }
}
