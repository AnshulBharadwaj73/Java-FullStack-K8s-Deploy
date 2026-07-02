# Wraps the iam-groups and iam-users sub-modules so the caller can declare a
# map of groups (with attached policies) and a map of users (with group
# memberships) in one place.

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------
# Groups
# ---------------------------------------------------------
module "groups" {
  source   = "./modules/iam-groups"
  for_each = var.groups

  group_name       = each.key
  environment      = var.environment
  managed_policies = each.value.managed_policies
  inline_policies  = each.value.inline_policies
  tags             = merge(var.tags, lookup(each.value, "tags", {}))
}

# ---------------------------------------------------------
# Users
# ---------------------------------------------------------
module "users" {
  source   = "./modules/iam-users"
  for_each = var.users

  username              = each.key
  environment           = var.environment
  groups                = each.value.groups
  create_access_key     = lookup(each.value, "create_access_key", true)
  create_console_access = lookup(each.value, "create_console_access", true)
  tags                  = merge(var.tags, lookup(each.value, "tags", {}))

  depends_on = [module.groups]
}

# ---------------------------------------------------------
# One credentials file per user (sensitive, gitignored).
# ---------------------------------------------------------
resource "local_sensitive_file" "credentials" {
  for_each = var.write_credential_files ? var.users : {}

  filename = "${path.root}/credentials-${var.environment}-${each.key}.txt"
  content  = <<-EOT
    ========================================
    IAM User Credentials
    ========================================
    Username:        ${module.users[each.key].user_name}
    Account ID:      ${data.aws_caller_identity.current.account_id}
    Console Login:   https://${var.aws_region}.signin.aws.amazon.com/console

    Programmatic:
      Access Key ID: ${module.users[each.key].access_key_id}
      Secret Key:    ${module.users[each.key].secret_access_key}

    Console:
      Password:      ${module.users[each.key].console_password}
    ========================================
  EOT
}
