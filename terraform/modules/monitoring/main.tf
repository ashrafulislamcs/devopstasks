resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}-${var.environment}/cluster"
  retention_in_days = 30

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/${var.cluster_name}-${var.environment}"
  retention_in_days = 14

  tags = { Environment = var.environment }
}

# Alarm: notify if worker node CPU is sustained high (would be wired to an SNS
# topic -> email/Slack in a full setup)
resource "aws_sns_topic" "alerts" {
  name = "${var.cluster_name}-${var.environment}-alerts"
}

resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${var.cluster_name}-${var.environment}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 3
  metric_name          = "CPUUtilization"
  namespace            = "AWS/EC2"
  period               = 300
  statistic            = "Average"
  threshold            = 80
  alarm_actions        = [aws_sns_topic.alerts.arn]
}
