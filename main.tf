########################################################################################################################
# Resource Group
########################################################################################################################

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.4.7"

  resource_group_name = "${var.prefix}-resource-group"
}

########################################################################################################################
# Secrets Manager Instance
########################################################################################################################

module "secrets_manager" {
  source  = "terraform-ibm-modules/secrets-manager/ibm"
  version = "2.13.1"

  resource_group_id     = module.resource_group.resource_group_id
  region                = var.region
  secrets_manager_name  = "${var.prefix}-secrets-manager"
  sm_service_plan       = "standard"
  sm_tags               = var.resource_tags

  providers = {
    ibm = ibm.ibm-sm
  }
}

########################################################################################################################
# Private Certificate Engine Configuration
########################################################################################################################

module "private_cert_engine" {
  source  = "terraform-ibm-modules/secrets-manager-private-cert-engine/ibm"
  version = "1.13.0"

  secrets_manager_guid        = module.secrets_manager.secrets_manager_guid
  region                      = var.region
  root_ca_name                = "${var.prefix}-root-ca"
  root_ca_common_name         = "Root CA - ${var.certificate_common_name}"
  root_ca_max_ttl             = var.root_ca_max_ttl
  intermediate_ca_name        = "${var.prefix}-intermediate-ca"
  intermediate_ca_common_name = "Intermediate CA - ${var.certificate_common_name}"
  intermediate_ca_max_ttl     = var.intermediate_ca_max_ttl
  certificate_template_name   = "${var.prefix}-cert-template"
  template_max_ttl            = var.certificate_template_max_ttl
  template_allow_any_name     = true
  template_allow_subdomains   = true

  providers = {
    ibm = ibm.ibm-sm
  }

  depends_on = [module.secrets_manager]
}

########################################################################################################################
# Secret Group for VPN Certificates
########################################################################################################################

module "secrets_manager_group" {
  source  = "terraform-ibm-modules/secrets-manager-secret-group/ibm"
  version = "1.4.2"

  region                   = var.region
  secrets_manager_guid     = module.secrets_manager.secrets_manager_guid
  secret_group_name        = "${var.prefix}-certs"
  secret_group_description = "Secret group for VPN server certificates"

  providers = {
    ibm = ibm.ibm-sm
  }

  depends_on = [module.secrets_manager]
}

########################################################################################################################
# Private Certificate for VPN Server
########################################################################################################################

module "vpn_server_certificate" {
  source  = "terraform-ibm-modules/secrets-manager-private-cert/ibm"
  version = "1.11.0"

  cert_name              = "${var.prefix}-server-cert"
  cert_description       = "Private certificate for VPN server authentication"
  cert_template          = module.private_cert_engine.template_name
  cert_secrets_group_id  = module.secrets_manager_group.secret_group_id
  cert_common_name       = var.certificate_common_name
  secrets_manager_guid   = module.secrets_manager.secrets_manager_guid
  secrets_manager_region = var.region

  providers = {
    ibm = ibm.ibm-sm
  }

  depends_on = [module.private_cert_engine, module.secrets_manager_group]
}

########################################################################################################################
# Private Certificate for VPN Client Authentication
########################################################################################################################

module "vpn_client_certificate" {
  source  = "terraform-ibm-modules/secrets-manager-private-cert/ibm"
  version = "1.11.0"

  cert_name              = "${var.prefix}-client-cert"
  cert_description       = "Private certificate for VPN client authentication"
  cert_template          = module.private_cert_engine.template_name
  cert_secrets_group_id  = module.secrets_manager_group.secret_group_id
  cert_common_name       = "vpn-client.${var.certificate_common_name}"
  secrets_manager_guid   = module.secrets_manager.secrets_manager_guid
  secrets_manager_region = var.region

  providers = {
    ibm = ibm.ibm-sm
  }

  depends_on = [module.private_cert_engine, module.secrets_manager_group]
}

########################################################################################################################
# Intermediate CA Certificate (imported as secret for VPN client_ca)
# The VPN server needs the CA certificate that signs client certificates
########################################################################################################################

resource "ibm_sm_imported_certificate" "intermediate_ca_cert" {
  instance_id   = module.secrets_manager.secrets_manager_guid
  region        = var.region
  name          = "${var.prefix}-intermediate-ca-cert"
  description   = "Intermediate CA certificate for VPN client authentication"
  secret_group_id = module.secrets_manager_group.secret_group_id
  
  certificate = data.ibm_sm_private_certificate_configuration_intermediate_ca.intermediate_ca.data[0].certificate
  intermediate = data.ibm_sm_private_certificate_configuration_root_ca.root_ca.data[0].certificate
}

data "ibm_sm_private_certificate_configuration_intermediate_ca" "intermediate_ca" {
  instance_id = module.secrets_manager.secrets_manager_guid
  region      = var.region
  name        = "${var.prefix}-intermediate-ca"
}

data "ibm_sm_private_certificate_configuration_root_ca" "root_ca" {
  instance_id = module.secrets_manager.secrets_manager_guid
  region      = var.region
  name        = "${var.prefix}-root-ca"
}

########################################################################################################################
# VPC Infrastructure
########################################################################################################################

module "vpc" {
  source  = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version = "8.13.2"

  resource_group_id    = module.resource_group.resource_group_id
  region               = var.region
  name                 = "vpc"
  prefix               = var.prefix
  tags                 = var.resource_tags
  enable_vpc_flow_logs = false

  # Address prefix for the VPC - using the full /20 range split across zones
  address_prefixes = {
    zone-1 = ["10.10.0.0/22"]   # 10.10.0.0 - 10.10.3.255 (1,024 IPs)
    zone-2 = ["10.10.4.0/22"]   # 10.10.4.0 - 10.10.7.255 (1,024 IPs)
    zone-3 = ["10.10.8.0/22"]   # 10.10.8.0 - 10.10.11.255 (1,024 IPs)
  }

  # Public gateways for internet access
  use_public_gateways = {
    zone-1 = true
    zone-2 = true
    zone-3 = false
  }

  # Subnets across 3 availability zones for high availability
  subnets = {
    zone-1 = [
      {
        name           = "subnet-1"
        cidr           = "10.10.0.0/24"   # Within zone-1 prefix 10.10.0.0/22
        public_gateway = true
        acl_name       = "acl"
      }
    ]
    zone-2 = [
      {
        name           = "subnet-2"
        cidr           = "10.10.4.0/24"   # Within zone-2 prefix 10.10.4.0/22
        public_gateway = true
        acl_name       = "acl"
      }
    ]
    zone-3 = [
      {
        name           = "subnet-3"
        cidr           = "10.10.8.0/24"   # Within zone-3 prefix 10.10.8.0/22
        public_gateway = false
        acl_name       = "acl"
      }
    ]
  }

  # Network ACL configuration
  network_acls = [
    {
      name                         = "acl"
      add_ibm_cloud_internal_rules = true
      add_vpc_connectivity_rules   = true
      prepend_ibm_rules            = true
      rules                        = []
    }
  ]
}

# Data source to get VPC details after creation
data "ibm_is_vpc" "vpc" {
  depends_on = [module.vpc]
  identifier = module.vpc.vpc_id
}

########################################################################################################################
# Security Group Rule for VPN Client Access
########################################################################################################################

# Get VPN server details to find its security group
data "ibm_is_vpn_server" "vpn_server" {
  depends_on = [module.client_to_site_vpn]
  identifier = module.client_to_site_vpn.vpn_server_id
}

# Add security group rule to allow VPN clients to connect (UDP 443 from anywhere)
resource "ibm_is_security_group_rule" "vpn_client_inbound" {
  group     = data.ibm_is_vpn_server.vpn_server.security_groups[0].id
  direction = "inbound"
  remote    = "0.0.0.0/0"

  udp {
    port_min = 443
    port_max = 443
  }

  depends_on = [module.client_to_site_vpn]
}

########################################################################################################################
# Workaround: Update VPN Server with Certificate
# The module creates the VPN server but doesn't properly attach the server certificate
# This null_resource ensures the certificate is attached after creation
########################################################################################################################

resource "null_resource" "update_vpn_server_certificate" {
  triggers = {
    vpn_server_id = module.client_to_site_vpn.vpn_server_id
    cert_crn      = module.vpn_server_certificate.secret_crn
  }

  provisioner "local-exec" {
    command = <<-EOT
      ibmcloud is vpn-server-update ${module.client_to_site_vpn.vpn_server_id} \
        --cert "${module.vpn_server_certificate.secret_crn}"
    EOT
  }

  depends_on = [
    module.client_to_site_vpn,
    module.vpn_server_certificate
  ]
}

########################################################################################################################
# Client-to-Site VPN Server (High Availability)
########################################################################################################################

module "client_to_site_vpn" {
  source  = "terraform-ibm-modules/client-to-site-vpn/ibm"
  version = "3.5.6"

  vpn_gateway_name              = "${var.prefix}-c2s-vpn"
  resource_group_id             = module.resource_group.resource_group_id
  server_cert_crn               = module.vpn_server_certificate.secret_crn
  
  # High Availability: Use first 2 subnets across different zones
  subnet_ids                    = slice([for subnet in data.ibm_is_vpc.vpc.subnets : subnet["id"]], 0, 2)
  
  # VPN client configuration
  client_ip_pool                = var.vpn_client_ip_pool
  protocol                      = var.vpn_protocol
  client_idle_timeout           = var.vpn_client_idle_timeout
  enable_split_tunneling        = true
  
  # Authentication configuration - CERTIFICATE-BASED ONLY
  enable_username_auth          = false
  enable_certificate_auth       = true
  client_cert_crns              = [ibm_sm_imported_certificate.intermediate_ca_cert.crn]
  
  # IAM access group for VPN users (still needed for authorization)
  create_policy                 = var.create_vpn_access_policy
  access_group_name             = "${var.prefix}-access-group"
  vpn_client_access_group_users = var.vpn_client_access_group_users
  
  # VPN server routes - route VPC traffic through VPN
  vpn_server_routes = {
    "vpc-network" = {
      destination = var.vpc_address_prefix
      action      = "deliver"
    }
  }

  # Skip creating IAM authorization policy if it already exists
  skip_secrets_manager_iam_auth_policy = false

  depends_on = [module.vpc, module.vpn_server_certificate, module.vpn_client_certificate]
}