# Nodal Probe module

Terraform module that places a Nodal Probe in an existing VPC, sets up Traffic Mirroring to its sniff NIC (`ens6`), and installs a local probe zip over SSH.

## Example

```hcl
module "nodal_probe" {
  source = "./modules/nodal-probe"

  vpc_id               = "vpc-0123456789abcdef0"
  probe_subnet_id      = "subnet-0123456789abcdef0"
  probe_installer_path = abspath("./probe.zip")
  allowed_ssh_cidrs    = ["203.0.113.10/32"]
}
```

## Requirements

| Name | Version |
| --- | --- |
| terraform | >= 1.5.0 |
| aws | >= 5.0, < 7.0 |
| tls | >= 4.0, < 5.0 |
| local | >= 2.4, < 3.0 |

The root module must configure the AWS provider. The machine running Terraform also needs the **AWS CLI** (used to attach the sniff ENI).

## Notes

- Use a public subnet for `probe_subnet_id`
- Installer zip must include `update/install.sh`
- Destroy with Terraform only

See the [root README](../../README.md) for full usage.
