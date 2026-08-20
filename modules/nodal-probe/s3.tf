# Private, module-managed staging for probe.zip. bucket_prefix keeps names
# unique so multiple module instances can coexist in one account.
resource "aws_s3_bucket" "installer" {
  bucket_prefix = "nodal-probe-"
  force_destroy = true
  tags          = merge(local.tags, { Name = "Nodal Probe Installer" })
}

resource "aws_s3_bucket_public_access_block" "installer" {
  bucket = aws_s3_bucket.installer.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "installer" {
  bucket = aws_s3_bucket.installer.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "installer" {
  bucket = aws_s3_bucket.installer.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "installer_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.installer.arn,
      "${aws_s3_bucket.installer.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "installer" {
  bucket = aws_s3_bucket.installer.id
  policy = data.aws_iam_policy_document.installer_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.installer]
}

resource "aws_s3_object" "installer" {
  bucket                 = aws_s3_bucket.installer.id
  key                    = local.installer_object_key
  source                 = var.probe_installer_path
  etag                   = filemd5(var.probe_installer_path)
  server_side_encryption = "AES256"
  content_type           = "application/zip"
  tags                   = merge(local.tags, { Name = "Nodal Probe Installer" })

  depends_on = [
    aws_s3_bucket_server_side_encryption_configuration.installer,
    aws_s3_bucket_ownership_controls.installer,
    aws_s3_bucket_policy.installer,
  ]
}
