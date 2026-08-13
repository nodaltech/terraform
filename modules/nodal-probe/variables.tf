variable "vpc_id" {
  type        = string
  description = "ID of the existing VPC. All in-use ENIs in this VPC are discovered and mirrored to the Nodal Probe unless source_eni_ids is set."

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (vpc-...)."
  }
}

variable "probe_installer_path" {
  type        = string
  description = "Absolute or root-relative path on the machine running Terraform to the probe installer zip. It is uploaded to the instance as /home/ubuntu/probe.zip regardless of the local filename."
}

variable "probe_subnet_id" {
  type        = string
  default     = null
  description = "Subnet for the Nodal Probe (both NICs). Must be public (IGW route) so ens5 gets an auto-assigned public IP, not an Elastic IP. If null, the first subnet in the VPC is used."

  validation {
    condition     = var.probe_subnet_id == null || can(regex("^subnet-[0-9a-f]+$", var.probe_subnet_id))
    error_message = "probe_subnet_id must be a valid subnet ID (subnet-...)."
  }
}

variable "source_eni_ids" {
  type        = list(string)
  default     = []
  description = "If non-empty, only these ENI IDs are mirrored (instead of auto-discovering every in-use interface ENI in the VPC)."
}

variable "exclude_eni_ids" {
  type        = list(string)
  default     = []
  description = "ENI IDs to skip when auto-discovering mirror sources (for example non-Nitro instances). The probe's own ENIs are always excluded."
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "If non-empty, only ENIs in these subnets are auto-discovered as mirror sources."
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH to the probe primary NIC. Prefer your operator /32. Use [\"0.0.0.0/0\"] only for short-lived labs."

  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0
    error_message = "allowed_ssh_cidrs must contain at least one CIDR (for example your public IP as x.x.x.x/32)."
  }
}

variable "instance_type" {
  type        = string
  default     = "t3.xlarge"
  description = "EC2 instance type for the Nodal Probe. Must be Nitro-based to receive traffic mirror VXLAN."
}

variable "ami_id" {
  type        = string
  default     = null
  description = "Optional AMI ID. Defaults to the current Ubuntu Server 24.04 amd64 AMI from SSM."
}

variable "root_volume_size" {
  type        = number
  default     = 50
  description = "Root EBS volume size in GiB."

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GiB."
  }
}

variable "key_name_prefix" {
  type        = string
  default     = "nodal-probe"
  description = "Prefix for the AWS key pair name. A unique suffix is appended."
}

variable "private_key_path" {
  type        = string
  default     = null
  description = "Local path for the generated SSH private key. Defaults to nodal_probe.pem in the root module directory."
}

variable "session_number" {
  type        = number
  default     = 1
  description = "Traffic Mirror session number on each source ENI (1-32766). Only needs to be unique among sessions on the same source ENI."

  validation {
    condition     = var.session_number >= 1 && var.session_number <= 32766
    error_message = "session_number must be between 1 and 32766."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags applied to all taggable resources."
}
