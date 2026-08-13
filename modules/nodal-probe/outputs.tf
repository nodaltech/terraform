output "instance_id" {
  description = "EC2 instance ID of the Nodal Probe."
  value       = aws_instance.probe.id
}

output "public_ip" {
  description = "Auto-assigned public IP of ens5 (not an Elastic IP). Sniff NIC has no public IP."
  value       = local.probe_public_ip
}

output "private_ip" {
  description = "Private IP of the probe primary NIC (ens5)."
  value       = aws_instance.probe.private_ip
}

output "sniff_private_ip" {
  description = "Private IP of the probe sniff NIC (ens6, traffic mirror target)."
  value       = aws_network_interface.sniff.private_ip
}

output "primary_eni_id" {
  description = "ENI ID of the probe primary NIC."
  value       = aws_instance.probe.primary_network_interface_id
}

output "sniff_eni_id" {
  description = "ENI ID of the probe sniff NIC (traffic mirror target)."
  value       = aws_network_interface.sniff.id
}

output "private_key_path" {
  description = "Local path to the generated SSH private key."
  value       = local_sensitive_file.probe_pem.filename
}

output "key_pair_name" {
  description = "AWS key pair name."
  value       = aws_key_pair.probe.key_name
}

output "ssh_command" {
  description = "SSH command for the probe (ens5 auto-assigned public IP)."
  value       = "ssh -i ${local_sensitive_file.probe_pem.filename} -o StrictHostKeyChecking=accept-new ubuntu@${local.probe_public_ip}"
}

output "subnet_ids" {
  description = "All subnet IDs discovered in the target VPC."
  value       = data.aws_subnets.vpc.ids
}

output "discovered_eni_ids" {
  description = "In-use interface ENIs discovered in the VPC before exclusions."
  value       = sort(tolist(local.discovered_eni_ids))
}

output "mirrored_eni_ids" {
  description = "ENI IDs that have traffic mirror sessions pointing at the probe."
  value       = sort(tolist(local.source_eni_ids))
}

output "traffic_mirror_target_id" {
  description = "Traffic mirror target ID."
  value       = aws_ec2_traffic_mirror_target.probe.id
}

output "traffic_mirror_filter_id" {
  description = "Traffic mirror filter ID."
  value       = aws_ec2_traffic_mirror_filter.all.id
}

output "traffic_mirror_session_ids" {
  description = "Map of source ENI ID to traffic mirror session ID."
  value       = { for eni, session in aws_ec2_traffic_mirror_session.eni : eni => session.id }
}

output "probe_subnet_id" {
  description = "Subnet where the Nodal Probe was placed."
  value       = local.probe_subnet_id
}

output "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to the probe."
  value       = var.allowed_ssh_cidrs
}
