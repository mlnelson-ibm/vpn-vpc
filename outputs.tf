########################################################################################################################
# Outputs
########################################################################################################################

########################################################################################################################
# Resource Group Outputs
########################################################################################################################

output "resource_group_name" {
  description = "Name of the resource group containing all resources"
  value       = module.resource_group.resource_group_name
}

output "resource_group_id" {
  description = "ID of the resource group containing all resources"
  value       = module.resource_group.resource_group_id
}

########################################################################################################################
# Secrets Manager Outputs
########################################################################################################################

output "secrets_manager_id" {
  description = "ID of the Secrets Manager instance"
  value       = module.secrets_manager.secrets_manager_id
}

output "secrets_manager_guid" {
  description = "GUID of the Secrets Manager instance"
  value       = module.secrets_manager.secrets_manager_guid
}

output "secrets_manager_crn" {
  description = "CRN of the Secrets Manager instance"
  value       = module.secrets_manager.secrets_manager_crn
}

########################################################################################################################
# Certificate Outputs
########################################################################################################################

output "vpn_server_certificate_id" {
  description = "ID of the VPN server certificate in Secrets Manager"
  value       = module.vpn_server_certificate.secret_id
}

output "vpn_server_certificate_crn" {
  description = "CRN of the VPN server certificate in Secrets Manager"
  value       = module.vpn_server_certificate.secret_crn
}

output "vpn_client_certificate_id" {
  description = "ID of the VPN client certificate in Secrets Manager"
  value       = module.vpn_client_certificate.secret_id
}

output "vpn_client_certificate_crn" {
  description = "CRN of the VPN client certificate in Secrets Manager"
  value       = module.vpn_client_certificate.secret_crn
}

output "certificate_template_name" {
  description = "Name of the certificate template used for VPN certificates"
  value       = module.private_cert_engine.template_name
}

########################################################################################################################
# VPC Outputs
########################################################################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = module.vpc.vpc_name
}

output "vpc_crn" {
  description = "CRN of the VPC"
  value       = module.vpc.vpc_crn
}

output "subnet_ids" {
  description = "List of all subnet IDs in the VPC"
  value       = module.vpc.subnet_ids
}

output "subnet_details" {
  description = "Detailed information about all subnets"
  value       = module.vpc.subnet_detail_list
}

########################################################################################################################
# VPN Server Outputs
########################################################################################################################

output "vpn_server_id" {
  description = "ID of the client-to-site VPN server"
  value       = module.client_to_site_vpn.vpn_server_id
}

output "vpn_server_name" {
  description = "Name of the VPN server"
  value       = "${var.prefix}-c2s-vpn"
}

output "vpn_client_ip_pool" {
  description = "IP address pool assigned to VPN clients"
  value       = var.vpn_client_ip_pool
}

########################################################################################################################
# VPN Client Configuration
########################################################################################################################

output "vpn_client_profile_download_command" {
  description = "IBM Cloud CLI command to download the VPN client profile (.ovpn file)"
  value       = "ibmcloud is vpn-server-client-configuration ${module.client_to_site_vpn.vpn_server_id} --file ${var.prefix}-client-profile.ovpn"
}

output "vpn_access_instructions" {
  description = "Instructions for accessing the VPN"
  value = <<-EOT
    
    ╔════════════════════════════════════════════════════════════════════════════════╗
    ║                    VPN CLIENT SETUP INSTRUCTIONS                               ║
    ╚════════════════════════════════════════════════════════════════════════════════╝
    
    1. DOWNLOAD VPN CLIENT PROFILE:
       Run the following command to download your VPN client configuration:
       
       ibmcloud login --apikey <your-api-key>
       ibmcloud is vpn-server-client-configuration ${module.client_to_site_vpn.vpn_server_id} --file ${var.prefix}-client-profile.ovpn
    
    2. INSTALL OPENVPN CLIENT:
       - macOS: Download from https://openvpn.net/client/
       - Windows: Download from https://openvpn.net/client/
       - Linux: sudo apt-get install openvpn (Ubuntu/Debian)
    
    3. IMPORT PROFILE:
       - Open your OpenVPN client
       - Import the downloaded ${var.prefix}-client-profile.ovpn file
    
    4. CONNECT:
       - Click Connect in your OpenVPN client
       - Authenticate with your IBM Cloud IAM credentials:
         Username: Your IBM Cloud email address
         Password: Your IBM Cloud password (or API key)
    
    5. VERIFY CONNECTION:
       Once connected, you should be able to access resources in the VPC network:
       ${var.vpc_address_prefix}
    
    ╔════════════════════════════════════════════════════════════════════════════════╗
    ║                         IMPORTANT NOTES                                        ║
    ╚════════════════════════════════════════════════════════════════════════════════╝
    
    • VPN Server ID: ${module.client_to_site_vpn.vpn_server_id}
    • VPN Client IP Pool: ${var.vpn_client_ip_pool}
    • VPC Network: ${var.vpc_address_prefix}
    • Region: ${var.region}
    • High Availability: Enabled (2 zones)
    
    For troubleshooting, visit:
    https://cloud.ibm.com/docs/vpc?topic=vpc-vpn-client-to-site-overview
    
  EOT
}

########################################################################################################################
# Summary Output
########################################################################################################################

output "deployment_summary" {
  description = "Summary of all deployed resources"
  value = {
    resource_group = {
      name = module.resource_group.resource_group_name
      id   = module.resource_group.resource_group_id
    }
    secrets_manager = {
      name = "${var.prefix}-secrets-manager"
      id   = module.secrets_manager.secrets_manager_id
      guid = module.secrets_manager.secrets_manager_guid
    }
    vpc = {
      name        = module.vpc.vpc_name
      id          = module.vpc.vpc_id
      cidr        = var.vpc_address_prefix
      subnet_count = length(module.vpc.subnet_ids)
    }
    vpn_server = {
      name            = "${var.prefix}-c2s-vpn"
      id              = module.client_to_site_vpn.vpn_server_id
      client_ip_pool  = var.vpn_client_ip_pool
      protocol        = var.vpn_protocol
      high_availability = true
    }
  }
}