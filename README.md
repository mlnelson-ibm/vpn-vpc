# IBM Cloud VPC with Client-to-Site VPN - Terraform Configuration

This Terraform configuration creates a complete High Availability (HA) Client-to-Site VPN infrastructure on IBM Cloud, enabling secure remote access to a Virtual Private Cloud (VPC) in the us-south region.

## 🏗️ Architecture Overview

This solution deploys:

- **Resource Group**: Organizes all resources under a single group
- **Secrets Manager**: Stores VPN certificates securely with private certificate engine
- **VPC**: Virtual Private Cloud with 10.10.0.0/20 CIDR block
- **Subnets**: 3 subnets across 3 availability zones (us-south-1, us-south-2, us-south-3)
- **Client-to-Site VPN**: High availability VPN server spanning 2 zones
- **IAM Access Group**: Controls VPN user access

### Network Design

```
┌─────────────────────────────────────────────────────────────────┐
│                    IBM Cloud - us-south Region                  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              VPC (10.10.0.0/20)                           │ │
│  │                                                           │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │ │
│  │  │   Zone 1     │  │   Zone 2     │  │   Zone 3     │  │ │
│  │  │ 10.10.0.0/24 │  │ 10.10.1.0/24 │  │ 10.10.2.0/24 │  │ │
│  │  │              │  │              │  │              │  │ │
│  │  │  VPN Server  │  │  VPN Server  │  │   Reserved   │  │ │
│  │  │   (Active)   │  │   (Active)   │  │              │  │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │ │
│  │                                                           │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  VPN Clients: 10.0.0.0/20 (4,096 IP addresses)                │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

Before you begin, ensure you have:

1. **IBM Cloud Account** with appropriate permissions
2. **IBM Cloud CLI** installed ([Installation Guide](https://cloud.ibm.com/docs/cli?topic=cli-getting-started))
3. **Terraform** >= 1.9.0 installed ([Download](https://www.terraform.io/downloads))
4. **IBM Cloud API Key** ([Create API Key](https://cloud.ibm.com/iam/apikeys))

### Required IBM Cloud Permissions

Your API key must have the following permissions:
- Create and manage Resource Groups
- Create and manage VPC resources
- Create and manage Secrets Manager instances
- Create and manage IAM access groups and policies

## 🚀 Quick Start

### Step 1: Clone or Download This Configuration

```bash
# If you have this as a repository
git clone <repository-url>
cd vpn-vpc-terraform

# Or if you created the files manually, navigate to the directory
cd vpn-vpc-terraform
```

### Step 2: Configure Variables

Copy the template and add your IBM Cloud API key:

```bash
cp terraform.tfvars.template terraform.tfvars
```

Edit `terraform.tfvars` and set your API key:

```hcl
ibmcloud_api_key = "YOUR_IBM_CLOUD_API_KEY_HERE"

# Optional: Add VPN users
vpn_client_access_group_users = [
  "user1@example.com",
  "user2@example.com"
]
```

### Step 3: Initialize Terraform

```bash
terraform init
```

This will download all required provider plugins and modules.

### Step 4: Review the Plan

```bash
terraform plan
```

Review the resources that will be created. You should see approximately 20+ resources.

### Step 5: Deploy the Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm. The deployment will take approximately 10-15 minutes.

### Step 6: Download VPN Client Profile

After successful deployment, Terraform will output a command to download your VPN client profile:

```bash
# Login to IBM Cloud
ibmcloud login --apikey YOUR_API_KEY

# Download the VPN client profile (command will be in Terraform outputs)
ibmcloud is vpn-server-client-configuration <vpn-server-id> --file vpn-vpc-client-profile.ovpn
```

## 🔐 Connecting to the VPN

### Prerequisites

1. **Install OpenVPN Client**
   - **macOS**: [Download OpenVPN Connect](https://openvpn.net/client/)
   - **Windows**: [Download OpenVPN Connect](https://openvpn.net/client/)
   - **Linux**:
     ```bash
     sudo apt-get install openvpn  # Ubuntu/Debian
     sudo yum install openvpn      # RHEL/CentOS
     ```

2. **Install jq** (for certificate extraction)
   ```bash
   brew install jq  # macOS
   sudo apt-get install jq  # Ubuntu/Debian
   ```

### Step 1: Download and Configure VPN Profile

After deployment, run the automated configuration script:

```bash
# The script will:
# 1. Download the VPN client profile
# 2. Extract client certificates from Secrets Manager
# 3. Embed certificates into the .ovpn file

# Get the VPN server ID from Terraform outputs
VPN_SERVER_ID=$(terraform output -raw vpn_server_id)
SM_INSTANCE_ID=$(terraform output -raw secrets_manager_id)
CLIENT_CERT_ID=$(terraform output -raw vpn_client_certificate_id)

# Download VPN profile
ibmcloud is vpn-server-client-configuration $VPN_SERVER_ID --file vpn-profile.ovpn

# Download client certificate and key
CERT_DATA=$(ibmcloud secrets-manager secret \
  --id $CLIENT_CERT_ID \
  --instance-id $SM_INSTANCE_ID \
  --region us-south \
  --output json)

echo "$CERT_DATA" | jq -r '.certificate' > client-cert.pem
echo "$CERT_DATA" | jq -r '.private_key' > client-key.pem

# Remove commented cert/key lines
sed -i.bak '/^#cert client_public_key.crt/d' vpn-profile.ovpn
sed -i.bak '/^#key client_private_key.key/d' vpn-profile.ovpn

# Add client certificate and key to .ovpn file
cat >> vpn-profile.ovpn << 'EOF'

<cert>
EOF
cat client-cert.pem >> vpn-profile.ovpn
cat >> vpn-profile.ovpn << 'EOF'
</cert>

<key>
EOF
cat client-key.pem >> vpn-profile.ovpn
cat >> vpn-profile.ovpn << 'EOF'
</key>
EOF

echo "✅ VPN profile configured: vpn-profile.ovpn"
```

### Step 2: Import and Connect

1. **Import Profile**: Open OpenVPN Connect and import `vpn-profile.ovpn`
2. **Connect**: Click the Connect button
3. **Verify**: You should now be connected to the VPC network

### Step 3: Verify Connection

Once connected, test access to VPC resources:

```bash
# Your client will receive an IP from 10.0.0.0/20
# You can access VPC resources at 10.10.0.0/20

# Example: ping a VPC resource (if you have one)
ping 10.10.0.10
```

### Authentication Method

This VPN uses **certificate-based authentication** (not username/password):
- ✅ Client certificate (automatically embedded in .ovpn)
- ✅ Client private key (automatically embedded in .ovpn)
- ✅ CA certificate (already in downloaded profile)
- ❌ No username/password required

## 📊 Resources Created

| Resource Type | Name Pattern | Purpose |
|---------------|--------------|---------|
| Resource Group | `vpn-vpc-resource-group` | Organizes all resources |
| Secrets Manager | `vpn-vpc-secrets-manager` | Stores certificates |
| Secret Group | `vpn-vpc-certs` | Groups VPN certificates |
| Root CA | `vpn-vpc-root-ca` | Root certificate authority |
| Intermediate CA | `vpn-vpc-intermediate-ca` | Intermediate CA |
| Certificate Template | `vpn-vpc-cert-template` | Certificate template |
| Private Certificate | `vpn-vpc-server-cert` | VPN server certificate |
| VPC | `vpn-vpc-vpc` | Virtual Private Cloud |
| Subnets | `vpn-vpc-vpn-subnet-1/2/3` | Network subnets |
| VPN Server | `vpn-vpc-c2s-vpn` | Client-to-site VPN |
| IAM Access Group | `vpn-vpc-access-group` | VPN user access control |

## 💰 Cost Estimation

Approximate monthly costs (us-south region):

| Resource | Estimated Cost |
|----------|----------------|
| Secrets Manager (Standard) | ~$0.50/month |
| VPC | Free |
| Subnets | Free |
| Public Gateways (3) | ~$97/month |
| VPN Server (HA - 2 zones) | ~$65/month |
| **Total** | **~$162/month** |

*Note: Costs exclude data transfer charges. Actual costs may vary.*

## 🔧 Configuration Options

### Variables

All configurable options are in `variables.tf`. Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `us-south` | IBM Cloud region |
| `prefix` | `vpn-vpc` | Resource name prefix |
| `vpc_address_prefix` | `10.10.0.0/20` | VPC CIDR block |
| `vpn_client_ip_pool` | `10.0.0.0/20` | VPN client IP pool |
| `vpn_protocol` | `udp` | VPN protocol (udp/tcp) |
| `certificate_common_name` | `vpn.example.com` | Certificate CN |
## 🐛 Troubleshooting

### Connection Timeout Issues

If you experience connection timeouts when trying to connect to the VPN:

1. **Verify Server Certificate is Attached**
   ```bash
   ibmcloud is vpn-server <vpn-server-id> --output json | jq '.certificate'
   ```
   
   If this shows `null`, the server certificate is missing. The Terraform configuration includes a `null_resource` that automatically attaches the certificate, but if it fails:
   
   ```bash
   # Manually attach the server certificate
   ibmcloud is vpn-server-update <vpn-server-id> --cert "<server-cert-crn>"
   ```

2. **Verify Client Certificates in .ovpn File**
   
   The downloaded `.ovpn` file must include:
   - `<ca>...</ca>` - CA certificate (included by default)
   - `<cert>...</cert>` - Client certificate (must be added)
   - `<key>...</key>` - Client private key (must be added)
   
   If these are missing or commented out, follow the configuration script in the "Connecting to the VPN" section.

3. **Check Security Group Rules**
   ```bash
   ibmcloud is security-group <security-group-id> --output json | jq '.rules'
   ```
   
   Ensure there's an inbound rule allowing UDP port 443 from 0.0.0.0/0.

4. **Verify VPN Server Health**
   ```bash
   ibmcloud is vpn-server <vpn-server-id> --output json | jq '{health_state, lifecycle_state}'
   ```
   
   Both should show `"ok"` and `"stable"` respectively.

5. **Test Network Connectivity**
   ```bash
   # Test if the VPN hostname resolves
   nslookup <vpn-hostname>
   
   # Test UDP connectivity (requires nc with UDP support)
   nc -vzu <vpn-hostname> 443
   ```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Connection timeout" | Missing server certificate | Run the null_resource or manually update VPN server |
| "TLS handshake failed" | Missing client certificates in .ovpn | Re-run the configuration script |
| "Authentication failed" | Wrong authentication method | Ensure certificate-based auth is enabled |
| "Cannot resolve hostname" | DNS issue | Check internet connection and DNS settings |


### Adding VPN Users

Edit `terraform.tfvars`:

```hcl
vpn_client_access_group_users = [
  "user1@example.com",
  "user2@example.com",
  "user3@example.com"
]
```

Then apply the changes:

```bash
terraform apply
```

## 📤 Outputs

After deployment, Terraform provides:

- **Resource Group ID**: For reference
- **VPC ID and Name**: Network identifiers
- **VPN Server ID**: VPN gateway identifier
- **VPN Client Profile Download Command**: CLI command to get .ovpn file
- **Deployment Summary**: Complete overview of all resources
- **Access Instructions**: Step-by-step VPN setup guide

View outputs anytime:

```bash
terraform output
```

## 🔄 Managing the Infrastructure

### Update Configuration

1. Modify `terraform.tfvars` or `variables.tf`
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

### Destroy Infrastructure

To remove all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete all resources including the VPC, VPN server, and Secrets Manager instance.

## 🛠️ Troubleshooting

### VPN Connection Issues

1. **Authentication Failed**
   - Verify you're using your IBM Cloud IAM credentials
   - Check that your user is in the VPN access group

2. **Cannot Download Client Profile**
   - Ensure IBM Cloud CLI is installed and logged in
   - Verify the VPN server ID from Terraform outputs

3. **Cannot Access VPC Resources**
   - Verify VPN connection is active
   - Check that resources exist in the VPC network (10.10.0.0/20)
   - Verify security group rules allow traffic

### Terraform Issues

1. **Module Download Errors**
   ```bash
   terraform init -upgrade
   ```

2. **State Lock Issues**
   - Wait for other operations to complete
   - Or force unlock (use with caution):
   ```bash
   terraform force-unlock <lock-id>
   ```

3. **Resource Already Exists**
   - Import existing resource:
   ```bash
   terraform import <resource_type>.<name> <resource_id>
   ```

## 📚 Additional Resources

- [IBM Cloud VPC Documentation](https://cloud.ibm.com/docs/vpc)
- [Client-to-Site VPN Overview](https://cloud.ibm.com/docs/vpc?topic=vpc-vpn-client-to-site-overview)
- [IBM Secrets Manager Documentation](https://cloud.ibm.com/docs/secrets-manager)
- [Terraform IBM Provider Documentation](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs)

## 🔒 Security Best Practices

1. **API Key Security**
   - Never commit `terraform.tfvars` to version control
   - Use environment variables for sensitive data
   - Rotate API keys regularly

2. **VPN Access Control**
   - Regularly review VPN access group members
   - Remove access for users who no longer need it
   - Enable MFA for IBM Cloud accounts

3. **Certificate Management**
   - Monitor certificate expiration dates
   - Rotate certificates before expiration
   - Use appropriate TTL values for your security requirements

## 📝 Module Versions

This configuration uses the following IBM Cloud Terraform modules:

- `terraform-ibm-modules/resource-group/ibm` v1.4.7
- `terraform-ibm-modules/secrets-manager/ibm` v2.13.1
- `terraform-ibm-modules/secrets-manager-private-cert-engine/ibm` v1.13.0
- `terraform-ibm-modules/secrets-manager-secret-group/ibm` v1.4.2
- `terraform-ibm-modules/secrets-manager-private-cert/ibm` v1.11.0
- `terraform-ibm-modules/landing-zone-vpc/ibm` v8.13.2
- `terraform-ibm-modules/client-to-site-vpn/ibm` v3.5.6

## 🤝 Support

For issues or questions:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review [IBM Cloud Documentation](https://cloud.ibm.com/docs)
3. Open an issue in the repository (if applicable)
4. Contact IBM Cloud Support

## 📄 License

This configuration is provided as-is for use with IBM Cloud services.

---

**Created with ❤️ using IBM Cloud Terraform Modules**
