output "instance_id" {
  description = "EC2 instance ID of the Nodal Probe."
  value       = aws_instance.probe.id
}

output "public_ip" {
  description = "Auto-assigned public IPv4 of the primary NIC, if associate_public_ip_address is true. Empty for typical private-subnet deployments."
  value       = aws_instance.probe.public_ip
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

output "iam_role_name" {
  description = "IAM role name assumed by the probe instance."
  value       = aws_iam_role.probe.name
}

output "iam_instance_profile_name" {
  description = "IAM instance profile name attached to the probe."
  value       = aws_iam_instance_profile.probe.name
}

output "installer_s3_uri" {
  description = "Private s3:// URI of the staged probe.zip. Not a public URL."
  value       = local.installer_s3_uri
}

output "ssm_association_id" {
  description = "SSM State Manager association ID that installs the probe."
  value       = aws_ssm_association.install.id
}

output "ssm_start_session_command" {
  description = "AWS CLI command to open an SSM Session Manager shell on the probe."
  value       = "aws ssm start-session --target ${aws_instance.probe.id} --region ${data.aws_region.current.region}"
}

output "discovered_eni_ids" {
  description = "Account-owned, in-use EC2 ENIs discovered as mirror candidates. Empty when source_eni_ids is set."
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
  value       = data.aws_subnet.probe.id
}
