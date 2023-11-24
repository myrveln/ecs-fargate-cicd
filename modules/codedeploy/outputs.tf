output "app_name" {
  description = "Name of the CodeDeploy App"
  value       = aws_codedeploy_app.this.name
}

output "app_arn" {
  description = "ARN of the CodeDeploy App"
  value       = aws_codedeploy_app.this.arn
}

output "deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.this.deployment_group_name
}

output "deployment_group_arn" {
  description = "ARN of the CodeDeploy deployment group"
  value       = aws_codedeploy_deployment_group.this.arn
}
