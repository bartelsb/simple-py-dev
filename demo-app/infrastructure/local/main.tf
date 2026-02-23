module "demo-app" {
  source = "../modules/demo-app"

  environment = "local"
  app_version = terraform.workspace
  container_image = "demo-app:${terraform.workspace}"
}