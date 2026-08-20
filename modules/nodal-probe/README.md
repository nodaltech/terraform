# Nodal Probe module

Terraform module that places a Nodal Probe in an existing VPC, mirrors EC2 ENI traffic to a sniff NIC (`ens6`), stages `probe.zip` in a private S3 object, and installs it with Systems Manager.

Default path: no SSH, no generated key pairs, no AWS CLI attach, no public IP required.

For a fuller deployment guide, see the [root README](../../README.md).

## Example

```hcl
module "nodal_probe" {
  source = "../../modules/nodal-probe"

  vpc_id               = "vpc-xxxxxxxx"
  probe_subnet_id      = "subnet-xxxxxxxx"
  probe_installer_path = "probe.zip"

  source_eni_ids = [
    "eni-xxxxxxxxxxxxxxxxx"
  ]

  instance_type               = "t3.xlarge"
  root_volume_size            = 50
  associate_public_ip_address = false

  tags = {
    Environment = "dev"
    Owner       = "infrastructure"
  }
}
```

Configure the AWS provider in the root module (this module uses `data.aws_region.current.region`). The AWS CLI is not required for apply.

## Requirements

| Name | Version |
| --- | --- |
| terraform | >= 1.5.0 |
| aws | >= 6.0, < 7.0 |

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `vpc_id` | yes | — | VPC containing the probe subnet and (when discovering) source ENIs |
| `probe_subnet_id` | yes | — | Subnet for both NICs; must belong to `vpc_id`; may be private |
| `probe_installer_path` | yes | — | Local path to installer zip (must exist at plan/apply) |
| `source_eni_ids` | no* | `[]` | ENIs to mirror (*required unless `enable_eni_auto_discovery`) |
| `enable_eni_auto_discovery` | no | `false` | Opt into VPC-wide account-owned EC2 ENI discovery |
| `exclude_eni_ids` | no | `[]` | Skip during auto-discovery |
| `subnet_ids` | no | `[]` | Limit auto-discovery to these subnets |
| `instance_type` | no | `t3.xlarge` | Nitro instance type for the probe |
| `ami_id` | no | `null` | Override; default Ubuntu Server 24.04 amd64 from SSM |
| `root_volume_size` | no | `50` | Root EBS size in GiB (min 8) |
| `associate_public_ip_address` | no | `false` | Auto-assign public IPv4 on the primary NIC |
| `key_name` | no | `null` | Optional existing EC2 key pair; Terraform never generates a key |
| `allowed_ssh_cidrs` | no | `[]` | Optional SSH CIDRs; empty means no inbound SSH |
| `session_number` | no | `1` | Traffic Mirror session number (1–32766) |
| `probe_egress_rules` | no | all IPv4 egress | Primary NIC egress rules (see variable docs) |
| `ssm_install_timeout_seconds` | no | `1800` | Wait for SSM install association Success |
| `tags` | no | `{}` | Extra tags on taggable resources |

## Outputs

| Name | Description |
| --- | --- |
| `instance_id` | Probe EC2 instance ID |
| `public_ip` | Public IPv4 if enabled |
| `private_ip` | Primary NIC private IP |
| `sniff_private_ip` | Sniff NIC private IP |
| `primary_eni_id` | Primary ENI ID |
| `sniff_eni_id` | Sniff ENI ID |
| `iam_role_name` | Probe IAM role name |
| `iam_instance_profile_name` | Instance profile name |
| `installer_s3_uri` | Private `s3://` URI of staged `probe.zip` |
| `ssm_association_id` | Install association ID |
| `ssm_start_session_command` | Session Manager CLI command |
| `discovered_eni_ids` | Auto-discovery candidates |
| `mirrored_eni_ids` | ENIs with mirror sessions |
| `traffic_mirror_target_id` | Mirror target ID |
| `traffic_mirror_filter_id` | Mirror filter ID |
| `traffic_mirror_session_ids` | Map of source ENI → session ID |
| `probe_subnet_id` | Subnet used for the probe |

## Networking

- `probe_subnet_id` is required and validated against `vpc_id`.
- Private subnets are supported when SSM/S3 reachability exists (NAT or VPC endpoints).
- Default `associate_public_ip_address = false`. IGW-only subnets without a public IP (or NAT/endpoints) will not register with SSM.
- No inbound SSH by default. Optional `key_name` + `allowed_ssh_cidrs` for emergency access only.
- This module does not create VPC endpoints.
- Cross-AZ sources are allowed; transfer charges may apply. Multiple module instances per account/VPC are supported.

## Source selection

- **Explicit:** `source_eni_ids = ["eni-..."]` (production default path). Each ID is looked up and must belong to `vpc_id` and be attached to an EC2 instance.
- **Auto (opt-in):** `enable_eni_auto_discovery = true` discovers account-owned EC2 ENIs only (`attachment.instance-owner-id` = current account). Service-owned ENIs are excluded. Default is off.
- Probe ENIs tagged `NodalProbeManaged=true` are excluded from auto-discovery (all module instances in the VPC).
- Apply fails if neither explicit ENIs nor auto-discovery is configured, or if selection yields zero ENIs.
- IPv6 traffic is not mirrored (AWS / module limitation).
- With auto-discovery enabled, later plans may add sessions when new EC2 ENIs appear.

## Installer

1. Upload `probe_installer_path` to a module-managed private S3 bucket (`nodal-probe-*`, SSE-S3, public access blocked, TLS-only bucket policy).
2. SSM document downloads via `aws:downloadContent`, then runs `scripts/install_probe.sh` (bring up `ens6`, `apt-get install unzip`, unzip, run `install.sh`, remove zip).
3. Association waits for Success up to `ssm_install_timeout_seconds`.

## Security groups

- **Primary:** no inbound by default; egress from `probe_egress_rules` (default unrestricted IPv4).
- **Sniff:** inbound UDP/4789 from VPC CIDR(s) only (VXLAN).

## IAM

- Probe role: `AmazonSSMManagedInstanceCore` + `s3:GetObject` on the installer object.
- Deployer policy example: [`docs/terraform-deployment-policy.json`](../../docs/terraform-deployment-policy.json).

## Destroy

Use `terraform destroy` so mirror sessions and the target are removed before the sniff ENI is detached. The staging bucket uses `force_destroy` so teardown can delete the installer object.
