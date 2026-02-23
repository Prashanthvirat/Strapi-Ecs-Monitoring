resource "aws_ecr_repository" "strapi_repo" {
  name = "strapi-repo"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true
}