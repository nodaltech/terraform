resource "aws_network_interface" "sniff" {
  subnet_id         = local.probe_subnet_id
  security_groups   = [aws_security_group.sniff.id]
  description       = "Nodal Probe sniffer network interface (traffic mirror target)"
  source_dest_check = true
  tags              = merge(local.tags, { Name = "Nodal Probe Sniff" })

  lifecycle {
    precondition {
      condition     = local.probe_subnet_id != null
      error_message = "The target VPC has no subnets. Set probe_subnet_id or choose a VPC that already has subnets."
    }
  }
}

# Primary NIC is instance-managed so associate_public_ip_address can assign a
# public IPv4 address without an Elastic IP. The sniff NIC is a separate ENI.
resource "aws_instance" "probe" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.probe_subnet_id
  vpc_security_group_ids      = [aws_security_group.primary.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.probe.key_name
  iam_instance_profile        = aws_iam_instance_profile.probe.name
  user_data                   = file("${path.module}/templates/user_data.sh")

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

  tags = merge(local.tags, { Name = "Nodal Probe" })

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

resource "aws_ec2_tag" "primary_eni_name" {
  resource_id = aws_instance.probe.primary_network_interface_id
  key         = "Name"
  value       = "Nodal Probe Primary"
}

# Attach sniff as ens6 (device index 1) on create only.
# aws_network_interface_attachment hangs on destroy because Terraform detaches
# while the instance is still running (and the ENI was a mirror target). We
# Do not detach here; instance termination releases the ENI.
resource "terraform_data" "sniff_attach" {
  triggers_replace = [
    aws_instance.probe.id,
    aws_network_interface.sniff.id,
  ]

  input = {
    instance_id = aws_instance.probe.id
    eni_id      = aws_network_interface.sniff.id
  }

  provisioner "local-exec" {
    command = "aws ec2 attach-network-interface --network-interface-id ${aws_network_interface.sniff.id} --instance-id ${aws_instance.probe.id} --device-index 1 --region ${data.aws_region.current.name}"
  }
}
