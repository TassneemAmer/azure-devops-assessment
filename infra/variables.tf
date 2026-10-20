variable "subscription_id" {
  description = "Azure subscription ID used for this assessment deployment."
  type        = string
}

variable "location" {
  description = "Azure region for the assessment resources."
  type        = string
  default     = "westeurope"
}

variable "project_name" {
  description = "Short lowercase project name used in resource names."
  type        = string
  default     = "azassessment"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.project_name))
    error_message = "project_name must be 3-12 lowercase letters or numbers and start with a letter."
  }
}

variable "environment" {
  description = "Deployment environment label used in names and tags."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.environment))
    error_message = "environment must be 2-8 lowercase letters or numbers."
  }
}

variable "db_admin_login" {
  description = "Administrator login for PostgreSQL Flexible Server."
  type        = string
  default     = "assessmentadmin"
}

variable "db_admin_password" {
  description = "Administrator password for PostgreSQL. Supply via TF_VAR_db_admin_password; do not commit it."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_admin_password) >= 16
    error_message = "db_admin_password must be at least 16 characters."
  }
}

variable "tags" {
  description = "Tags applied to Azure resources."
  type        = map(string)
  default = {
    assessment = "cloud-devops"
    managed_by = "terraform"
  }
}
