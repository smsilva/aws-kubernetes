data "aws_availability_zones" "available" {}

locals {
  vpc_cidr        = "10.0.0.0/16" # 10.0.0.0/16 10.244.0.0/16
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]
}

output "values" {
  value = {
    azs             = local.azs
    vpc_cidr        = local.vpc_cidr
    private_subnets = local.private_subnets
    public_subnets  = local.public_subnets
    intra_subnets   = local.intra_subnets
  }
}
