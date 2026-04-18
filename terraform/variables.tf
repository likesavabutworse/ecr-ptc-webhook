variable "quay" {
  description = "Quay (quay.io) pull-through cache rule. No upstream credentials required."
  type = object({
    enabled    = bool
    ecr_prefix = optional(string, "quay.io")
  })
  default = { enabled = true }
}

variable "kubernetes" {
  description = "Kubernetes (registry.k8s.io) pull-through cache rule. No upstream credentials required."
  type = object({
    enabled    = bool
    ecr_prefix = optional(string, "registry.k8s.io")
  })
  default = { enabled = false }
}

variable "ecr_public" {
  description = "Amazon ECR Public (public.ecr.aws) pull-through cache rule. No upstream credentials required."
  type = object({
    enabled    = bool
    ecr_prefix = optional(string, "public.ecr.aws")
  })
  default = { enabled = false }
}

variable "docker_hub" {
  description = "Docker Hub pull-through cache rule. Requires a Secrets Manager secret."
  type = object({
    enabled                  = bool
    ecr_prefix               = optional(string, "docker.io")
    credential_arn           = optional(string)
    create_credential_secret = optional(bool, false)
  })
  default = { enabled = false }
  validation {
    condition     = !var.docker_hub.enabled || var.docker_hub.credential_arn != null || var.docker_hub.create_credential_secret
    error_message = "docker_hub: set credential_arn or create_credential_secret=true when enabled."
  }
}

variable "github" {
  description = "GitHub Container Registry (ghcr.io) pull-through cache rule. Requires a Secrets Manager secret."
  type = object({
    enabled                  = bool
    ecr_prefix               = optional(string, "ghcr.io")
    credential_arn           = optional(string)
    create_credential_secret = optional(bool, false)
  })
  default = { enabled = false }
  validation {
    condition     = !var.github.enabled || var.github.credential_arn != null || var.github.create_credential_secret
    error_message = "github: set credential_arn or create_credential_secret=true when enabled."
  }
}

variable "gitlab" {
  description = "GitLab Container Registry (registry.gitlab.com) pull-through cache rule. Requires a Secrets Manager secret."
  type = object({
    enabled                  = bool
    ecr_prefix               = optional(string, "registry.gitlab.com")
    credential_arn           = optional(string)
    create_credential_secret = optional(bool, false)
  })
  default = { enabled = false }
  validation {
    condition     = !var.gitlab.enabled || var.gitlab.credential_arn != null || var.gitlab.create_credential_secret
    error_message = "gitlab: set credential_arn or create_credential_secret=true when enabled."
  }
}

variable "chainguard" {
  description = "Chainguard Registry (cgr.dev) pull-through cache rule. Requires a Secrets Manager secret."
  type = object({
    enabled                  = bool
    ecr_prefix               = optional(string, "cgr.dev")
    credential_arn           = optional(string)
    create_credential_secret = optional(bool, false)
  })
  default = { enabled = false }
  validation {
    condition     = !var.chainguard.enabled || var.chainguard.credential_arn != null || var.chainguard.create_credential_secret
    error_message = "chainguard: set credential_arn or create_credential_secret=true when enabled."
  }
}

variable "azure_registries" {
  description = "Per-registry configuration for Azure Container Registry pull-through cache rules. Key is used for for_each / resource addressing. Each ACR subdomain must be registered as a separate rule."
  type = map(object({
    subdomain                = string  # e.g. "myregistry" for myregistry.azurecr.io
    ecr_prefix               = optional(string)  # defaults to "<subdomain>.azurecr.io"
    credential_arn           = optional(string)
    create_credential_secret = optional(bool, false)
  }))
  default = {}
  validation {
    condition = alltrue([
      for k, v in var.azure_registries :
      v.credential_arn != null || v.create_credential_secret
    ])
    error_message = "azure_registries: each entry must set credential_arn or create_credential_secret=true."
  }
}

variable "cross_account_pull_ids" {
  description = "Extra AWS account IDs allowed to pull from this ECR registry via the registry-level policy. Grant is applied at the registry (not repository) level and covers all PTC-cached repos."
  type        = list(string)
  default     = []
}

variable "manage_registry_policy" {
  description = "Whether to manage the aws_ecr_registry_policy. Set to false if another module / stack owns the registry policy."
  type        = bool
  default     = true
}
