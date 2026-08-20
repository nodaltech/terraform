resource "aws_ec2_traffic_mirror_target" "probe" {
  description          = "Nodal Probe traffic mirror target"
  network_interface_id = aws_network_interface.sniff.id
  tags                 = merge(local.tags, { Name = "Nodal Probe" })

  # Keep the target after the attachment on create, and destroy the target
  # before detach. Detaching a live mirror-target ENI previously hung.
  depends_on = [aws_network_interface_attachment.sniff]
}

resource "aws_ec2_traffic_mirror_filter" "all" {
  description = "Nodal Probe accept-all ingress and egress"
  tags        = merge(local.tags, { Name = "Nodal Probe" })
}

resource "aws_ec2_traffic_mirror_filter_rule" "ingress" {
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.all.id
  description              = "Accept all ingress"
  rule_number              = 100
  rule_action              = "accept"
  traffic_direction        = "ingress"
  source_cidr_block        = "0.0.0.0/0"
  destination_cidr_block   = "0.0.0.0/0"
}

resource "aws_ec2_traffic_mirror_filter_rule" "egress" {
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.all.id
  description              = "Accept all egress"
  rule_number              = 100
  rule_action              = "accept"
  traffic_direction        = "egress"
  source_cidr_block        = "0.0.0.0/0"
  destination_cidr_block   = "0.0.0.0/0"
}

resource "aws_ec2_traffic_mirror_session" "eni" {
  for_each = local.source_eni_ids

  description              = "Nodal Probe session for ${each.value}"
  network_interface_id     = each.value
  traffic_mirror_target_id = aws_ec2_traffic_mirror_target.probe.id
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.all.id
  session_number           = var.session_number
  tags                     = merge(local.tags, { Name = "Nodal Probe ${each.value}" })

  # Explicit ENI lookups must succeed (and satisfy postconditions) first.
  # Source-selection preconditions must pass before sessions are created.
  depends_on = [
    data.aws_network_interface.explicit_sources,
    terraform_data.source_selection,
  ]
}
