data "aws_iam_policy" "secretsmanager" {
  name = var.iam_policy_name
}

resource "aws_iam_role" "external_secrets_operator" {
  name = "${var.iam_role_base_name}-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:sub" : "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${var.oidc_provider}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {}
}

resource "aws_iam_role_policy_attachment" "external_secrets_operator" {
  role       = aws_iam_role.external_secrets_operator.name
  policy_arn = data.aws_iam_policy.secretsmanager.arn
}
