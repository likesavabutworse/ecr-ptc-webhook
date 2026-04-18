# ecr-ptc-webhook

A Kubernetes mutating admission webhook to rewrite container images to pull
through [Amazon ECR Pull Through Cache](https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache.html).

When a pod is created, images from configured upstream registries (`docker.io`, `quay.io`, `ghcr.io`, `registry.gitlab.com`, `cgr.dev`, any `*.azurecr.io`) are rewritten to `<account>.dkr.ecr.<region>.amazonaws.com/<prefix>/...`. Docker Hub library images (`nginx`, `postgres:16`) are normalized to `library/<name>` before rewriting.


Required env vars: `ECR_REGISTRY_ACCOUNT_ID`, `ECR_REGISTRY_REGION` — the AWS account and region of the ECR private registry where the pull-through cache rules live. These are intentionally decoupled from the cluster's own account/region because the ECR registry is frequently in a different account (shared registry) or region (single-region cache). Optional `REGISTRIES_CONFIG_PATH` points at a YAML file of the form below; if unset the defaults in [src/registries.py](src/registries.py) are used.

```yaml
registries:
  - host: docker.io
    ecr_prefix: docker-hub
    dockerhub: true
  - host: quay.io
    ecr_prefix: quay
```

## Metrics

Prometheus metrics are served on `:9090/metrics` (plain HTTP, separate from
the TLS webhook port).

The Helm chart renders a `ServiceMonitor` when `metrics.serviceMonitor.enabled=true`.

## Deploying

### Terraform

See [terraform/README.md](terraform/README.md). Creates the pull-through
cache rules and a reference IAM policy for node / workload roles.

### Helm

cert-manager is required by default (the chart provisions the webhook
serving cert). To use an existing TLS secret, set `tls.mode=existingSecret`.

```sh
helm install ecr-ptc-webhook \
  oci://ghcr.io/likesavabutworse/charts/ecr-ptc-webhook \
  --version 0.1.0 \
  --namespace ecr-ptc-webhook --create-namespace \
  --set awsAccountId=123456789012 \
  --set awsRegion=us-east-1 \
  --set metrics.serviceMonitor.enabled=true
```

Opt namespaces out by labelling them with  `ecr-ptc-webhook/ignore=true`.