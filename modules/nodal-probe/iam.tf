data "aws_iam_policy_document" "probe_assume" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "probe" {
  name_prefix        = "nodal-probe-"
  assume_role_policy = data.aws_iam_policy_document.probe_assume.json
  tags               = merge(local.tags, { Name = "Nodal Probe" })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.probe.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "installer_read" {
  statement {
    sid     = "GetInstallerObject"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.installer.arn}/${local.installer_object_key}",
    ]
  }
}

resource "aws_iam_role_policy" "installer_read" {
  name_prefix = "nodal-probe-installer-"
  role        = aws_iam_role.probe.id
  policy      = data.aws_iam_policy_document.installer_read.json
}

resource "aws_iam_instance_profile" "probe" {
  name_prefix = "nodal-probe-"
  role        = aws_iam_role.probe.name
  tags        = merge(local.tags, { Name = "Nodal Probe" })
}
