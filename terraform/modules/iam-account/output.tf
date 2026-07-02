output "group_names" {
  value = { for k, m in module.groups : k => m.group_name }
}

output "group_arns" {
  value = { for k, m in module.groups : k => m.group_arn }
}

output "users" {
  description = "Per-user identifiers and (sensitive) credentials."
  sensitive   = true
  value = {
    for k, m in module.users : k => {
      username          = m.user_name
      access_key_id     = m.access_key_id
      secret_access_key = m.secret_access_key
      console_password  = m.console_password
    }
  }
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
