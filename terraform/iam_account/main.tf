module "dev_group" {
  source = "./modules/iam-groups"
  group_name = "dev-team"
  environment = var.environment
  
  managed_policies = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicFullAccess",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/IAMUserChangePassword",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy",
    "arn:aws:iam::aws:policy/AWSElasticLoadBalancingFullAccess"
    ]
    inline_policies = [
    {
      name = "deny-billing"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Deny"
            Action = [
              "aws-portal:*",
              "budgets:*",
              "ce:*"
            ]
            Resource = "*"
          }
        ]
      })
    }
  ]
    tags = var.tags
}

# module "ops_group" {
#   source = "./modules/iam-groups"

#   group_name= ""
  
# }

module "dev_alice" {
  source = "./modules/iam-users"

  username = "alice.dev"
  environment = var.environment

  groups = [module.dev_group.group_name]

  create_access_key = true
  create_console_access = true

  tags = {
    "Role" = "Developer"
    Team = "Backend"
  }
}

