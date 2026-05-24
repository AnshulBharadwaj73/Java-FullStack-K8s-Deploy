# Group outputs
output "dev_group_name" {
  value = module.dev_group.group_name
}

data "aws_caller_identity" "current" {
  
}

# output "ops_group_name" {
#   value = module.ops_group.group_name
# }

# User outputs
output "dev_users" {
  value = {
    alice = {
      username          = module.dev_alice.user_name
      access_key_id     = module.dev_alice.access_key_id
      secret_access_key = module.dev_alice.secret_access_key
      console_password  = module.dev_alice.console_password
    }
  }
  sensitive = true
}

# Generate credentials files for users
resource "local_sensitive_file" "dev_credentials" {
  count = 1
  filename = "credentials-dev-${module.dev_alice.user_name}.txt"
  content = <<-EOT
    ========================================
    IAM User Credentials
    ========================================
    Username: ${module.dev_alice.user_name}
    Console Login: https://${var.aws_region}.signin.aws.amazon.com/console
    
    Programmatic Access:
    AWS Access Key ID: ${module.dev_alice.access_key_id}
    AWS Secret Access Key: ${module.dev_alice.secret_access_key}
    
    Console Access:
    Password: ${module.dev_alice.console_password}

    Account ID: ${data.aws_caller_identity.current.account_id}

    ========================================
  EOT
#   sensitive = true 
}