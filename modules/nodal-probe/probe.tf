resource "aws_network_interface" "sniff" {
  subnet_id         = data.aws_subnet.probe.id
  security_groups   = [aws_security_group.sniff.id]
  description       = "Nodal Probe sniffer network interface (traffic mirror target)"
  source_dest_check = true
  tags = merge(local.tags, {
    Name              = "Nodal Probe Sniff"
    NodalProbeManaged = "true"
  })
}

# Primary NIC is instance-managed so associate_public_ip_address can be set
# without a dedicated aws_network_interface for ens5. The sniff NIC is a
# separate ENI attached at device index 1 (typically ens6).
resource "aws_instance" "probe" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.probe.id
  vpc_security_group_ids      = [aws_security_group.primary.id]
  associate_public_ip_address = var.associate_public_ip_address
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.probe.name
  user_data_base64            = base64encode(file("${path.module}/templates/user_data.sh"))

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags                  = merge(local.tags, { Name = "Nodal Probe Root" })
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.tags, {
    Name              = "Nodal Probe"
    NodalProbeManaged = "true"
  })

  lifecycle {
    ignore_changes = [ami, user_data_base64]
  }

  # Instance profile association is not enough; the managed policy and S3
  # installer read policy must exist before the SSM agent registers.
  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.installer_read,
  ]
}

resource "aws_ec2_tag" "primary_eni_name" {
  resource_id = aws_instance.probe.primary_network_interface_id
  key         = "Name"
  value       = "Nodal Probe Primary"
}

# Dedicated marker used to exclude ALL Nodal probe ENIs from auto-discovery
# (including other module instances). Prefer this over Name-tag matching so
# unrelated customer ENIs named similarly are not skipped as sources.
resource "aws_ec2_tag" "primary_eni_managed" {
  resource_id = aws_instance.probe.primary_network_interface_id
  key         = "NodalProbeManaged"
  value       = "true"
}

# Attach sniff as device index 1 (ens6). This resource is used instead of
# local-exec so attach/detach uses the Terraform AWS provider credentials.
#
# Destroy order is modeled so the ENI is not detached while it is still a
# traffic mirror target (that combination previously hung):
#   sessions -> target -> this attachment -> instance / sniff ENI
# aws_ec2_traffic_mirror_target.probe depends_on this attachment.
resource "aws_network_interface_attachment" "sniff" {
  instance_id          = aws_instance.probe.id
  network_interface_id = aws_network_interface.sniff.id
  device_index         = 1
}
