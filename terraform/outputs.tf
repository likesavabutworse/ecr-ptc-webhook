data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

output "aws_account_id" {
  description = "Account ID where the pull-through cache rules were created."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Region where the pull-through cache rules were created."
  value       = data.aws_region.current.region
}

output "ecr_prefixes" {
  description = "Map of upstream registry key to the ECR repository prefix used for caching. Feed this into the Helm chart's registries[*].ecrPrefix so the webhook's rewrites match the prefixes actually created in ECR."
  value = merge(
    var.quay.enabled       ? { quay       = var.quay.ecr_prefix }       : {},
    var.kubernetes.enabled ? { kubernetes = var.kubernetes.ecr_prefix } : {},
    var.ecr_public.enabled ? { ecr_public = var.ecr_public.ecr_prefix } : {},
    var.docker_hub.enabled ? { docker_hub = var.docker_hub.ecr_prefix } : {},
    var.github.enabled     ? { github     = var.github.ecr_prefix }     : {},
    var.gitlab.enabled     ? { gitlab     = var.gitlab.ecr_prefix }     : {},
    var.chainguard.enabled ? { chainguard = var.chainguard.ecr_prefix } : {},
    {
      for k, v in var.azure_registries :
      "azure_${k}" => coalesce(v.ecr_prefix, "${v.subdomain}.azurecr.io")
    },
  )
}

output "credential_secret_arns" {
  description = "ARNs of any Secrets Manager shells this module created for upstream credentials."
  value = merge(
    { for k, s in aws_secretsmanager_secret.upstream : k => s.arn },
    { for k, s in aws_secretsmanager_secret.azure : "azure_${k}" => s.arn },
  )
}

output "registry_policy_managed" {
  description = "Whether this module is managing the aws_ecr_registry_policy for the account/region."
  value       = var.manage_registry_policy
}
