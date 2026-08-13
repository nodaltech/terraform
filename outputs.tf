output "instance_id" {
  description = "EC2 instance ID of the Nodal Probe."
  value       = module.nodal_probe.instance_id
}

output "public_ip" {
  description = "Auto-assigned public IP of ens5 (not an Elastic IP)."
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

output "ssh_command" {
  description = "SSH command using the generated nodal_probe.pem key."
  value       = module.nodal_probe.ssh_command
}

output "private_key_path" {
  description = "Local path to nodal_probe.pem."
  value       = module.nodal_probe.private_key_path
}

output "subnet_ids" {
  description = "All subnet IDs discovered in the target VPC."
  value       = module.nodal_probe.subnet_ids
}

output "discovered_eni_ids" {
  description = "In-use interface ENIs discovered in the VPC."
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
