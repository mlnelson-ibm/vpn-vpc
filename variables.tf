########################################################################################################################
# Input Variables
########################################################################################################################

variable "ibmcloud_api_key" {
  type        = string
  description = "IBM Cloud API key for authentication. This key is used to provision all resources."
  sensitive   = true
}

variable "region" {
  type        = string
  description = "IBM Cloud region where all resources will be provisioned."
  default     = "us-south"
}

variable "prefix" {
  type        = string
  description = "Prefix to be added to all resource names for easy identification."
  default     = "vpn-vpc"
}

variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to all created resources."
  default     = []
}

########################################################################################################################
# VPC Configuration
########################################################################################################################

variable "vpc_address_prefix" {
  type        = string
  description = "CIDR block for the VPC address prefix. Must not overlap with vpn_client_ip_pool."
  default     = "10.10.0.0/20"
}

########################################################################################################################
# VPN Configuration
########################################################################################################################

variable "vpn_client_ip_pool" {
  type        = string
  description = "CIDR block for VPN client IP addresses. Must not overlap with VPC CIDR or other networks."
  default     = "10.0.0.0/20"
}

variable "vpn_client_access_group_users" {
  type        = list(string)
  description = "List of IBM Cloud IAM user email addresses to grant VPN access. Users must exist in the account."
  default     = []
}

variable "create_vpn_access_policy" {
  type        = bool
  description = "Set to true to create an IAM access group with VPN Client role for the users specified in vpn_client_access_group_users."
  default     = true
}

variable "vpn_protocol" {
  type        = string
  description = "Transport protocol for the VPN server. Valid values: 'udp' or 'tcp'."
  default     = "udp"
  validation {
    condition     = contains(["udp", "tcp"], var.vpn_protocol)
    error_message = "VPN protocol must be either 'udp' or 'tcp'."
  }
}

variable "vpn_client_idle_timeout" {
  type        = number
  description = "Seconds a VPN client can be idle before disconnection. Set to 0 to disable timeout."
  default     = 1800
}

########################################################################################################################
# Certificate Configuration
########################################################################################################################

variable "certificate_common_name" {
  type        = string
  description = "Common name (CN) for the VPN server certificate. Typically a domain name."
  default     = "vpn.example.com"
}

variable "root_ca_max_ttl" {
  type        = string
  description = "Maximum time-to-live for the root CA certificate."
  default     = "87600h"
}

variable "intermediate_ca_max_ttl" {
  type        = string
  description = "Maximum time-to-live for the intermediate CA certificate."
  default     = "26300h"
}

variable "certificate_template_max_ttl" {
  type        = string
  description = "Maximum time-to-live for certificates issued from the template."
  default     = "8760h"
}