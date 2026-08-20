# Explicit source ENI example

Deploys the Nodal Probe module against one mirrored ENI. Defaults match the module: no public IP, no SSH CIDRs, install via SSM.

Copy or edit variables, place `probe.zip` next to `main.tf` (or set `probe_installer_path`), then:

```bash
terraform init
terraform plan
```

## Example values

```hcl
aws_region      = "us-west-2"
vpc_id          = "vpc-xxxxxxxx"
probe_subnet_id = "subnet-xxxxxxxx"

source_eni_ids = [
  "eni-xxxxxxxxxxxxxxxxx"
]
```

`associate_public_ip_address` is `false` in `main.tf`. Use a subnet with NAT or SSM/S3 VPC endpoints, or change it to `true` if the subnet only has an Internet Gateway route and no private egress path.
