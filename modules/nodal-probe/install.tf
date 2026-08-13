resource "terraform_data" "probe_install" {
  triggers_replace = [
    aws_instance.probe.id,
    filemd5(var.probe_installer_path),
  ]

  input = {
    public_ip = local.probe_public_ip
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.probe.private_key_pem
    host        = local.probe_public_ip
    timeout     = "15m"
  }

  provisioner "file" {
    source      = var.probe_installer_path
    destination = "/home/ubuntu/probe.zip"
  }

  provisioner "remote-exec" {
    script = "${path.module}/scripts/install_probe.sh"
  }

  lifecycle {
    precondition {
      condition     = local.probe_public_ip != null && local.probe_public_ip != ""
      error_message = "Nodal Probe has no public IP. Set probe_subnet_id to a public subnet (IGW route)."
    }
  }

  depends_on = [
    aws_instance.probe,
    terraform_data.sniff_attach,
    local_sensitive_file.probe_pem,
  ]
}
