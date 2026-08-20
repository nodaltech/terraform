data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_vpc" "target" {
  id = var.vpc_id
}

data "aws_subnet" "probe" {
  id = var.probe_subnet_id

  lifecycle {
    postcondition {
      condition     = self.vpc_id == var.vpc_id
      error_message = "probe_subnet_id must be a subnet in vpc_id."
    }
  }
}

data "aws_ssm_parameter" "ubuntu" {
  count = var.ami_id == null ? 1 : 0
  name  = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# Auto-discovery is opt-in (enable_eni_auto_discovery) and skipped when
# source_eni_ids is set. Traffic Mirroring can only source from ENIs attached
# to supported EC2 instances. VPC + in-use + interface-type filters also match
# AWS service-owned ENIs (ALB, RDS, Route 53 Resolver, and similar). Restricting
# to this account's instance attachments excludes those service ENIs.
data "aws_network_interfaces" "sources" {
  count = length(var.source_eni_ids) == 0 && var.enable_eni_auto_discovery ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "status"
    values = ["in-use"]
  }

  filter {
    name   = "attachment.status"
    values = ["attached"]
  }

  filter {
    name   = "interface-type"
    values = ["interface"]
  }

  filter {
    name   = "attachment.instance-owner-id"
    values = [data.aws_caller_identity.current.account_id]
  }

  dynamic "filter" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      name   = "subnet-id"
      values = var.subnet_ids
    }
  }
}

# All ENIs owned by any Nodal Probe module instance in this VPC. Used only to
# keep auto-discovery from selecting probe primary/sniff interfaces.
# Marker tag is NodalProbeManaged=true (not Name), so customer ENIs that happen
# to share display names are not excluded from mirroring.
data "aws_network_interfaces" "probe" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:NodalProbeManaged"
    values = ["true"]
  }
}

# When the caller pins source ENIs, verify each exists and belongs to vpc_id
# before creating mirror sessions (avoids mid-apply failures on wrong-VPC IDs).
data "aws_network_interface" "explicit_sources" {
  for_each = toset(var.source_eni_ids)

  id = each.value

  lifecycle {
    postcondition {
      condition     = self.vpc_id == var.vpc_id
      error_message = "source_eni_ids entry ${each.value} is not in vpc_id ${var.vpc_id}."
    }

    postcondition {
      condition     = try(self.attachment[0].instance_id, "") != ""
      error_message = "source_eni_ids entry ${each.value} is not attached to an EC2 instance and cannot be a Traffic Mirror source."
    }
  }
}
