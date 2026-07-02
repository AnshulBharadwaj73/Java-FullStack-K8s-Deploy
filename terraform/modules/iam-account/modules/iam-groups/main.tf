# IAM Group Module
resource "aws_iam_group" "this" {
  name = var.group_name
  path = var.path
}

# Attach managed policies
resource "aws_iam_group_policy_attachment" "managed" {
  count      = length(var.managed_policies) > 0 ? length(var.managed_policies) : 0
  group      = aws_iam_group.this.name
  policy_arn = var.managed_policies[count.index]
}

# Attach inline policies
resource "aws_iam_group_policy" "inline" {
  count  = length(var.inline_policies) > 0 ? length(var.inline_policies) : 0
  name   = var.inline_policies[count.index].name
  group  = aws_iam_group.this.name
  policy = var.inline_policies[count.index].policy
}