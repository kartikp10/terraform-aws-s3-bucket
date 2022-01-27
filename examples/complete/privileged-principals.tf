locals {
  account_id = data.aws_caller_identity.current.account_id

  principal_names = [
    "arn:aws:iam::${local.account_id}:role/${join("", module.deployment_principal_label.*.id)}",
    "arn:aws:iam::${local.account_id}:role/${join("", module.additional_deployment_principal_label.*.id)}"
  ]

  privileged_principal_arns = var.privileged_principal_enabled ? {
    (local.principal_names[0]) = [""]
    (local.principal_names[1]) = ["prefix1/", "prefix2/"]
  } : {}
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "deployment_assume_role" {
  count = var.privileged_principal_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      identifiers = ["ec2.amazonaws.com"] # example: this role can be used in an IAM Instance Profile
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "deployment_iam_policy" {
  count = var.privileged_principal_enabled ? 1 : 0

  statement {
    actions   = var.privileged_principal_actions
    effect    = "Allow"
    resources = ["arn:aws:s3:::${module.this.id}*"]
  }
}

resource "aws_iam_policy" "deployment_iam_policy" {
  count = var.privileged_principal_enabled ? 1 : 0

  policy = join("", data.aws_iam_policy_document.deployment_iam_policy.*.json)
  tags = {
    yor_trace = "53f69a6f-fddb-4264-8eb0-f9ab7fc70f1d"
  }
}

module "deployment_principal_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = var.privileged_principal_enabled

  attributes = ["deployment"]

  context = module.this.context
}

resource "aws_iam_role" "deployment_iam_role" {
  count = var.privileged_principal_enabled ? 1 : 0

  name               = join("", module.deployment_principal_label.*.id)
  assume_role_policy = join("", data.aws_iam_policy_document.deployment_assume_role.*.json)

  tags = merge(module.deployment_principal_label.tags, {
    yor_trace = "e19f1423-9426-4cff-8d44-04344376670a"
  })
}

module "additional_deployment_principal_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = var.privileged_principal_enabled

  attributes = ["deployment", "additional"]

  context = module.this.context
}

resource "aws_iam_role" "additional_deployment_iam_role" {
  count = var.privileged_principal_enabled ? 1 : 0

  name               = join("", module.additional_deployment_principal_label.*.id)
  assume_role_policy = join("", data.aws_iam_policy_document.deployment_assume_role.*.json)

  tags = merge(module.additional_deployment_principal_label.tags, {
    yor_trace = "5c3971f6-729a-4279-a41f-598dc7568292"
  })
}

resource "aws_iam_role_policy_attachment" "additional_deployment_role_attachment" {
  count = var.privileged_principal_enabled ? 1 : 0

  policy_arn = join("", aws_iam_policy.deployment_iam_policy.*.arn)
  role       = join("", aws_iam_role.deployment_iam_role.*.name)
}
