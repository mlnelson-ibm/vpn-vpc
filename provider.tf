########################################################################################################################
# Provider Configuration
########################################################################################################################

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

# Separate provider for Secrets Manager operations
provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
  alias            = "ibm-sm"
}