# =============================================================================
# Cluster Autoscaler — IRSA role + IAM policy
#
# The autoscaler watches for Pending pods and scales the managed node group's
# ASG up (and scales idle nodes down). It auto-discovers the ASG via the tags
# EKS already puts on managed node groups:
#   k8s.io/cluster-autoscaler/enabled
#   k8s.io/cluster-autoscaler/<cluster-name>
#
# This file only creates the IAM side. Install the controller with Helm — see
# the `cluster_autoscaler_install_command` output.
# =============================================================================

data "aws_region" "current" {}

# --- IRSA trust: only kube-system/cluster-autoscaler SA may assume this role ---
data "aws_iam_policy_document" "cluster_autoscaler_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${local.name}-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume.json
  tags               = local.common_tags
}

# --- Least-privilege policy: read-any, mutate only this cluster's ASGs ---
data "aws_iam_policy_document" "cluster_autoscaler" {
  # Discovery / read — must be * so it can inspect all ASGs and instance types.
  statement {
    sid    = "Describe"
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }

  # Mutate — only ASGs tagged as belonging to THIS cluster.
  statement {
    sid    = "Mutate"
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }
  }
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name   = "${local.name}-cluster-autoscaler"
  role   = aws_iam_role.cluster_autoscaler.id
  policy = data.aws_iam_policy_document.cluster_autoscaler.json
}

# --- Outputs: role ARN + a ready-to-run Helm install command ---
output "cluster_autoscaler_role_arn" {
  description = "IAM role the cluster-autoscaler ServiceAccount assumes via IRSA."
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "cluster_autoscaler_install_command" {
  description = "Run after apply to install Cluster Autoscaler via Helm."
  value       = <<-EOT
    helm repo add autoscaler https://kubernetes.github.io/autoscaler && helm repo update
    helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
      -n kube-system \
      --set autoDiscovery.clusterName=${var.cluster_name} \
      --set awsRegion=${data.aws_region.current.region} \
      --set rbac.serviceAccount.name=cluster-autoscaler \
      --set "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${aws_iam_role.cluster_autoscaler.arn}" \
      --set extraArgs.balance-similar-node-groups=true \
      --set extraArgs.skip-nodes-with-system-pods=false \
      --set extraArgs.scale-down-unneeded-time=5m
  EOT
}
