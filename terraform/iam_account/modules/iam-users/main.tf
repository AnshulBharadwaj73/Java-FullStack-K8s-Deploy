resource "aws_iam_user" "this" {
  name = var.username
  path = var.path

  tags = merge(var.tags, {
    Name =var.username
    Environment = var.environment
    })
}

resource "aws_iam_access_key" "access_key" {
	count = var.create_access_key ? 1 : 0
  	user = aws_iam_user.this.name
}

# Create Login Profile for Console Access
resource "aws_iam_user_login_profile" "user_profile" {
  count                   = var.create_console_access ? 1 : 0
  user                    = aws_iam_user.this.name
  password_length         = 16
  password_reset_required = var.password_reset_required
}

resource "random_password" "rand_password" {
	count = var.create_console_access && var.console_password == "" ? 1 : 0
	length = 16
	special = true
	override_special = "!#$%&*()-_=+[]{}<>:?"
	min_lower = 1
	min_upper = 1
	min_numeric = 1	
	min_special = 1
}



resource "aws_iam_user_group_membership" "groups" {
	count = length(var.groups) > 0 ? 1 : 0
	user =aws_iam_user.this.name
	groups = var.groups
}

resource "aws_iam_user_policy_attachment" "managed" {
	count      = length(var.managed_policies) > 0 ? length(var.managed_policies) : 0
  	user       = aws_iam_user.this.name
  	policy_arn = var.managed_policies[count.index]
}

resource "aws_iam_user_policy" "inline" {
	count  = length(var.inline_policies) > 0 ? length(var.inline_policies) : 0
  	name   = var.inline_policies[count.index].name
  	user   = aws_iam_user.this.name
  	policy = var.inline_policies[count.index].policy
}

