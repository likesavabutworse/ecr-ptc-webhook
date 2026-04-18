# ECR Pull-Through Cache — reference Terraform module

Creates `aws_ecr_pull_through_cache_rule` resources for each upstream registry
the webhook supports, plus an `aws_ecr_registry_policy` that grants this
account (and, optionally, sibling accounts) permission to trigger pull-through
cache fills and pull cached images.

## Registries supported

| Variable           | Upstream URL                   | Secret required |
|--------------------|--------------------------------|-----------------|
| `quay`             | `quay.io`                      | no              |
| `kubernetes`       | `registry.k8s.io`              | no              |
| `ecr_public`       | `public.ecr.aws`               | no              |
| `docker_hub`       | `registry-1.docker.io`         | yes             |
| `github`           | `ghcr.io`                      | yes             |
| `gitlab`           | `registry.gitlab.com`          | yes             |
| `chainguard`       | `cgr.dev`                      | yes             |
| `azure_registries` | `<subdomain>.azurecr.io` each  | yes (per entry) |

By convention the ECR repository prefix mirrors the upstream hostname
(`docker.io`, `quay.io`, `ghcr.io`, `cgr.dev`, ...). The webhook config in
[deploy/chart/values.yaml](../deploy/chart/values.yaml) uses the same
convention, so as long as you take the defaults on both sides they stay in
sync.

## Credentials

Upstream registries that require authentication expect credentials in an AWS
Secrets Manager secret whose name starts with `ecr-pullthroughcache/` and
whose JSON value has the following format:

```json
{ "username": "...", "accessToken": "..." }
```

Two ways to wire this up:

1. Bring your own ARN — point `credential_arn` at a secret managed by
   another stack, external-secrets, etc. The module does not touch it.
2. Let the module create the shell — set `create_credential_secret =
   true` on the registry block. The module creates an empty
   `aws_secretsmanager_secret` named
   `ecr-pullthroughcache/<registry>-credentials` and wires its ARN into the
   PTC rule. You still populate the value out of band (e.g. via CI or SOPS, ESO `PushSecret`).

## Registry policy

The `aws_ecr_registry_policy` grants, at the registry level:

- Self — `CreateRepository` + `BatchImportUpstreamImage`. Required for the
  first pull of a new upstream image (ECR creates the downstream repo on
  demand). With this, the standard `AmazonEC2ContainerRegistryReadOnly` is 
  enough to use PC and no additional workilad permissions are needed.
- Cross-account pull (optional, when `cross_account_pull_ids` is set) —
  broader ECR read + PTC actions to every account ID listed. Useful for 
  AWS organizations that have a central ECR registry

Set `manage_registry_policy = false` if another module already owns the
registry policy for this account / region — only one `aws_ecr_registry_policy`
resource can exist per region.

## Example

```
module "ecr_ptc" {
  source = "github.com/likesavabutworse/ecr-ptc-webhook//terraform?ref=v0.1.0"

  quay       = { enabled = true }
  kubernetes = { enabled = true }

  docker_hub = {
    enabled                  = true
    create_credential_secret = true  # Create empty ecr-pullthroughcache/docker-hub-credentials
  }

  github = {
    enabled        = true
    credential_arn = aws_secretsmanager_secret.ghcr.arn  # BYOS
  }

  chainguard = {
    enabled                  = true
    create_credential_secret = true
  }

  azure_registries = {
    prod = {
      subdomain                = "myregistry"
      create_credential_secret = true
    }
  }

  cross_account_pull_ids = ["111122223333", "444455556666"]
}
```