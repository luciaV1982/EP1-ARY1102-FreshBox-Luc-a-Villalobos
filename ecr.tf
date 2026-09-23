# =====================================================
# FreshBox SpA - Amazon ECR
# Repositorios para las 5 imagenes Docker
# =====================================================

resource "aws_ecr_repository" "frontend" {
  name                 = "freshbox-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "get_products" {
  name                 = "freshbox-get-products"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "create_product" {
  name                 = "freshbox-create-product"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "update_product" {
  name                 = "freshbox-update-product"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "delete_product" {
  name                 = "freshbox-delete-product"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# =====================================================
# Build y Push automatico de imagenes Docker a ECR
# =====================================================

resource "terraform_data" "ecr_images" {

  triggers_replace = [
    aws_ecr_repository.frontend.repository_url,
    aws_ecr_repository.get_products.repository_url,
    aws_ecr_repository.create_product.repository_url,
    aws_ecr_repository.update_product.repository_url,
    aws_ecr_repository.delete_product.repository_url
  ]

  provisioner "local-exec" {
    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]
    command     = "bash ./app/scripts/ecr-push.sh"
  }

  depends_on = [
    aws_ecr_repository.frontend,
    aws_ecr_repository.get_products,
    aws_ecr_repository.create_product,
    aws_ecr_repository.update_product,
    aws_ecr_repository.delete_product
  ]
}
