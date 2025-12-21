# iac/variables.tf
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "app-grp"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "northeurope"
}

variable "vnet_cidr" {
  description = "VNet CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "web_subnet_cidr" {
  description = "Web subnet CIDR"
  type        = string
  default     = "10.0.0.0/24"
}

variable "gateway_subnet_cidr" {
  description = "Gateway subnet CIDR (must be /27 or larger)"
  type        = string
  default     = "10.0.1.0/27"
}
