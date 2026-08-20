output "instance_id" {
  description = "EC2 instance ID of the Nodal Probe."
  value       = module.nodal_probe.instance_id
}

output "public_ip" {
  description = "Auto-assigned public IPv4 of the primary NIC, if enabled. Empty for typical private-subnet deployments."
  value       = module.nodal_probe.public_ip
}

output "private_ip" {
  description = "Private IP of the probe primary NIC (ens5)."
  value       = module.nodal_probe.private_ip
}

output "sniff_private_ip" {
  description = "Private IP of the sniff NIC (ens6, traffic mirror target)."
  value       = module.nodal_probe.sniff_private_ip
}

output "ssm_start_session_command" {
  description = "AWS CLI command to open an SSM Session Manager shell on the probe."
  value       = module.nodal_probe.ssm_start_session_command
}

output "installer_s3_uri" {
  description = "Private s3:// URI of the staged probe.zip."
  value       = module.nodal_probe.installer_s3_uri
}

output "discovered_eni_ids" {
  description = "Account-owned EC2 ENIs discovered as mirror candidates. Empty when source_eni_ids is set."
  value       = module.nodal_probe.discovered_eni_ids
}

output "mirrored_eni_ids" {
  description = "ENIs with traffic mirror sessions pointing at the Nodal Probe."
  value       = module.nodal_probe.mirrored_eni_ids
}

output "traffic_mirror_target_id" {
  description = "Traffic mirror target ID."
  value       = module.nodal_probe.traffic_mirror_target_id
}

output "traffic_mirror_session_ids" {
  description = "Map of source ENI ID to traffic mirror session ID."
  value       = module.nodal_probe.traffic_mirror_session_ids
}
