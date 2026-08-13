module "nodal_probe" {
  source = "./modules/nodal-probe"

  vpc_id               = var.vpc_id
  probe_installer_path = abspath(var.probe_installer_path)
  probe_subnet_id      = var.probe_subnet_id
  source_eni_ids       = var.source_eni_ids
  exclude_eni_ids      = var.exclude_eni_ids
  subnet_ids           = var.subnet_ids
  allowed_ssh_cidrs    = var.allowed_ssh_cidrs
  instance_type        = var.instance_type
  ami_id               = var.ami_id
  root_volume_size     = var.root_volume_size
  tags                 = var.tags
}
