output "alarm_arns" {
  value = [
    aws_cloudwatch_metric_alarm.failed_nodes.arn,
    aws_cloudwatch_metric_alarm.node_cpu_high.arn,
    aws_cloudwatch_metric_alarm.node_memory_high.arn,
    aws_cloudwatch_metric_alarm.node_disk_high.arn,
    aws_cloudwatch_metric_alarm.pod_restarting.arn,
    aws_cloudwatch_metric_alarm.healthcare_pod_cpu.arn,
  ]
}