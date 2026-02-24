locals {
    default_name = "demo-app"
    default_name_with_version = "demo-app-${var.app_version}"
}

resource "kubernetes_namespace_v1" "app_namespace" {
  metadata {
    name = local.default_name_with_version
  }
}

resource "kubernetes_deployment_v1" "demo_app" {
  metadata {
    name      = local.default_name_with_version
    namespace = kubernetes_namespace_v1.app_namespace.metadata[0].name
    labels = {
      app         = local.default_name
      environment = var.environment
    }
    annotations = {
      owner = "terraform"
    }
  }
  
  lifecycle {
    create_before_destroy = true
  }

  spec {
    replicas = var.replica_count

    selector {
      match_labels = {
        app = local.default_name
      }
    }

    template {
      metadata {
        labels = {
          app         = local.default_name
          environment = var.environment
        }
        annotations = {
          owner = "terraform"
        }
      }

      spec {
        container {
          image = var.container_image
          name  = local.default_name
          
          port {
            container_port = var.container_port
          }

          resources {
            limits = {
              cpu    = var.resource_limits_cpu
              memory = var.resource_limits_memory
            }
            requests = {
              cpu    = var.resource_requests_cpu
              memory = var.resource_requests_memory
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 5000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 5000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          security_context {
            read_only_root_filesystem = true
          }  
        }
      }
    }
  }
}
