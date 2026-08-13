provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project   = "Nodal Probe"
        ManagedBy = "Terraform"
      },
      var.tags,
    )
  }
}
