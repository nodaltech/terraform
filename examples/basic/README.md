# Basic example

This repository root **is** the basic example. From the repo root:

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
terraform init
terraform plan
terraform apply
```

Required values: `aws_region`, `vpc_id`, `probe_installer_path`, `allowed_ssh_cidrs`, and ideally `probe_subnet_id` (public subnet).
