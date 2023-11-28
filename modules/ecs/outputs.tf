output "alb_listener_arn" {
  value = aws_lb_listener.this.arn
}

output "blue_target_group_name" {
  value = aws_lb_target_group.blue.name
}

output "green_target_group_name" {
  value = aws_lb_target_group.green.name
}

output "ecs_service_name" {
  value = aws_ecs_service.this.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}

output "ecr_repository_arn" {
  value = aws_ecr_repository.this.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}
