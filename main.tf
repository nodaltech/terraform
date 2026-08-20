module "nodal_probe" {
  source = "./modules/nodal-probe"

  vpc_id                      = var.vpc_id
  probe_installer_path        = abspath(var.probe_installer_path)
  probe_subnet_id             = var.probe_subnet_id
  source_eni_ids              = var.source_eni_ids
  enable_eni_auto_discovery   = var.enable_eni_auto_discovery
  exclude_eni_ids             = var.exclude_eni_ids
  subnet_ids                  = var.subnet_ids
  instance_type               = var.instance_type
  ami_id                      = var.ami_id
  root_volume_size            = var.root_volume_size
  associate_public_ip_address = var.associate_public_ip_address
  key_name                    = var.key_name
  allowed_ssh_cidrs           = var.allowed_ssh_cidrs
  session_number              = var.session_number
  tags                        = var.tags
}
