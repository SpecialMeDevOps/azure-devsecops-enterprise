variable "subscription_id" {
  description = "Azure subscription ID. This is an identifier, not a credential."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the existing resource group that contains this deployment."
  type        = string
  default     = "rg-secureops-dev"
}

variable "location" {
  description = "Azure region for resources created by this configuration."
  type        = string
  default     = "Central India"
}

variable "tags" {
  description = "Tags applied to resources created by this configuration."
  type        = map(string)
  default = {
    application = "secureops-api"
    environment = "development"
    managed_by  = "terraform"
  }
}

variable "acr_mode" {
  description = "Whether to create a registry or reference an existing one. Importing is a separate manual operation."
  type        = string
  default     = "reference"

  validation {
    condition     = contains(["create", "reference"], var.acr_mode)
    error_message = "acr_mode must be either create or reference."
  }
}

variable "acr_name" {
  description = "Globally unique name of the Azure Container Registry."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.acr_name))
    error_message = "acr_name must contain 5 to 50 alphanumeric characters."
  }
}

variable "acr_sku" {
  description = "SKU used only when creating the registry. Basic is appropriate for low-volume development workloads."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be Basic, Standard, or Premium."
  }
}

variable "log_analytics_workspace_mode" {
  description = "Whether to create a workspace or reference an existing one. Importing is a separate manual operation."
  type        = string
  default     = "reference"

  validation {
    condition     = contains(["create", "reference"], var.log_analytics_workspace_mode)
    error_message = "log_analytics_workspace_mode must be either create or reference."
  }
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace."
  type        = string
  default     = "law-secureops-dev"
}

variable "log_retention_in_days" {
  description = "Workspace data retention in days. Longer retention can increase costs."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_in_days >= 30 && var.log_retention_in_days <= 730
    error_message = "log_retention_in_days must be between 30 and 730."
  }
}

variable "container_apps_environment_mode" {
  description = "Whether to create a Container Apps Environment or reference an existing one."
  type        = string
  default     = "reference"

  validation {
    condition     = contains(["create", "reference"], var.container_apps_environment_mode)
    error_message = "container_apps_environment_mode must be either create or reference."
  }
}

variable "container_apps_environment_name" {
  description = "Name of the Azure Container Apps Environment."
  type        = string
  default     = "cae-secureops-dev"
}

variable "managed_identity_mode" {
  description = "Whether to create a user-assigned identity or reference an existing one."
  type        = string
  default     = "reference"

  validation {
    condition     = contains(["create", "reference"], var.managed_identity_mode)
    error_message = "managed_identity_mode must be either create or reference."
  }
}

variable "managed_identity_name" {
  description = "Name of the user-assigned managed identity used for image pulls."
  type        = string
  default     = "id-secureops-api"
}

variable "manage_acr_pull_role_assignment" {
  description = "Create or manage the AcrPull assignment only after confirming an equivalent assignment is absent or importing it."
  type        = bool
  default     = false
}

variable "existing_acr_pull_assignment_confirmed" {
  description = "Set true only after verifying that the managed identity already has the required registry-scoped image-pull role."
  type        = bool
  default     = false
}

variable "container_app_mode" {
  description = "Whether to create the Container App or reference an existing one. Importing is a separate manual operation."
  type        = string
  default     = "reference"

  validation {
    condition     = contains(["create", "reference"], var.container_app_mode)
    error_message = "container_app_mode must be either create or reference."
  }
}

variable "container_app_name" {
  description = "Name of the Azure Container App."
  type        = string
  default     = "ca-secureops-api"
}

variable "container_image" {
  description = "Existing image in ACR, preferably pinned by digest (for example registry.azurecr.io/secureops-api@sha256:<digest>)."
  type        = string
  default     = ""
}

variable "external_ingress_enabled" {
  description = "Expose the app through the Container Apps HTTPS ingress. Keep false unless public access is explicitly intended."
  type        = bool
  default     = false
}

variable "container_port" {
  description = "Internal port listened to by the SecureOps API container."
  type        = number
  default     = 8000

  validation {
    condition     = var.container_port == 8000
    error_message = "The SecureOps API container target port must remain 8000."
  }
}

variable "container_cpu" {
  description = "CPU cores allocated to each replica. 0.25 is a cost-conscious starting point."
  type        = number
  default     = 0.25

  validation {
    condition     = var.container_cpu >= 0.25
    error_message = "container_cpu must be at least 0.25."
  }
}

variable "container_memory" {
  description = "Memory allocated to each replica. This value must be compatible with container_cpu."
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "Minimum replica count. Zero enables scale-to-zero for development but can introduce cold starts."
  type        = number
  default     = 0

  validation {
    condition     = var.min_replicas >= 0 && var.min_replicas <= 25
    error_message = "min_replicas must be between 0 and 25."
  }
}

variable "max_replicas" {
  description = "Maximum replica count used by the HTTP scaling rule."
  type        = number
  default     = 2

  validation {
    condition     = var.max_replicas >= 1 && var.max_replicas <= 25
    error_message = "max_replicas must be between 1 and 25."
  }
}

variable "http_concurrent_requests" {
  description = "Concurrent requests per replica before Container Apps scales out."
  type        = number
  default     = 50

  validation {
    condition     = var.http_concurrent_requests >= 1
    error_message = "http_concurrent_requests must be at least 1."
  }
}

variable "probe_initial_delay_seconds" {
  description = "Initial delay before each HTTP health probe begins."
  type        = number
  default     = 10

  validation {
    condition     = var.probe_initial_delay_seconds >= 0 && var.probe_initial_delay_seconds <= 60
    error_message = "probe_initial_delay_seconds must be between 0 and 60."
  }
}

variable "probe_period_seconds" {
  description = "Interval between consecutive HTTP health probes."
  type        = number
  default     = 10

  validation {
    condition     = var.probe_period_seconds >= 1 && var.probe_period_seconds <= 240
    error_message = "probe_period_seconds must be between 1 and 240."
  }
}

variable "probe_timeout_seconds" {
  description = "Timeout for each HTTP health probe."
  type        = number
  default     = 3

  validation {
    condition     = var.probe_timeout_seconds >= 1 && var.probe_timeout_seconds <= 240
    error_message = "probe_timeout_seconds must be between 1 and 240."
  }
}
