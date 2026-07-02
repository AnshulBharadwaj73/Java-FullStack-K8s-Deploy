locals {
  ns = "ContainerInsights"
  d  = { ClusterName = var.cluster_name }
}

# ----- Cluster-wide -----
resource "aws_cloudwatch_metric_alarm" "failed_nodes" {
  alarm_name          = "${var.cluster_name}-failed-nodes"
  alarm_description   = "One or more EKS nodes in NotReady state"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  evaluation_periods  = 2
  period              = 60
  statistic           = "Maximum"
  namespace           = local.ns
  metric_name         = "cluster_failed_node_count"
  dimensions          = local.d
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  tags                = var.tags
}

# ----- Per-node CPU -----
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${var.cluster_name}-node-cpu-high"
  alarm_description   = "Average node CPU > 85% for 10m"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 85
  evaluation_periods  = 10
  period              = 60
  statistic           = "Average"
  namespace           = local.ns
  metric_name         = "node_cpu_utilization"
  dimensions          = local.d
  alarm_actions       = var.alarm_actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  alarm_name          = "${var.cluster_name}-node-memory-high"
  alarm_description   = "Average node memory > 85% for 10m"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 85
  evaluation_periods  = 10
  period              = 60
  statistic           = "Average"
  namespace           = local.ns
  metric_name         = "node_memory_utilization"
  dimensions          = local.d
  alarm_actions       = var.alarm_actions
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "node_disk_high" {
  alarm_name          = "${var.cluster_name}-node-disk-high"
  alarm_description   = "Node filesystem > 85% used"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 85
  evaluation_periods  = 5
  period              = 60
  statistic           = "Maximum"
  namespace           = local.ns
  metric_name         = "node_filesystem_utilization"
  dimensions          = local.d
  alarm_actions       = var.alarm_actions
  tags                = var.tags
}

# ----- Pods restarting -----
resource "aws_cloudwatch_metric_alarm" "pod_restarting" {
  alarm_name          = "${var.cluster_name}-pod-restarts"
  alarm_description   = ">5 pod restarts in the cluster within 5m"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5
  evaluation_periods  = 5
  period              = 60
  statistic           = "Sum"
  namespace           = local.ns
  metric_name         = "pod_number_of_container_restarts"
  dimensions          = local.d
  alarm_actions       = var.alarm_actions
  tags                = var.tags
}

# ----- Per-namespace pod CPU -----
resource "aws_cloudwatch_metric_alarm" "healthcare_pod_cpu" {
  alarm_name          = "${var.cluster_name}-healthcare-pod-cpu"
  alarm_description   = "healthcare namespace pod CPU > 85%"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 85
  evaluation_periods  = 10
  period              = 60
  statistic           = "Average"
  namespace           = local.ns
  metric_name         = "pod_cpu_utilization"
  dimensions = {
    ClusterName = var.cluster_name
    Namespace   = "healthcare"
  }
  alarm_actions = var.alarm_actions
  tags          = var.tags
}