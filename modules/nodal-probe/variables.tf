variable "vpc_id" {
  type        = string
  description = "ID of the existing VPC that contains the probe subnet and (when auto-discovering) candidate source ENIs."

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (vpc- followed by 8–17 hex characters)."
  }
}

variable "probe_installer_path" {
  type        = string
  description = "Absolute or root-relative path on the machine running Terraform to the probe installer zip. Terraform uploads it to a private S3 object; the probe downloads it over SSM. The instance always stores it as /home/ubuntu/probe.zip regardless of the local filename."

  validation {
    condition     = fileexists(var.probe_installer_path)
    error_message = "probe_installer_path must point to an existing file on the machine running Terraform."
  }
}

variable "probe_subnet_id" {
  type        = string
  description = "Subnet for both probe NICs. Must belong to vpc_id. May be private. Successful install does not require a public IP; SSM needs NAT egress or VPC interface endpoints (ssm, ssmmessages, ec2messages) plus S3 access for the installer."

  validation {
    condition     = can(regex("^subnet-[0-9a-f]{8,17}$", var.probe_subnet_id))
    error_message = "probe_subnet_id must be a valid subnet ID (subnet- followed by 8–17 hex characters)."
  }
}

variable "source_eni_ids" {
  type        = list(string)
  default     = []
  description = "ENI IDs to mirror. Recommended for all production deployments. Required unless enable_eni_auto_discovery is true. Each ENI must belong to vpc_id and be attached to an EC2 instance."

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
  description = <<-EOT
    When true and source_eni_ids is empty, discover in-use interface ENIs in the VPC that are attached to EC2 instances owned by this account.

    Default false. Auto-discovery can select every eligible EC2 ENI in the VPC (including unrelated workloads), creates Traffic Mirror sessions on those ENIs, and consumes source-instance network allowance. Production and shared VPCs should set source_eni_ids explicitly instead.
  EOT
}

variable "exclude_eni_ids" {
  type        = list(string)
  default     = []
  description = "ENI IDs to skip when auto-discovering mirror sources (for example non-Nitro instances). The probe's own ENIs are always excluded. Ignored when source_eni_ids is set."

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
  description = "If non-empty, only ENIs in these subnets are auto-discovered as mirror sources. Ignored when source_eni_ids is set."

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
  description = "EC2 instance type for the Nodal Probe. Must be Nitro-based to receive traffic mirror VXLAN."

  validation {
    condition     = length(trimspace(var.instance_type)) > 0
    error_message = "instance_type must be a non-empty string."
  }
}

variable "ami_id" {
  type        = string
  default     = null
  description = "Optional AMI ID. Defaults to the current Ubuntu Server 24.04 amd64 AMI from SSM."

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
  description = "Whether to auto-assign a public IPv4 address on the primary NIC. Default false. Private subnets should leave this false; SSM does not require a public IP."
}

variable "key_name" {
  type        = string
  default     = null
  description = "Optional existing EC2 key pair name for emergency console/SSH access. Terraform never generates a private key. SSH is not used for installation. If set, also set allowed_ssh_cidrs to permit TCP/22."
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDR blocks allowed to SSH to the probe primary NIC. Default empty (no inbound SSH). Only used for optional operator access; SSM Session Manager is the supported administrative path."

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
  description = <<-EOT
    Traffic Mirror session number (1-32766) used for every session this module creates.
    AWS requires uniqueness among sessions on the same source ENI (max 3 sessions per ENI).
    The same number may be reused across different source ENIs.
    If a source already has a session using this number, apply fails — choose a free number (commonly 2 or 3).
    Two Nodal module instances must not target the same source ENI with the same session_number.
  EOT

  validation {
    condition     = var.session_number >= 1 && var.session_number <= 32766
    error_message = "session_number must be between 1 and 32766."
  }
}

variable "probe_egress_rules" {
  type = list(object({
    description = optional(string, "Probe primary NIC egress")
    ip_protocol = string
    from_port   = optional(number)
    to_port     = optional(number)
    cidr_ipv4   = string
  }))
  default = [
    {
      description = "Unrestricted IPv4 egress. This repository does not document Nodal probe destinations; SSM, apt, S3 installer download, and probe runtime all use this path. Restrict when destinations are known."
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  ]
  description = <<-EOT
    Egress rules for the probe primary NIC. Default is unrestricted IPv4 (0.0.0.0/0, all protocols).

    This default is a security trade-off: the installer uses apt and S3, SSM needs HTTPS to AWS endpoints, and this repository does not contain the Nodal probe binary or its phone-home destinations. Do not assume 0.0.0.0/0 is required by Nodal; replace these rules when you know the destinations.

    For ip_protocol "-1", from_port and to_port are omitted. Otherwise both ports are required. Duplicate rules are not allowed.
  EOT

  validation {
    condition = alltrue([
      for rule in var.probe_egress_rules : (
        can(cidrhost(rule.cidr_ipv4, 0)) && (
          rule.ip_protocol == "-1" || (rule.from_port != null && rule.to_port != null)
        )
      )
    ])
    error_message = "Each probe_egress_rules entry needs a valid cidr_ipv4, and from_port/to_port unless ip_protocol is \"-1\"."
  }

  validation {
    condition = length(var.probe_egress_rules) == length(toset([
      for rule in var.probe_egress_rules : md5(jsonencode(rule))
    ]))
    error_message = "probe_egress_rules must not contain duplicate rule objects."
  }
}

variable "ssm_install_timeout_seconds" {
  type        = number
  default     = 1800
  description = "How long Terraform waits for the SSM install association to reach Success, including SSM agent registration after boot."

  validation {
    condition     = var.ssm_install_timeout_seconds >= 60 && var.ssm_install_timeout_seconds <= 7200
    error_message = "ssm_install_timeout_seconds must be between 60 and 7200."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags applied to all taggable resources."
}
