variable "aws_region" {
  type        = string
  description = "AWS region for the Nodal Probe and traffic mirror sessions."
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC whose subnets and ENIs are discovered and mirrored to the Nodal Probe."

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (vpc-...)."
  }
}

variable "probe_installer_path" {
  type        = string
  description = "Path on this machine to the probe installer zip. Uploaded to the instance as probe.zip."

  validation {
    condition     = fileexists(var.probe_installer_path)
    error_message = "probe_installer_path must point to an existing file on the machine running Terraform."
  }
}

variable "probe_subnet_id" {
  type        = string
  default     = null
  description = "Public subnet for the Nodal Probe (IGW route so ens5 can have a public IP). If null, the first subnet in the VPC is used."

  validation {
    condition     = var.probe_subnet_id == null || can(regex("^subnet-[0-9a-f]+$", var.probe_subnet_id))
    error_message = "probe_subnet_id must be a valid subnet ID (subnet-...)."
  }
}

variable "source_eni_ids" {
  type        = list(string)
  default     = []
  description = "If non-empty, only these ENIs are mirrored instead of auto-discovering all in-use interface ENIs in the VPC."
}

variable "exclude_eni_ids" {
  type        = list(string)
  default     = []
  description = "ENI IDs to skip during auto-discovery (for example non-Nitro instances)."
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "If non-empty, only ENIs in these subnets are auto-discovered as mirror sources."
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH to the probe. Prefer your operator /32. Use [\"0.0.0.0/0\"] only for short-lived labs."

  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0
    error_message = "allowed_ssh_cidrs must contain at least one CIDR (for example your public IP as x.x.x.x/32)."
  }
}

variable "instance_type" {
  type        = string
  default     = "t3.xlarge"
  description = "EC2 instance type for the Nodal Probe."
}

variable "ami_id" {
  type        = string
  default     = null
  description = "Optional AMI override. Defaults to Ubuntu Server 24.04 amd64 from SSM."
}

variable "root_volume_size" {
  type        = number
  default     = 50
  description = "Root EBS volume size in GiB."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags applied via the AWS provider default_tags and the module."
}
