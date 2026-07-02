# IRSA role + IAM policy for the AWS Load Balancer Controller.
# After apply, install the controller itself with:
#
#   helm repo add eks https://aws.github.io/eks-charts
#   helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
#     -n kube-system \
#     --set clusterName=<cluster-name> \
#     --set serviceAccount.create=true \
#     --set serviceAccount.name=aws-load-balancer-controller \
#     --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<this module's role_arn output>
#
# Once the controller is up, any Ingress in the cluster with
# `ingressClassName: alb` will get a real AWS ALB provisioned automatically.

data "aws_caller_identity" "current" {}

# Trust policy — only the cluster's specific service account can assume the role.
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  name               = "${var.cluster_name}-aws-lbc"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# Fetch the canonical IAM policy from the upstream LBC repo.
# Bumping `lbc_policy_version` is how you adopt a new controller version.
data "http" "lbc_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${var.lbc_policy_version}/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc" {
  name        = "${var.cluster_name}-aws-lbc-policy"
  description = "Permissions for AWS Load Balancer Controller to manage ALBs/NLBs/TGs/SGs"
  policy      = data.http.lbc_policy.response_body
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}
