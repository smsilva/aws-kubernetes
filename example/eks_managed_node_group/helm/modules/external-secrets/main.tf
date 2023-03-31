resource "helm_release" "external_secrets" {
  namespace        = var.namespace
  create_namespace = true
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.8.1"
}

resource "helm_release" "external_secrets_config" {
  namespace = var.namespace
  name      = "external-secrets-config"
  chart     = "${path.module}/../../charts/external-secrets-config"

  set {
    name  = "serviceAccount.name"
    value = var.service_account_name
  }

  set {
    name  = "serviceAccount.namespace"
    value = var.namespace
  }

  set {
    name  = "iam.roleArn"
    value = aws_iam_role.external_secrets_operator.arn
  }

  depends_on = [
    helm_release.external_secrets
  ]
}
