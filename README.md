# Nodal Probe Terraform

Deploys a **Nodal Probe** into an existing AWS VPC, mirrors traffic from selected or auto-discovered EC2 ENIs to a dedicated sniff NIC, and installs a local `probe.zip` through **AWS Systems Manager**.

The default path does not use SSH, generated private keys, or a public IP.

## Architecture

```text
Terraform
   |
   +--> Private S3 bucket (probe.zip, SSE-S3, public access blocked)
   |
   +--> EC2 probe
   |      |
   |      +--> SSM Agent (AmazonSSMManagedInstanceCore)
   |      |
   |      +--> downloads probe.zip via SSM aws:downloadContent
   |      |
   |      +--> unzip; run install.sh from the archive
   |
   +--> SSM Command document + State Manager association
   |
   +--> Traffic Mirroring
          source ENIs --VXLAN 4789--> ens6 (sniff NIC)
          ens5 = management (SSM; no inbound required by default)
```

- **ens5**: primary/management NIC. Defaults: no public IP, no inbound SSH.
- **ens6**: traffic mirror target. Attached with `aws_network_interface_attachment` (Terraform AWS provider credentials; not the AWS CLI).
- Installer zip must contain `install.sh` somewhere in the archive (nested folders are fine).

Reusable module: [`modules/nodal-probe`](modules/nodal-probe). Example: [`examples/explicit-eni`](examples/explicit-eni).

## Networking

- `probe_subnet_id` is **required** and must belong to `vpc_id`. The module does not auto-select a subnet.
- The subnet may be **private**. `associate_public_ip_address` defaults to `false`.
- No inbound SSH is required. Use Session Manager:

  ```bash
  terraform output -raw ssm_start_session_command
  # or
  aws ssm start-session --target $(terraform output -raw instance_id)
  ```

- SSM and installer download need a network path. Provide one of:
  - NAT (or other HTTPS egress) to public AWS/apt endpoints, or
  - VPC interface endpoints for `ssm`, `ssmmessages`, and `ec2messages`, plus S3 access (gateway endpoint or equivalent) for the installer object.
- This root/module stack does **not** create VPC endpoints.
- Subnets with only an Internet Gateway route and **no** public IP on the instance cannot reach SSM. In that case either set `associate_public_ip_address = true` or use NAT/endpoints.
- The install script runs `apt-get` to install `unzip` (needs Ubuntu package mirrors unless you change the AMI).
- Mirrored traffic from other Availability Zones works; AWS may charge for cross-AZ data transfer. Deploy one module instance per AZ if you want in-AZ mirroring only.

## Source selection

**Explicit (required for production unless you opt into auto-discovery):**

```hcl
source_eni_ids = [
  "eni-xxxxxxxxxxxxxxxxx"
]
```

When non-empty, this list takes precedence. Each ID is validated to belong to `vpc_id` and to be attached to an EC2 instance.

**Auto-discovery (opt-in only):**

```hcl
enable_eni_auto_discovery = true
# optional: subnet_ids / exclude_eni_ids
```

Discovers in-use `interface` ENIs attached to EC2 instances **owned by the current AWS account**. That excludes ALB, RDS, Route 53 Resolver, and other service-owned ENIs. Default is **off** so a shared VPC is not mirrored by accident. Source ENIs must be on **Nitro** instance types. The probe’s own ENIs are always excluded.

The traffic mirror filter accepts all IPv4 ingress and egress (Nodal analysis expects full traffic).

## Installer

1. Terraform reads `probe_installer_path` on the machine running Terraform.
2. It creates a private S3 bucket (`nodal-probe-*` prefix, unique per module instance), blocks public access, and stores `probe.zip` with AES256 server-side encryption.
3. The probe instance role may `s3:GetObject` on that object only.
4. An SSM association downloads the object with `aws:downloadContent` (instance-role auth; not a public URL), then runs the install script: wait for `ens6`, install `unzip`, unzip the archive, run `install.sh`, delete the zip.

There is no public S3 URL. The zip is not placed in EC2 user data.

If install fails, Terraform fails the association create/update when `wait_for_success_timeout_seconds` elapses without Success (default 1800s; module variable `ssm_install_timeout_seconds`).

## IAM

**Deployer** (identity running Terraform): least-privilege example in [`docs/terraform-deployment-policy.json`](docs/terraform-deployment-policy.json). Replace `ACCOUNT_ID` and `REGION`. Do not use `ec2:*` / `iam:*` / `ssm:*` / `s3:*`.

**Probe instance role:**

- AWS managed `AmazonSSMManagedInstanceCore`
- Inline policy: `s3:GetObject` on the staged installer object only

## Destroy behavior

Always destroy with Terraform:

```bash
terraform destroy
```

Destroy order removes Traffic Mirror sessions, then the mirror target, then detaches the sniff ENI, then the instance and staging bucket. Do not only terminate the instance in the console.

## Requirements

- Terraform `>= 1.5`
- AWS provider `>= 6.0, < 7.0`
- AWS credentials matching the deployment policy
- Existing VPC and explicit `probe_subnet_id` in that VPC
- SSM (and S3) connectivity as described above
- Local `probe.zip` containing `install.sh`

## Quick start

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
aws_region           = "us-west-2"
vpc_id               = "vpc-xxxxxxxx"
probe_subnet_id      = "subnet-xxxxxxxx"
probe_installer_path = "./probe.zip"

source_eni_ids = [
  "eni-xxxxxxxxxxxxxxxxx"
]

instance_type               = "t3.xlarge"
root_volume_size            = 50
associate_public_ip_address = false
```

```bash
terraform init
terraform plan
terraform apply
```

## Root module variables

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `aws_region` | yes | — | AWS region for the provider |
| `vpc_id` | yes | — | Target VPC |
| `probe_subnet_id` | yes | — | Subnet for both probe NICs |
| `probe_installer_path` | yes | — | Local path to the installer zip |
| `source_eni_ids` | no* | `[]` | ENIs to mirror (*required unless auto-discovery is enabled) |
| `enable_eni_auto_discovery` | no | `false` | Opt into VPC-wide account-owned EC2 ENI discovery |
| `exclude_eni_ids` | no | `[]` | Skip during auto-discovery |
| `subnet_ids` | no | `[]` | Limit auto-discovery to these subnets |
| `instance_type` | no | `t3.xlarge` | Probe instance type (Nitro) |
| `ami_id` | no | `null` | Override Ubuntu 24.04 AMI from SSM |
| `root_volume_size` | no | `50` | Root volume GiB |
| `associate_public_ip_address` | no | `false` | Auto-assign public IPv4 on ens5 |
| `key_name` | no | `null` | Optional existing EC2 key pair (no key is generated) |
| `allowed_ssh_cidrs` | no | `[]` | Optional SSH ingress; empty = no SSH |
| `session_number` | no | `1` | Traffic Mirror session number (1–32766) |
| `tags` | no | `{}` | Extra tags |

Module-only inputs (call [`modules/nodal-probe`](modules/nodal-probe) directly): `probe_egress_rules`, `ssm_install_timeout_seconds`.

Apply fails closed if neither `source_eni_ids` nor `enable_eni_auto_discovery` is set, or if discovery/selection yields zero ENIs.

## Root module outputs

| Name | Description |
| --- | --- |
| `instance_id` | Probe EC2 instance ID |
| `public_ip` | Public IPv4 if enabled; otherwise empty |
| `private_ip` | Primary NIC private IP |
| `sniff_private_ip` | Sniff NIC private IP |
| `ssm_start_session_command` | Session Manager CLI command |
| `installer_s3_uri` | Private `s3://` URI of staged `probe.zip` |
| `discovered_eni_ids` | Auto-discovery candidates (empty when `source_eni_ids` is set) |
| `mirrored_eni_ids` | ENIs with mirror sessions |
| `traffic_mirror_target_id` | Mirror target ID |
| `traffic_mirror_session_ids` | Map of source ENI → session ID |

## Verify traffic mirroring

On the probe (Session Manager):

```bash
sudo ip link set ens6 up
sudo tcpdump -ni ens6 udp port 4789
```

Generate traffic on a mirrored source. You should see UDP/4789 packets.

If Terraform succeeded but you see no VXLAN, check: mirror sessions exist on the source ENI, source is Nitro, sniff SG allows UDP/4789 from the VPC CIDR, and `ens6` is UP. Packet drops under load are silent (AWS prioritizes production traffic).

## Customer deployment checklist

1. Set **`source_eni_ids`** explicitly (do not enable auto-discovery in shared/production VPCs).
2. Confirm probe subnet has **SSM + S3** reachability (NAT/endpoints) or set `associate_public_ip_address = true` on an IGW-routed subnet.
3. Use a free **`session_number`** if the source ENI already has Traffic Mirror sessions (AWS max **3 sessions per ENI**).
4. Use **encrypted remote state with locking**.
5. Destroy **only** with `terraform destroy` (never console-terminate the probe alone).
6. Expect **full IPv4 packet payloads** on the probe (credentials, PII, DB traffic may be present).
7. Treat **IPv6 as not mirrored** (AWS Traffic Mirroring limitation / this module’s IPv4 filters).

## Known limitations (adversarial)

| Topic | Behavior |
| --- | --- |
| Auto-discovery drift | With `enable_eni_auto_discovery=true`, a later `terraform plan` **adds sessions** for new account-owned EC2 ENIs without config changes. Explicit `source_eni_ids` does not. |
| Lost state | Re-apply without state can recreate a probe and fail creating sessions if `session_number` is already in use on the same ENIs. Recover by importing, deleting orphaned Nodal sessions, or changing `session_number`. |
| Parallel probes | Supported via prefixes. Two modules must not use the same `session_number` on the same source ENI. |
| Non-Nitro sources | Fail at **apply** when creating the session (not always detectable at plan). |
| RDS/ElastiCache ENIs | AWS may allow some requester-managed sources; this module’s explicit path requires an EC2 `instance_id` attachment and rejects others at plan/refresh. |
| IPv6 | Not mirrored. |
| Package install | Needs apt (or equivalent) reachability unless you replace the AMI/install path. |
| Capture scope | Accept-all IPv4 ingress+egress; full payloads unless the product truncates later. |

## Notes

- Default primary-NIC egress is unrestricted IPv4 (`0.0.0.0/0`). Security groups cannot match DNS names; Nodal phone-home typically uses DNS. Tighten with module `probe_egress_rules` (port allowlists) and/or DNS-aware firewalls when destinations are known.
- Sniff NIC security group allows VXLAN UDP/4789 from the VPC CIDR(s) only; it does not open administrative ingress.
- Probe ENIs are tagged `NodalProbeManaged=true` so auto-discovery excludes them without relying on display Name collisions.
- EBS root volume is encrypted. Installer object uses SSE-S3.
- `terraform.tfvars`, `*.pem`, `*.zip`, and state files are gitignored.

## Layout

```text
.
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── versions.tf
├── terraform.tfvars.example
├── docs/terraform-deployment-policy.json
├── examples/explicit-eni/
└── modules/nodal-probe/
```
