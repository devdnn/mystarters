#!/bin/bash
# Script to create a basic Terraform project structure (no roles/modules)

mkdir -p modules

touch locals.tf main.tf outputs.tf providers.tf terraform.tfvars variables.tf

# region locals.tf
cat > locals.tf <<'EOF'
locals {
  yaml_variables_list = yamldecode("terraform.tfvars")
}
EOF
# endregion locals.tf

# region output.tf
cat > outputs.tf <<'EOF'
output "current_workspace" {
  value = terraform.workspace
}

output "current_environment" {
  value = local.yaml_variables_list.environment_type
}

output "proxmox_api_endpoint_url" {
  value = local.yaml_variables_list.proxmox_api_endpoint_url
}
EOF
# endregion output.tf

# region providers.tf
cat > providers.tf <<'EOF'
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.47.0"
    }
  }
}

provider "proxmox" {
  endpoint = local.yaml_variables_list.proxmox_api_endpoint_url
  username = local.yaml_variables_list.proxmox_api_user
  password = local.yaml_variables_list.proxmox_api_password
  insecure = local.yaml_variables_list.proxmox_tls_insecure
  ssh {
    agent = true
  }
}
EOF
# endregion providers.tf

# region terraform.tfvars
echo 'environment_type = "dev"' > terraform.tfvars

cat >> terraform.tfvars <<'EOF'

# host node proxmox details
proxmox_api_endpoint_url = "https://XXXX:8006/"
proxmox_api_user = "root@pam"
proxmox_api_password = "XXXXXX"
proxmox_tls_insecure = true
EOF

# endregion terraform.tfvars

# region variables.tf
cat > variables.tf <<'EOF'
variable "environment_type" {
  type    = string
  default = "dev"
}

variable "proxmox_api_endpoint_url" {
  type    = string
  default = "https://XXX:8006/api2/json"
}

variable "proxmox_api_user" {
  type    = string
  default = ""
}

variable "proxmox_api_password" {
  type    = string
  default = ""
}

variable "proxmox_tls_insecure" {
  type    = bool
  default = true
}
EOF
# endregion variables.tf

echo "Terraform skeleton structure created: main.tf, variables.tf, outputs.tf, providers.tf, terraform.tfvars, modules/"
