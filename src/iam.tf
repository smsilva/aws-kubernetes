locals {
  kubernetes_namespace            = "external-secrets"
  kubernetes_service_account_name = "secretsmanager-access"
  iam_role_base_name              = "external-secrets-operator"
  iam_policy_name                 = "secretsmanager-docker-hub-read-only"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_arn
}

data "aws_iam_policy" "secretsmanager_docker_hub_read_only" {
  name = local.iam_policy_name
}

resource "kubernetes_namespace" "external_secrets" {

  metadata {
    name = local.kubernetes_namespace
  }

}

resource "aws_iam_role" "external_secrets_operator" {
  name = "${local.iam_role_base_name}-${local.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:sub" : "system:serviceaccount:${local.kubernetes_namespace}:${local.kubernetes_service_account_name}"
            "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com"
          }
        }
      },
    ]
  })

  tags = {}
}

resource "aws_iam_role_policy_attachment" "external_secrets_operator" {
  role       = aws_iam_role.external_secrets_operator.name
  policy_arn = data.aws_iam_policy.secretsmanager_docker_hub_read_only.arn
}

resource "kubernetes_service_account" "external_secrets_operator" {
  metadata {
    name      = local.kubernetes_service_account_name
    namespace = local.kubernetes_namespace

    annotations = {
      "eks.amazonaws.com/role-arn" : aws_iam_role.external_secrets_operator.arn
    }
  }
}

resource "helm_release" "external_secrets" {
  namespace  = local.kubernetes_namespace
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.8.1"

  depends_on = [
    module.eks
  ]
}

resource "helm_release" "external_secrets_config" {
  namespace = local.kubernetes_namespace
  name      = "external-secrets-config"
  chart     = "${path.module}/helm/charts/external-secrets-config"

  set {
    name = "serviceAccount.name"
    value = local.kubernetes_service_account_name
  }

  set {
    name = "serviceAccount.namespace"
    value = local.kubernetes_namespace
  }

  depends_on = [
    helm_release.external_secrets
  ]
}
