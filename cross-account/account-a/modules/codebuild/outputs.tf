output "project_name" {
  description = "Name of the codebuild project"
  value       = aws_codebuild_project.this.name
}
