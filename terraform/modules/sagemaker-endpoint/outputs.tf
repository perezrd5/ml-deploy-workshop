output "endpoint_name" {
  description = "Used by the audit-trail script and by attendees for invoke-endpoint."
  value       = aws_sagemaker_endpoint.this.name
}

output "endpoint_arn" {
  description = "Full ARN — written into the audit event so the five-minute traceability query can join to it."
  value       = aws_sagemaker_endpoint.this.arn
}

output "execution_role_arn" {
  description = "Exposed so the deploy-role's iam:PassRole permission can be scoped to this exact ARN in stricter setups."
  value       = aws_iam_role.execution.arn
}

output "endpoint_5xx_alarm_arn" {
  description = "The CloudWatch alarm that auto_rollback references — surfaced for cross-stack visibility."
  value       = aws_cloudwatch_metric_alarm.endpoint_5xx.arn
}

output "security_group_id" {
  description = "Endpoint ENI security group — exposed for VPC endpoint configurations or peering."
  value       = aws_security_group.endpoint.id
}
