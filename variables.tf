variable "aws_region" {
  type        = string
  description = "AWS region for the Nodal Probe and traffic mirror sessions."
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC that contains the probe subnet and candidate source ENIs."

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (vpc- followed by 8–17 hex characters)."
  }
}

variable "probe_installer_path" {
  type        = string
  description = "Path on this machine to the probe installer zip. Staged to a private S3 object and installed via SSM."

  validation {
    condition     = fileexists(var.probe_installer_path)
    error_message = "probe_installer_path must point to an existing file on the machine running Terraform."
  }
}

variable "probe_subnet_id" {
  type        = string
  description = "Subnet for the Nodal Probe (both NICs). Must belong to vpc_id. May be private."

  validation {
    condition     = can(regex("^subnet-[0-9a-f]{8,17}$", var.probe_subnet_id))
    error_message = "probe_subnet_id must be a valid subnet ID (subnet- followed by 8–17 hex characters)."
  }
}

variable "source_eni_ids" {
  type        = list(string)
  default     = []
  description = "ENI IDs to mirror. Required for production unless enable_eni_auto_discovery is true."

  validation {
    condition = alltrue([
      for id in var.source_eni_ids : can(regex("^eni-[0-9a-f]{8,17}$", id))
    ])
    error_message = "Every source_eni_ids entry must be a valid ENI ID (eni- followed by 8–17 hex characters)."
  }
}

variable "enable_eni_auto_discovery" {
  type        = bool
  default     = false
  description = "Opt into VPC-wide discovery of account-owned EC2 ENIs when source_eni_ids is empty. Default false."
}

variable "exclude_eni_ids" {
  type        = list(string)
  default     = []
  description = "ENI IDs to skip during auto-discovery (for example non-Nitro instances)."

  validation {
    condition = alltrue([
      for id in var.exclude_eni_ids : can(regex("^eni-[0-9a-f]{8,17}$", id))
    ])
    error_message = "Every exclude_eni_ids entry must be a valid ENI ID (eni- followed by 8–17 hex characters)."
  }
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "If non-empty, only ENIs in these subnets are auto-discovered as mirror sources."

  validation {
    condition = alltrue([
      for id in var.subnet_ids : can(regex("^subnet-[0-9a-f]{8,17}$", id))
    ])
    error_message = "Every subnet_ids entry must be a valid subnet ID (subnet- followed by 8–17 hex characters)."
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

  validation {
    condition     = var.ami_id == null || can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id must be null or a valid AMI ID (ami- followed by 8–17 hex characters)."
  }
}

variable "root_volume_size" {
  type        = number
  default     = 50
  description = "Root EBS volume size in GiB."

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 16384
    error_message = "root_volume_size must be between 8 and 16384 GiB."
  }
}

variable "associate_public_ip_address" {
  type        = bool
  default     = false
  description = "Whether to auto-assign a public IPv4 address on the primary NIC. Default false."
}

variable "key_name" {
  type        = string
  default     = null
  description = "Optional existing EC2 key pair name. Terraform does not generate a private key. SSH is not used for installation."
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  default     = []
  description = "Optional CIDRs allowed to SSH. Default empty (no inbound SSH)."

  validation {
    condition = alltrue([
      for cidr in var.allowed_ssh_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "Every allowed_ssh_cidrs entry must be a valid IPv4 CIDR (for example 203.0.113.10/32)."
  }
}

variable "session_number" {
  type        = number
  default     = 1
  description = "Traffic Mirror session number (1-32766) used for sessions created by this deployment."

  validation {
    condition     = var.session_number >= 1 && var.session_number <= 32766
    error_message = "session_number must be between 1 and 32766."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags applied via the AWS provider default_tags and the module."
}
