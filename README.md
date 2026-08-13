# Nodal Probe Terraform

Deploys a **Nodal Probe** into an existing AWS VPC, mirrors traffic from ENIs in that VPC to the probe, and installs your local probe zip on the instance.

## How it works

```text
  Source ENIs  --VXLAN 4789-->  ens6 (sniff NIC)
                                ens5 (SSH + public IP)  <-- your laptop
```

- **ens5**: management NIC with an auto-assigned public IP (not an Elastic IP)
- **ens6**: traffic mirror target (private IP); brought up during install
- Discovers in-use ENIs in the VPC (or uses `source_eni_ids` if you set them)
- Uploads your installer over SSH as `/home/ubuntu/probe.zip` and runs `update/install.sh`

## Requirements

- Terraform `>= 1.5`
- AWS credentials with EC2, IAM instance profiles, security groups, and Traffic Mirroring
- **AWS CLI** on the machine running Terraform (used to attach the sniff NIC)
- An existing VPC and a **public subnet** (IGW route) for the probe
- Source ENIs on **Nitro** instance types
- Probe installer zip that contains `update/install.sh` (nested folders are fine)

## Quick start

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region           = "us-east-1"
vpc_id               = "vpc-0123456789abcdef0"
probe_subnet_id      = "subnet-0123456789abcdef0" # public subnet
probe_installer_path = "./probe.zip"
allowed_ssh_cidrs    = ["203.0.113.10/32"]         # your public IP
```

```bash
terraform init
terraform plan
terraform apply
```

SSH in:

```bash
ssh -i nodal_probe.pem ubuntu@$(terraform output -raw public_ip)
```

On Windows, fix PEM permissions first:

```powershell
icacls nodal_probe.pem /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

## Variables

| Name | Required | Description |
| --- | --- | --- |
| `aws_region` | yes | AWS region |
| `vpc_id` | yes | VPC to use |
| `probe_installer_path` | yes | Local path to the installer zip |
| `allowed_ssh_cidrs` | yes | CIDRs allowed to SSH (use your `/32`) |
| `probe_subnet_id` | no | Public subnet for the probe (recommended) |
| `source_eni_ids` | no | Mirror only these ENIs |
| `exclude_eni_ids` | no | Skip these ENIs when auto-discovering |
| `subnet_ids` | no | Only discover ENIs in these subnets |
| `instance_type` | no | Default `t3.xlarge` |
| `ami_id` | no | Default Ubuntu 24.04 from SSM |
| `root_volume_size` | no | Default `50` GiB |
| `tags` | no | Extra tags |

## Outputs

| Name | Description |
| --- | --- |
| `public_ip` | Probe public IP |
| `private_ip` | Primary NIC private IP |
| `sniff_private_ip` | Sniff NIC private IP |
| `ssh_command` | SSH command |
| `mirrored_eni_ids` | ENIs being mirrored |
| `private_key_path` | Path to `nodal_probe.pem` |

```bash
terraform output
```

## Verify traffic mirroring

On the probe:

```bash
sudo ip link set ens6 up
sudo tcpdump -ni ens6 udp port 4789
```

Generate traffic on a mirrored source. You should see UDP/4789 packets.

## Destroy

```bash
terraform destroy
```

Use Terraform to tear down. Do not only terminate the instance in the AWS console.

## Notes

- Prefer `allowed_ssh_cidrs = ["x.x.x.x/32"]` in production; `0.0.0.0/0` is for labs only
- Private key material is stored in Terraform state; use encrypted remote state
- `terraform.tfvars`, `*.pem`, `*.zip`, and state files are gitignored
- Reusable module: `modules/nodal-probe` (see that folder's README)

## Layout

```text
.
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── versions.tf
├── terraform.tfvars.example
└── modules/nodal-probe/
```
