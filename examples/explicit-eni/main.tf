provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "AWS region for this example."
  default     = "us-west-2"
}

variable "vpc_id" {
  type = string
}

variable "probe_subnet_id" {
  type = string
}

variable "probe_installer_path" {
  type    = string
  default = "probe.zip"
}

variable "source_eni_ids" {
  type = list(string)
}

module "nodal_probe" {
  source = "../../modules/nodal-probe"

  vpc_id                      = var.vpc_id
  probe_subnet_id             = var.probe_subnet_id
  probe_installer_path        = abspath(var.probe_installer_path)
  source_eni_ids              = var.source_eni_ids
  instance_type               = "t3.xlarge"
  root_volume_size            = 50
  associate_public_ip_address = false

  tags = {
    Environment = "dev"
    Owner       = "infrastructure"
  }
}
