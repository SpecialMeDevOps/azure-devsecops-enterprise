data "azurerm_resource_group" "target" {
  name = var.resource_group_name
}

data "azurerm_container_registry" "existing" {
  count = var.acr_mode == "reference" ? 1 : 0

  name                = var.acr_name
  resource_group_name = data.azurerm_resource_group.target.name
}

resource "azurerm_container_registry" "this" {
  count = var.acr_mode == "create" ? 1 : 0

  name                = var.acr_name
  resource_group_name = data.azurerm_resource_group.target.name
  location            = var.location
  sku                 = var.acr_sku
  admin_enabled       = false
  tags                = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

data "azurerm_log_analytics_workspace" "existing" {
  count = var.log_analytics_workspace_mode == "reference" ? 1 : 0

  name                = var.log_analytics_workspace_name
  resource_group_name = data.azurerm_resource_group.target.name
}

resource "azurerm_log_analytics_workspace" "this" {
  count = var.log_analytics_workspace_mode == "create" ? 1 : 0

  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.target.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_in_days
  tags                = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

data "azurerm_container_app_environment" "existing" {
  count = var.container_apps_environment_mode == "reference" ? 1 : 0

  name                = var.container_apps_environment_name
  resource_group_name = data.azurerm_resource_group.target.name
}

resource "azurerm_container_app_environment" "this" {
  count = var.container_apps_environment_mode == "create" ? 1 : 0

  name                       = var.container_apps_environment_name
  location                   = var.location
  resource_group_name        = data.azurerm_resource_group.target.name
  log_analytics_workspace_id = local.log_analytics_workspace_id
  tags                       = var.tags
}

data "azurerm_user_assigned_identity" "existing" {
  count = var.managed_identity_mode == "reference" ? 1 : 0

  name                = var.managed_identity_name
  resource_group_name = data.azurerm_resource_group.target.name
}

resource "azurerm_user_assigned_identity" "this" {
  count = var.managed_identity_mode == "create" ? 1 : 0

  name                = var.managed_identity_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.target.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  count = var.manage_acr_pull_role_assignment ? 1 : 0

  scope                = local.acr_id
  role_definition_name = "AcrPull"
  principal_id         = local.managed_identity_principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [
    azurerm_user_assigned_identity.this,
    azurerm_container_registry.this,
  ]
}

data "azurerm_container_app" "existing" {
  count = var.container_app_mode == "reference" ? 1 : 0

  name                = var.container_app_name
  resource_group_name = data.azurerm_resource_group.target.name
}

resource "azurerm_container_app" "this" {
  count = var.container_app_mode == "create" ? 1 : 0

  name                         = var.container_app_name
  resource_group_name          = data.azurerm_resource_group.target.name
  container_app_environment_id = local.container_apps_environment_id
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [local.managed_identity_id]
  }

  registry {
    server   = local.acr_login_server
    identity = local.managed_identity_id
  }

  ingress {
    external_enabled           = var.external_ingress_enabled
    target_port                = var.container_port
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "secureops-api"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "SECUREOPS_ENVIRONMENT"
        value = "production"
      }

      env {
        name  = "SECUREOPS_LOG_LEVEL"
        value = "INFO"
      }

      startup_probe {
        initial_delay           = var.probe_initial_delay_seconds
        interval_seconds        = var.probe_period_seconds
        timeout                 = var.probe_timeout_seconds
        failure_count_threshold = 10
        path                    = "/health"
        port                    = var.container_port
        transport               = "HTTP"
      }

      readiness_probe {
        initial_delay           = var.probe_initial_delay_seconds
        interval_seconds        = var.probe_period_seconds
        timeout                 = var.probe_timeout_seconds
        failure_count_threshold = 3
        path                    = "/health"
        port                    = var.container_port
        transport               = "HTTP"
      }

      liveness_probe {
        initial_delay           = var.probe_initial_delay_seconds
        interval_seconds        = var.probe_period_seconds
        timeout                 = var.probe_timeout_seconds
        failure_count_threshold = 3
        path                    = "/health"
        port                    = var.container_port
        transport               = "HTTP"
      }
    }

    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = tostring(var.http_concurrent_requests)
    }
  }

  lifecycle {
    precondition {
      condition     = trimspace(var.container_image) != ""
      error_message = "container_image must identify an image that already exists in ACR."
    }

    precondition {
      condition     = !local.acr_admin_enabled
      error_message = "The selected ACR has its admin account enabled. Disable it before creating this Container App."
    }

    precondition {
      condition     = var.manage_acr_pull_role_assignment || var.existing_acr_pull_assignment_confirmed
      error_message = "Before creating the Container App, either manage the AcrPull assignment or confirm an equivalent assignment already exists."
    }

    precondition {
      condition     = var.min_replicas <= var.max_replicas
      error_message = "min_replicas must not exceed max_replicas."
    }

    precondition {
      condition     = var.probe_timeout_seconds <= var.probe_period_seconds
      error_message = "probe_timeout_seconds must not exceed probe_period_seconds."
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
  ]
}

locals {
  acr_id = var.acr_mode == "create" ? (
    azurerm_container_registry.this[0].id
    ) : (
    data.azurerm_container_registry.existing[0].id
  )

  acr_login_server = var.acr_mode == "create" ? (
    azurerm_container_registry.this[0].login_server
    ) : (
    data.azurerm_container_registry.existing[0].login_server
  )

  acr_admin_enabled = var.acr_mode == "create" ? (
    azurerm_container_registry.this[0].admin_enabled
    ) : (
    data.azurerm_container_registry.existing[0].admin_enabled
  )

  log_analytics_workspace_id = var.log_analytics_workspace_mode == "create" ? (
    azurerm_log_analytics_workspace.this[0].id
    ) : (
    data.azurerm_log_analytics_workspace.existing[0].id
  )

  container_apps_environment_id = var.container_apps_environment_mode == "create" ? (
    azurerm_container_app_environment.this[0].id
    ) : (
    data.azurerm_container_app_environment.existing[0].id
  )

  managed_identity_id = var.managed_identity_mode == "create" ? (
    azurerm_user_assigned_identity.this[0].id
    ) : (
    data.azurerm_user_assigned_identity.existing[0].id
  )

  managed_identity_principal_id = var.managed_identity_mode == "create" ? (
    azurerm_user_assigned_identity.this[0].principal_id
    ) : (
    data.azurerm_user_assigned_identity.existing[0].principal_id
  )
}
