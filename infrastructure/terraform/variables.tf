variable "app_short_name" {
  description = "Application short name (6 characters)"
  type        = string
}

variable "env_config" {
  description = "Environment configuration file name"
  type        = string
}

variable "environment" {
  description = "Application environment name"
  type        = string
}

variable "hub" {
  description = "Hub name (dev or prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.hub)
    error_message = "Hub must be either 'dev' or 'prod'"
  }
}

variable "hub_subscription_id" {
  description = "Subscription ID of the hub"
  type        = string
}

variable "arm_subscription_id" {
  description = "Subscription ID of the application ARM subscription"
  type        = string
}

# defender for storage variables

variable "override_subscription_settings_enabled" {
  description = "Override subscription level settings for Microsoft Defender for Storage"
  type        = bool
  default     = true
}

variable "malware_scanning_on_upload_enabled" {
  description = "Enable malware scanning on upload for Microsoft Defender for Storage"
  type        = bool
  default     = false
}

variable "malware_scanning_on_upload_cap_gb_per_month" {
  description = "Cap for malware scanning on upload in GB per month for Microsoft Defender for Storage"
  type        = number
  default     = 5000
}

variable "sensitive_data_discovery_enabled" {
  description = "Enable sensitive data discovery for Microsoft Defender for Storage"
  type        = bool
  default     = true
}

variable "scan_is_enabled" {
  description = "Enable Microsoft Defender for Storage scanning"
  type        = bool
  default     = true
}

variable "storage_blob_private_dns_zone_name" {
  description = "Private DNS zone name for storage blob private endpoints"
  type        = string
  default     = "privatelink.blob.core.windows.net"
}
