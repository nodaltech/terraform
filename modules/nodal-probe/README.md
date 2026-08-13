# Nodal Probe module

Reusable Terraform module that deploys a Nodal Probe into an existing AWS VPC, configures VPC Traffic Mirroring to its sniff NIC, and installs a locally provided probe zip over SSH.

## Usage

```hcl
module "nodal_probe" {
  source = "../../modules/nodal-probe" # or a git source with //modules/nodal-probe

  vpc_id               = var.vpc_id
  probe_installer_path = abspath(var.probe_installer_path)
  probe_subnet_id      = var.probe_subnet_id # public subnet
  allowed_ssh_cidrs    = ["203.0.113.10/32"]
  tags = {
    Environment = "prod"
  }
}
```

## Requirements

| Name | Version |
| --- | --- |
| terraform | >= 1.5.0 |
| aws | >= 5.0, < 7.0 |
| tls | >= 4.0, < 5.0 |
| local | >= 2.4, < 3.0 |

## Providers

The AWS provider must be configured by the root module (region and credentials).

## Resources (summary)

- EC2 instance (Ubuntu 24.04), key pair, security groups
- Secondary ENI + attachment (sniff / mirror target)
- Traffic Mirror target, filter, filter rules, sessions
- IAM role + instance profile (SSM)
- Local `nodal_probe.pem` private key file
- `terraform_data` provisioners to upload and install the zip

## Notes

- Prefer a dedicated **public** subnet via `probe_subnet_id`.
- Restrict `allowed_ssh_cidrs` in production.
- The private key material is stored in Terraform state — use encrypted remote state.
- Destroy with Terraform only; do not terminate the instance solely in the AWS console.
- Installer zip must include `update/install.sh` (nested paths allowed).

See the [repository README](../../README.md) for full customer documentation.
