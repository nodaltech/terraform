data "aws_region" "current" {}

data "aws_vpc" "target" {
  id = var.vpc_id
}

data "aws_subnets" "vpc" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_ssm_parameter" "ubuntu" {
  count = var.ami_id == null ? 1 : 0
  name  = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_network_interfaces" "sources" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "status"
    values = ["in-use"]
  }

  filter {
    name   = "interface-type"
    values = ["interface"]
  }

  dynamic "filter" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      name   = "subnet-id"
      values = var.subnet_ids
    }
  }
}

# Looked up via tags (not resource IDs) so for_each on mirror sessions stays
# known at plan. Empty on first apply; populated on later refreshes.
data "aws_network_interfaces" "probe" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["Nodal Probe Primary", "Nodal Probe Sniff"]
  }
}
