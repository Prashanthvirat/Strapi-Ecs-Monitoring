output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "ecr_repo_url" {
  value = aws_ecr_repository.strapi_repo.repository_url
}