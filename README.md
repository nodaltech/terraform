# Nodal Probe — AWS Terraform

Deploy a **Nodal Probe** into an existing AWS VPC: discover (or select) Elastic Network Interfaces, create VPC Traffic Mirroring sessions to the probe, and install a local probe installer zip onto the instance.

This repository is a ready-to-apply root module plus a reusable child module under `modules/nodal-probe`.

## Architecture

```text
                    Existing VPC
  ┌─────────────────────────────────────────────┐
  │  Source ENIs (Nitro instances)              │
  │       │ Traffic Mirror sessions             │
  │       │ VXLAN UDP/4789                      │
  │       ▼                                     │
  │  ┌──────────────────────────────┐           │
  │  │ Nodal Probe (Ubuntu 24.04)   │           │
  │  │  ens5  primary + public IP   │◄── SSH / installer
  │  │  ens6  sniff (mirror target) │           │
  │  └──────────────────────────────┘           │
  └─────────────────────────────────────────────┘
```

| Component | Purpose |
| --- | --- |
| Primary NIC (`ens5`) | Management: SSH, apt, installer upload. Auto-assigned **public IPv4** (not an Elastic IP). |
| Sniff NIC (`ens6`) | Traffic Mirror **target**. Private IP only. Brought **UP** after attach. |
| Mirror filter | Accept all IPv4 ingress and egress |
| Mirror sessions | One per selected source ENI |
| SSH key | Generated as `nodal_probe.pem` in the working directory |

Instance Name tag: `Nodal Probe`.

## Requirements

| Tool | Version |
| --- | --- |
| [Terraform](https://developer.hashicorp.com/terraform/install) | `>= 1.5` |
| [AWS credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) | Account with EC2, IAM (instance profile), VPC security groups, Traffic Mirroring |
| Probe installer zip | Must contain `update/install.sh` (top-level or nested, e.g. `probe-maven/update/install.sh`) |

### AWS environment

- An existing **VPC**
- A **public subnet** (route `0.0.0.0/0` → Internet Gateway) for the probe so it receives a public IP and can reach apt mirrors
- Source ENIs on **Nitro** instance types (AWS Traffic Mirroring requirement)
- Network ACLs allowing **UDP 4789** from the VPC CIDR to the probe subnet

## Quick start

1. Clone this repository.
2. Copy the example variables file and edit it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
aws_region             = "us-east-1"
vpc_id                 = "vpc-0123456789abcdef0"
probe_subnet_id        = "subnet-0123456789abcdef0"  # public subnet
probe_installer_path   = "./probe.zip"
allowed_ssh_cidrs      = ["203.0.113.10/32"]            # your public IP /32
```

3. Place your Nodal probe installer zip where `probe_installer_path` points (the zip itself is not committed to git).
4. Apply:

```bash
terraform init
terraform plan
terraform apply
```

5. Connect:

```bash
ssh -i nodal_probe.pem -o StrictHostKeyChecking=accept-new ubuntu@$(terraform output -raw public_ip)
```

**Windows (OpenSSH)** — restrict the PEM ACL before connecting:

```powershell
icacls nodal_probe.pem /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

## What `apply` does

1. Creates an SSH key pair and writes `nodal_probe.pem` (mode `0400`).
2. Launches Ubuntu 24.04 with a public IP on the primary NIC.
3. Attaches a second ENI as `ens6` (sniff / mirror target) and brings it up.
4. Creates a Traffic Mirror target, accept-all filter, and sessions for discovered (or listed) ENIs.
5. Copies your local installer to `/home/ubuntu/probe.zip` over SSH, unzips it, and runs `install.sh`.

Re-running apply after changing the installer file (content hash) or replacing the instance re-runs upload and install.

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `aws_region` | yes | | AWS region |
| `vpc_id` | yes | | VPC to scan / place the probe in |
| `probe_installer_path` | yes | | Local path to the installer zip |
| `allowed_ssh_cidrs` | yes | | SSH allow-list (use your `/32` in production) |
| `probe_subnet_id` | no | first subnet in the VPC | **Use a public subnet** |
| `source_eni_ids` | no | `[]` | If set, only these ENIs are mirrored |
| `exclude_eni_ids` | no | `[]` | Skip these ENIs during auto-discovery |
| `subnet_ids` | no | `[]` | Limit auto-discovery to these subnets |
| `instance_type` | no | `t3.xlarge` | Must be Nitro-capable as a mirror target |
| `ami_id` | no | Ubuntu 24.04 via SSM | AMI override |
| `root_volume_size` | no | `50` | Root volume GiB |
| `tags` | no | `{}` | Extra tags (also applied via provider `default_tags`) |

## Outputs

| Name | Description |
| --- | --- |
| `public_ip` | Probe public IPv4 |
| `private_ip` | Primary NIC private IP |
| `sniff_private_ip` | Sniff NIC private IP |
| `ssh_command` | Ready-to-run SSH command |
| `mirrored_eni_ids` | ENIs with mirror sessions |
| `traffic_mirror_session_ids` | Map of ENI → session ID |
| `private_key_path` | Path to `nodal_probe.pem` |

```bash
terraform output
terraform output -raw ssh_command
```

## Using the child module

Other Terraform roots can call the module directly:

```hcl
module "nodal_probe" {
  source = "git::https://github.com/<org>/<repo>.git//modules/nodal-probe?ref=v1.0.0"

  vpc_id               = var.vpc_id
  probe_installer_path = abspath(var.probe_installer_path)
  probe_subnet_id      = var.probe_subnet_id
  allowed_ssh_cidrs    = var.allowed_ssh_cidrs
}
```

See [`modules/nodal-probe/README.md`](modules/nodal-probe/README.md).

## Security

- Restrict `allowed_ssh_cidrs` to operator `/32` addresses in production. `0.0.0.0/0` is only for short-lived labs.
- VXLAN (UDP 4789) is limited to the VPC CIDR(s).
- Root EBS volume is encrypted; instance metadata requires IMDSv2.
- SSM (`AmazonSSMManagedInstanceCore`) is attached as a secondary access path.
- The TLS private key is stored in **Terraform state**. Use encrypted remote state (S3 + DynamoDB lock + KMS, or Terraform Cloud/Enterprise).
- `terraform.tfvars`, `*.pem`, `*.zip`, and `*.tfstate*` are gitignored — do not force-add them.

## Traffic mirroring notes

- Auto-discovery selects in-use ENIs with `interface-type = interface` (skips NAT gateways, VPC endpoints, NLBs, etc.).
- The probe’s own ENIs are excluded so the mirror target is never used as a source.
- Non-Nitro sources fail session creation — use `exclude_eni_ids` or an explicit `source_eni_ids` list.
- Mirrored traffic arrives on `ens6` as VXLAN; the installer should sniff `ens6`.
- New ENIs appear on the next `terraform apply` (data sources refresh at plan time).

## Verify mirroring

On the probe:

```bash
sudo ip link set ens6 up
sudo tcpdump -ni ens6 -vv udp port 4789
```

Generate traffic on a mirrored source instance. You should see UDP/4789 to the sniff NIC. If `ens6` is `state DOWN`, bring it up as above before capturing.

## Destroy

```bash
terraform destroy
```

Always destroy with Terraform (do not terminate the instance only in the console). Manual termination can leave the sniff ENI or mirror target behind and cause detach/delete to hang.

If destroy hangs on the sniff ENI or attachment after a manual instance delete:

```bash
# Inspect then force-detach / delete leftover mirror targets for that ENI, then:
terraform state rm module.nodal_probe.aws_network_interface_attachment.sniff
terraform state rm module.nodal_probe.aws_network_interface.sniff
terraform destroy
```

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| No public IP / SSH timeout | Set `probe_subnet_id` to a **public** subnet; confirm `allowed_ssh_cidrs` includes your IP |
| Session create fails | Source is not Nitro, or ENI already has the maximum sessions — exclude or list ENIs explicitly |
| `install.sh not found` | Zip must contain `update/install.sh` (nested dirs are OK) |
| Installer / zip missing on host | Apply did not finish the install provisioner: `terraform apply -replace=module.nodal_probe.terraform_data.probe_install` |
| `ens6` DOWN / no VXLAN | `sudo ip link set ens6 up` then retest with `tcpdump` |
| Destroy hangs on ENI | Mirror target/sessions must be deleted first; avoid console-only instance delete (see Destroy) |

## Repository layout

```text
.
├── README.md
├── LICENSE
├── main.tf                      # root module → modules/nodal-probe
├── variables.tf
├── outputs.tf
├── providers.tf
├── versions.tf
├── terraform.tfvars.example     # copy to terraform.tfvars (gitignored)
├── .gitignore
├── .terraform.lock.hcl          # commit this for reproducible provider versions
└── modules/nodal-probe/         # reusable module
    ├── README.md
    ├── data.tf
    ├── probe.tf
    ├── mirroring.tf
    ├── install.tf
    ├── key.tf
    ├── security.tf
    ├── iam.tf
    ├── scripts/install_probe.sh
    └── templates/user_data.sh
```

## Support

For installer packages, licensing, and production guidance, contact your Nodal representative.
