data "aws_partition" "current" {}

locals {
  _registry_arns = [
    "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/*",
    "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/*/*",
  ]
}

data "aws_iam_policy_document" "registry" {
  count = var.manage_registry_policy ? 1 : 0

  # Allow this account's own principals to trigger pull-through cache fills.
  # Without this, the first pull of a new upstream image fails because ECR
  # cannot create the downstream repo on demand.
  statement {
    sid = "PullThroughCacheSelf"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "ecr:CreateRepository",
      "ecr:BatchImportUpstreamImage",
    ]
    resources = local._registry_arns
  }

  # Optional: let other accounts in the org pull cached images out of this
  # registry (avoids every account running its own cache).
  dynamic "statement" {
    for_each = length(var.cross_account_pull_ids) > 0 ? [1] : []
    content {
      sid = "CrossAccountPull"
      principals {
        type = "AWS"
        identifiers = [
          for id in var.cross_account_pull_ids :
          "arn:${data.aws_partition.current.partition}:iam::${id}:root"
        ]
      }
      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:GetLifecyclePolicy",
        "ecr:GetLifecyclePolicyPreview",
        "ecr:ListTagsForResource",
        "ecr:DescribeImageScanFindings",
        "ecr:BatchImportUpstreamImage",
        "ecr:GetImageCopyStatus",
        "ecr:CreateRepository",
      ]
      resources = local._registry_arns
    }
  }
}

resource "aws_ecr_registry_policy" "this" {
  count  = var.manage_registry_policy ? 1 : 0
  policy = data.aws_iam_policy_document.registry[0].json
}
