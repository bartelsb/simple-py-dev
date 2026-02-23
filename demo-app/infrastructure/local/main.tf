module "demo-app" {
  source = "../modules/demo-app"

  environment = var.environment
  app_version = var.app_version
  container_image = var.container_image
}