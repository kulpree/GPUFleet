# Component: Container registry

**Terraform resource:** `nebius_registry_v1_registry.apps`
**Nebius service:** Container Registry

## What it is

A private registry for container images. Kubernetes nodes pull images from it.

## Why it is here

The three application images (`ingest`, `train`, `rag-api`) are built locally or in CI and pushed here. Pulling from a registry in the same region as the cluster avoids egress charges and speeds up pod start.

## Key settings

| Argument | Value |
|---|---|
| `name` | `var.registry_name` (default `spiritual-rag`) |
| `parent_id` | `var.project_id` |
| `description` | Short text describing the images |

## Build and push

Log in with the registry endpoint and credentials from the Nebius console or CLI, then:

```bash
docker build -t <registry-endpoint>/spiritual-rag/rag-api:0.1.0 apps/rag-api
docker push <registry-endpoint>/spiritual-rag/rag-api:0.1.0
```

Replace `REGISTRY` in `apps/k8s/*.yaml` with the registry endpoint. Pin tags such as `0.1.0`. Avoid `latest` in anything you deploy.

## Cost

Registry storage and egress are billed. Delete old image tags you no longer use. Keep only the last few tags for each image.

## Verify before use

- The registry endpoint format and the login command. The provider reference lists the resource; confirm the login steps in the Nebius container registry guide.

## References

- Terraform resource: https://docs.nebius.com/terraform-provider/reference/resources/registry_v1_registry
- Quickstart example that creates a registry: https://docs.nebius.com/terraform-provider/quickstart
