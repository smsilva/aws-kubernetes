locals {
  aws_auth_roles = [
    {
      rolearn  = data.aws_iam_role.eks_admin.arn
      username = "eks-admin"
      groups = [
        "system:masters",
      ]
    },
  ]
}

resource "aws_iam_policy" "node_additional" {
  name        = "${local.name}-additional"
  description = "Example usage of node additional policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = local.tags
}
