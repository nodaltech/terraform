resource "aws_security_group" "primary" {
  name_prefix = "nodal-probe-primary-"
  description = "Nodal Probe primary NIC (SSM management; no inbound required)"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "Nodal Probe Primary" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.allowed_ssh_cidrs)

  security_group_id = aws_security_group.primary.id
  description       = "Optional SSH (not used for Terraform provisioning)"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
  tags              = merge(local.tags, { Name = "Nodal Probe SSH" })
}

resource "aws_vpc_security_group_egress_rule" "primary" {
  for_each = local.probe_egress_rules

  security_group_id = aws_security_group.primary.id
  description       = each.value.description
  ip_protocol       = each.value.ip_protocol
  from_port         = each.value.ip_protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.ip_protocol == "-1" ? null : each.value.to_port
  cidr_ipv4         = each.value.cidr_ipv4
  tags              = merge(local.tags, { Name = "Nodal Probe Primary Egress" })
}

resource "aws_security_group" "sniff" {
  name_prefix = "nodal-probe-sniff-"
  description = "Nodal Probe sniff NIC (VXLAN traffic mirror target)"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "Nodal Probe Sniff" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vxlan" {
  for_each = toset(local.vpc_cidrs)

  security_group_id = aws_security_group.sniff.id
  description       = "VXLAN traffic mirroring from VPC ${each.value}"
  ip_protocol       = "udp"
  from_port         = 4789
  to_port           = 4789
  cidr_ipv4         = each.value
  tags              = merge(local.tags, { Name = "Nodal Probe VXLAN" })
}
