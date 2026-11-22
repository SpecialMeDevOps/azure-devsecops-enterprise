# SecureOps API Azure infrastructure

This Terraform root module describes Azure infrastructure for SecureOps API. It never creates the existing resource group. Resource modes default to `reference`, so existing resources are looked up rather than silently recreated. A read-only Azure inventory is required before changing a mode to `create` or importing an existing resource.

## Architecture

```text
Existing Resource Group (rg-secureops-dev)
├── Azure Container Registry (existing/reference or explicitly created)
├── Log Analytics Workspace (existing/reference or explicitly created)
├── Azure Container Apps Environment (Consumption)
├── User-assigned managed identity
│   └── AcrPull at the registry scope, only when explicitly enabled
└── Azure Container App
    ├── Internal target port: 8000
    ├── Startup, readiness, and liveness probes: GET /health
    ├── HTTP concurrency scaling with configurable replica bounds
    └── HTTPS ingress, external exposure disabled by default
```

The app uses the configured image from ACR and authenticates image pulls with the user-assigned identity. ACR admin credentials are disabled. The image should already exist in the registry before creating the Container App; Terraform does not build, push, or deploy an image.

The container image retains its own non-root `USER 10001:10001` configuration. This module does not change the Dockerfile or application.

## Important ownership and duplicate-resource safeguards

The Azure CLI is useful for inventory. These commands are read-only:

```powershell
az account show --query "{name:name,state:state}" -o table
az group show --name rg-secureops-dev --query "{name:name,location:location}" -o table
az resource list --resource-group rg-secureops-dev --query "[].{name:name,type:type,location:location}" -o table
az acr list --resource-group rg-secureops-dev --query "[].{name:name,sku:sku.name,adminUserEnabled:adminUserEnabled,loginServer:loginServer}" -o table
az role assignment list --scope <ACR_RESOURCE_ID> --all --query "[].{role:roleDefinitionName,principal:principalId,scope:scope}" -o table
```

Inspect the Container Apps Environment, Container App, Log Analytics workspace, and user-assigned identities in the resource group as well. This configuration cannot discover all untracked resources automatically.

For each resource:

1. Use `reference` when an existing object is shared or intentionally managed outside this Terraform state. Its data source is read-only and Terraform will not modify it.
2. Use `create` only after confirming the object does not exist in Azure.
3. If Terraform should own an existing object, use the corresponding resource mode and run `terraform import` explicitly after reviewing its ID, configuration, current state owner, and possible replacement changes. Import commands are examples only; none are run automatically.
4. Do not import an object already managed by another Terraform state.

The existing resource group is always a data source; there is no resource-group creation block. `prevent_destroy` protects a registry or workspace that this state manages from accidental destruction.

The `manage_acr_pull_role_assignment` flag defaults to `false` because an equivalent assignment may already exist. Set it to `true` only after inventory confirms the assignment is missing, or after explicitly importing an assignment this state should own. If an equivalent assignment remains externally managed, set `existing_acr_pull_assignment_confirmed = true` only after verifying its principal, scope, and role. App creation is blocked unless one of these conditions is satisfied. In classic ACR RBAC mode, the role is `AcrPull` scoped to the registry. Confirm the registry's permission mode before using this role; repository-ABAC mode may require a repository-scoped role instead.

When referencing an existing registry, the app creation precondition also requires its ACR admin account to be disabled. The configuration never reads or outputs registry passwords.

## Prerequisites

- Terraform `>= 1.8.0, < 2.0.0`.
- Azure CLI for local Azure authentication and read-only inventory.
- An Azure subscription and access to the existing `rg-secureops-dev` resource group.
- An image already present in ACR. Prefer an immutable digest reference.
- A decision on whether the API should have public HTTPS ingress. It is disabled by default.
- For Terraform to create the pull-role assignment, the executing identity must be authorized to create that assignment. Keep that permission scoped as narrowly as possible.

The provider is HashiCorp's official `azurerm` provider. `~> 4.0` constrains the provider to the 4.x series; commit `.terraform.lock.hcl` after initialization to pin the selected build and checksums.

## Configure inputs

Copy the example and fill in the real, non-secret resource names:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` is ignored by Git. Do not put credentials, access keys, client secrets, or tokens in it. The subscription ID is an identifier, not an authentication secret.

Keep all resource modes set to `reference` until inventory confirms the resources exist. For absent resources, deliberately change only their mode to `create`. A registry name must be globally unique. The selected `container_image` must already exist in that registry.

## Azure authentication

For local development, sign in with Azure CLI:

```powershell
az login
az account set --subscription <SUBSCRIPTION_ID>
```

Set `subscription_id` in a local tfvars file or supply `ARM_SUBSCRIPTION_ID`. The provider uses the local Azure CLI identity; no credentials are stored in Terraform configuration.

For GitHub Actions, configure an Entra federated identity credential for the intended repository/workflow subject and grant the workflow identity only the required Azure permissions. Use GitHub OIDC (`id-token: write` on only the Azure job), not a client secret. This Terraform template does not modify GitHub workflows or create Entra identities.

## Initialization and local validation

From the repository root in PowerShell:

```powershell
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform init -backend=false -input=false
terraform -chdir=terraform validate
```

`-backend=false` is for local provider initialization and configuration validation. It does not configure remote state. Initialization downloads provider packages and creates local `.terraform` metadata; `.terraform.lock.hcl` should be reviewed and committed.

Before any real plan, confirm all resource modes, names, region, image reference, ingress choice, role-assignment state, and backend settings.

## Plan review

After authenticating and configuring a backend appropriate for the environment:

```powershell
terraform -chdir=terraform plan -input=false -out=secureops.tfplan
terraform -chdir=terraform show secureops.tfplan
```

Review every add, change, and destroy. A plan is not a substitute for Azure inventory: an object absent from Terraform state may still exist in Azure. Do not apply a plan that creates a duplicate, replaces an existing service unexpectedly, exposes public ingress without approval, or changes resources owned by another state. Plan files can contain sensitive configuration and are ignored by Git; store them securely and do not upload them to public artifacts.

This repository's existing GitHub Actions workflow runs tests, Python security scans, Docker verification, and Trivy, but does not publish to ACR or authenticate to Azure. This Terraform module does not alter that workflow.

## Create, reference, and import examples

To reference an existing registry, keep `acr_mode = "reference"`. To create a registry after confirming no matching registry exists, set `acr_mode = "create"` and review the plan.

To manage an existing registry instead of referencing it, first set `acr_mode = "create"` so the resource block is declared, configure remote state, then explicitly import its full Azure resource ID. For example:

```powershell
terraform -chdir=terraform import 'azurerm_container_registry.this[0]' <ACR_RESOURCE_ID>
```

Equivalent resource addresses for optional create resources are:

```text
azurerm_log_analytics_workspace.this[0]
azurerm_container_app_environment.this[0]
azurerm_user_assigned_identity.this[0]
azurerm_container_app.this[0]
```

Import each only if the corresponding object should be owned by this state. Importing changes Terraform state, not the Azure resource, but it can affect future plans. Inspect the resulting plan before any apply.

## Remote state

The `azurerm` backend is declared but does not create a storage account. For shared or production use, provide an **existing** storage account and private blob container, preferably with blob versioning and soft delete enabled. Initialize with non-secret backend identifiers, for example:

```powershell
terraform -chdir=terraform init `
  -backend-config="resource_group_name=<STATE_RESOURCE_GROUP>" `
  -backend-config="storage_account_name=<EXISTING_STORAGE_ACCOUNT>" `
  -backend-config="container_name=<PRIVATE_STATE_CONTAINER>" `
  -backend-config="key=secureops/dev.tfstate" `
  -backend-config="use_azuread_auth=true"
```

Use Entra ID/OIDC for the blob data plane and grant the Terraform identity only the necessary Storage Blob Data access at the state container. Do not use storage account keys or SAS tokens in backend arguments. Restrict storage network access as appropriate, while ensuring the chosen runner can reach it. Never commit state, plan, backend credential files, or real tfvars files.

Do not run `terraform init -migrate-state` until the destination backend is verified and the existing state has been backed up securely.

## Deployment and cost

Terraform manages infrastructure only. It does not run `terraform apply`, build or push the app image, or deploy the application. After an approved infrastructure plan is applied by an authorized operator, an image publishing/deployment workflow can be designed separately.

ACR Basic is a cost-oriented option for a small development registry, but has lower throughput/storage and does not provide Premium private endpoints. Container Apps Consumption can scale to zero; min replicas of zero reduces idle compute costs at the expense of cold starts. Log Analytics charges depend on ingestion and retention. Network egress, additional registry storage, and remote-state storage can also add cost. Check the Azure pricing calculator for the actual subscription, region, and usage before provisioning. An Azure budget is an alert, not a spending cap.
