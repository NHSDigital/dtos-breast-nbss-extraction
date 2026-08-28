variable "app_short_name" {
  description = "Application short name (6 characters)"
  type        = string
}

variable "env_config"{
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
}

variable "hub_subscription_id"{
  description = "Subscription ID of the hub"
  type        = string
}

variable "arm_subscription_id" {
  description = "Subscription ID of the application ARM subscription"
  type        = string
}
