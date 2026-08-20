resource "aws_ssm_document" "install" {
  # Name is derived from the installer bucket so it stays stable if the EC2
  # instance is replaced, while remaining unique per module instance.
  name            = "NodalProbeInstall-${local.install_name_suffix}"
  document_type   = "Command"
  document_format = "JSON"
  tags            = merge(local.tags, { Name = "Nodal Probe Install" })

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Download probe.zip from the module-managed private S3 object and run the Nodal Probe installer."
    parameters = {
      InstallerEtag = {
        type        = "String"
        description = "S3 object etag; changing it re-runs the association."
      }
    }
    mainSteps = [
      {
        action = "aws:downloadContent"
        name   = "DownloadInstaller"
        inputs = {
          sourceType      = "S3"
          destinationPath = "/home/ubuntu"
          sourceInfo = {
            path = local.installer_https_url
          }
        }
      },
      {
        action = "aws:runShellScript"
        name   = "InstallProbe"
        inputs = {
          timeoutSeconds   = tostring(var.ssm_install_timeout_seconds)
          workingDirectory = "/home/ubuntu"
          runCommand = concat(
            [
              "export AWS_DEFAULT_REGION='${data.aws_region.current.region}'",
            ],
            [
              for line in split("\n", file("${path.module}/scripts/install_probe.sh")) : line
              if trimspace(line) != ""
            ],
          )
        }
      },
    ]
  })
}

# Terraform waits for association Success. The AWS DescribeAssociation API
# has historically reported Success before the first execution finished when
# the instance was still initializing. Targeting a single instance and waiting
# for Success is still the most deterministic provider-native mechanism;
# increase ssm_install_timeout_seconds if agent registration is slow.
resource "aws_ssm_association" "install" {
  name             = aws_ssm_document.install.name
  association_name = "NodalProbeInstall-${local.install_name_suffix}"

  parameters = {
    InstallerEtag = aws_s3_object.installer.etag
  }

  targets {
    key    = "InstanceIds"
    values = [aws_instance.probe.id]
  }

  wait_for_success_timeout_seconds = var.ssm_install_timeout_seconds

  depends_on = [
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.installer_read,
    aws_network_interface_attachment.sniff,
    aws_s3_object.installer,
    aws_ec2_tag.primary_eni_name,
    aws_ec2_tag.primary_eni_managed,
  ]
}
