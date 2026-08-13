resource "tls_private_key" "probe" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "probe" {
  key_name_prefix = "${var.key_name_prefix}-"
  public_key      = tls_private_key.probe.public_key_openssh
  tags            = merge(local.tags, { Name = "Nodal Probe" })
}

resource "local_sensitive_file" "probe_pem" {
  content         = tls_private_key.probe.private_key_pem
  filename        = local.private_key_path
  file_permission = "0400"
}
