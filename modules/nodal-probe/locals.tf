locals {
  tags = merge(
    {
      Component = "nodal-probe"
      ManagedBy = "Terraform"
    },
    var.tags,
  )

  ami_id = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.ubuntu[0].value

  vpc_cidrs = [for a in data.aws_vpc.target.cidr_block_associations : a.cidr_block]

  discovered_eni_ids = toset(flatten([
    for d in data.aws_network_interfaces.sources : d.ids
  ]))

  # Exclude probe ENIs using a data source (known at plan) rather than
  # aws_network_interface.*.id (unknown on first apply, which breaks for_each).
  probe_eni_ids_discovered = toset(data.aws_network_interfaces.probe.ids)

  auto_source_eni_ids = setsubtract(
    setsubtract(local.discovered_eni_ids, local.probe_eni_ids_discovered),
    toset(var.exclude_eni_ids),
  )

  # Explicit mode still drops this module's probe ENIs if someone lists them.
  source_eni_ids = (
    length(var.source_eni_ids) > 0
    ? setsubtract(toset(var.source_eni_ids), local.probe_eni_ids_discovered)
    : (
      var.enable_eni_auto_discovery
      ? local.auto_source_eni_ids
      : toset([])
    )
  )

  installer_object_key = "probe.zip"
  installer_s3_uri     = "s3://${aws_s3_bucket.installer.id}/${aws_s3_object.installer.key}"
  installer_https_url  = "https://${aws_s3_bucket.installer.bucket}.s3.${data.aws_region.current.region}.amazonaws.com/${aws_s3_object.installer.key}"

  # Stable across instance replacements; unique per module-managed bucket.
  install_name_suffix = substr(sha1(aws_s3_bucket.installer.bucket), 0, 12)

  # Content-addressed keys so reordering probe_egress_rules does not rewrite
  # unrelated aws_vpc_security_group_egress_rule resources.
  probe_egress_rules = {
    for rule in var.probe_egress_rules :
    md5(jsonencode(rule)) => rule
  }
}

# Fail closed: do not create a probe that silently mirrors nothing, and do not
# allow accidental VPC-wide mirroring without an explicit opt-in.
resource "terraform_data" "source_selection" {
  input = {
    explicit_count = length(var.source_eni_ids)
    auto_enabled   = var.enable_eni_auto_discovery
    selected_count = length(local.source_eni_ids)
  }

  lifecycle {
    precondition {
      condition     = length(var.source_eni_ids) > 0 || var.enable_eni_auto_discovery
      error_message = "Set source_eni_ids to the ENI(s) to mirror, or set enable_eni_auto_discovery = true to opt into VPC-wide discovery of account-owned EC2 ENIs. Auto-discovery is off by default because it can attach Traffic Mirror sessions to unrelated workloads."
    }

    precondition {
      condition     = length(local.source_eni_ids) > 0
      error_message = "No Traffic Mirror source ENIs were selected. Provide source_eni_ids, or enable auto-discovery and ensure eligible account-owned EC2 ENIs exist (review subnet_ids and exclude_eni_ids)."
    }
  }
}

check "explicit_sources_not_probe_enis" {
  assert {
    condition     = length(setintersection(toset(var.source_eni_ids), local.probe_eni_ids_discovered)) == 0
    error_message = "source_eni_ids includes ENIs tagged NodalProbeManaged=true (this or another Nodal Probe). Those IDs are skipped; remove them from source_eni_ids."
  }
}

check "auto_discovery_scale" {
  assert {
    condition     = !var.enable_eni_auto_discovery || length(local.source_eni_ids) <= 25
    error_message = "Auto-discovery selected more than 25 ENIs. Prefer explicit source_eni_ids, or narrow with subnet_ids/exclude_eni_ids, before mirroring a large shared VPC."
  }
}
