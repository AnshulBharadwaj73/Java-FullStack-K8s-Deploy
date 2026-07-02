output "role_arn" {
  description = "Annotate the LBC ServiceAccount with this: eks.amazonaws.com/role-arn"
  value       = aws_iam_role.lbc.arn
}

output "role_name" {
  value = aws_iam_role.lbc.name
}

output "helm_install_command" {
  description = "Copy-paste this after terraform apply to install the controller."
  value       = <<-EOT
    helm repo add eks https://aws.github.io/eks-charts && helm repo update
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName=${var.cluster_name} \
      --set region=${var.region} \
      --set vpcId=${var.vpc_id} \
      --set serviceAccount.create=true \
      --set serviceAccount.name=${var.service_account_name} \
      --set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${aws_iam_role.lbc.arn}"
  EOT
}
