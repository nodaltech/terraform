locals {
  tags = merge(
    {
      Component = "nodal-probe"
      ManagedBy = "Terraform"
    },
    var.tags,
  )

  ami_id = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ubuntu[0].value

  probe_subnet_id = coalesce(var.probe_subnet_id, try(sort(data.aws_subnets.vpc.ids)[0], null))

  private_key_path = coalesce(var.private_key_path, "${path.root}/nodal_probe.pem")

  vpc_cidrs = [for a in data.aws_vpc.target.cidr_block_associations : a.cidr_block]

  discovered_eni_ids = toset(data.aws_network_interfaces.sources.ids)

  # Exclude probe ENIs using a data source (known at plan) rather than
  # aws_network_interface.*.id (unknown on first apply, which breaks for_each).
  probe_eni_ids_discovered = toset(data.aws_network_interfaces.probe.ids)

  auto_source_eni_ids = setsubtract(
    setsubtract(local.discovered_eni_ids, local.probe_eni_ids_discovered),
    toset(var.exclude_eni_ids),
  )

  source_eni_ids = (
    length(var.source_eni_ids) > 0
    ? setsubtract(toset(var.source_eni_ids), local.probe_eni_ids_discovered)
    : local.auto_source_eni_ids
  )

  # Auto-assigned public IP on ens5 (not an Elastic IP).
  probe_public_ip = aws_instance.probe.public_ip
}
