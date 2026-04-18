locals {
  # Registries that may need a Secrets Manager secret. The key flows into the
  # secret name: ecr-pullthroughcache/<key>-credentials.
  _secretable = {
    docker_hub = {
      create = try(var.docker_hub.create_credential_secret, false) && var.docker_hub.enabled
    }
    github = {
      create = try(var.github.create_credential_secret, false) && var.github.enabled
    }
    gitlab = {
      create = try(var.gitlab.create_credential_secret, false) && var.gitlab.enabled
    }
    chainguard = {
      create = try(var.chainguard.create_credential_secret, false) && var.chainguard.enabled
    }
  }

  _secret_targets = { for k, v in local._secretable : k => v if v.create }
}

# -----------------------------------------------------------------------------
# Optional Secrets Manager shells for upstream credentials.
# -----------------------------------------------------------------------------
# The name *must* start with "ecr-pullthroughcache/" for ECR to be allowed to
# read it. We create the secret shell only; callers are expected to populate
# the value via a separate workflow (CI, Parameter Store import, rotation, ...).

resource "aws_secretsmanager_secret" "upstream" {
  for_each = local._secret_targets
  name     = "ecr-pullthroughcache/${replace(each.key, "_", "-")}-credentials"
}

resource "aws_secretsmanager_secret" "azure" {
  for_each = { for k, v in var.azure_registries : k => v if v.create_credential_secret }
  name     = "ecr-pullthroughcache/azure-${each.key}-credentials"
}

locals {
  _docker_hub_arn = var.docker_hub.enabled ? coalesce(
    var.docker_hub.credential_arn,
    try(aws_secretsmanager_secret.upstream["docker_hub"].arn, null),
  ) : null
  _github_arn = var.github.enabled ? coalesce(
    var.github.credential_arn,
    try(aws_secretsmanager_secret.upstream["github"].arn, null),
  ) : null
  _gitlab_arn = var.gitlab.enabled ? coalesce(
    var.gitlab.credential_arn,
    try(aws_secretsmanager_secret.upstream["gitlab"].arn, null),
  ) : null
  _chainguard_arn = var.chainguard.enabled ? coalesce(
    var.chainguard.credential_arn,
    try(aws_secretsmanager_secret.upstream["chainguard"].arn, null),
  ) : null
}

# -----------------------------------------------------------------------------
# Pull-through cache rules.
# -----------------------------------------------------------------------------

resource "aws_ecr_pull_through_cache_rule" "quay" {
  count                 = var.quay.enabled ? 1 : 0
  ecr_repository_prefix = var.quay.ecr_prefix
  upstream_registry_url = "quay.io"
}

resource "aws_ecr_pull_through_cache_rule" "kubernetes" {
  count                 = var.kubernetes.enabled ? 1 : 0
  ecr_repository_prefix = var.kubernetes.ecr_prefix
  upstream_registry_url = "registry.k8s.io"
}

resource "aws_ecr_pull_through_cache_rule" "ecr_public" {
  count                 = var.ecr_public.enabled ? 1 : 0
  ecr_repository_prefix = var.ecr_public.ecr_prefix
  upstream_registry_url = "public.ecr.aws"
}

resource "aws_ecr_pull_through_cache_rule" "docker_hub" {
  count                 = var.docker_hub.enabled ? 1 : 0
  ecr_repository_prefix = var.docker_hub.ecr_prefix
  upstream_registry_url = "registry-1.docker.io"
  credential_arn        = local._docker_hub_arn
}

resource "aws_ecr_pull_through_cache_rule" "github" {
  count                 = var.github.enabled ? 1 : 0
  ecr_repository_prefix = var.github.ecr_prefix
  upstream_registry_url = "ghcr.io"
  credential_arn        = local._github_arn
}

resource "aws_ecr_pull_through_cache_rule" "gitlab" {
  count                 = var.gitlab.enabled ? 1 : 0
  ecr_repository_prefix = var.gitlab.ecr_prefix
  upstream_registry_url = "registry.gitlab.com"
  credential_arn        = local._gitlab_arn
}

resource "aws_ecr_pull_through_cache_rule" "chainguard" {
  count                 = var.chainguard.enabled ? 1 : 0
  ecr_repository_prefix = var.chainguard.ecr_prefix
  upstream_registry_url = "cgr.dev"
  credential_arn        = local._chainguard_arn
}

resource "aws_ecr_pull_through_cache_rule" "azure" {
  for_each              = var.azure_registries
  ecr_repository_prefix = coalesce(each.value.ecr_prefix, "${each.value.subdomain}.azurecr.io")
  upstream_registry_url = "${each.value.subdomain}.azurecr.io"
  credential_arn = coalesce(
    each.value.credential_arn,
    try(aws_secretsmanager_secret.azure[each.key].arn, null),
  )
}
