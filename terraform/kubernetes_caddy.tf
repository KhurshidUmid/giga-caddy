resource "kubernetes_config_map" "caddy_config" {
  metadata {
    name      = "caddy-config"
    namespace = "default"
  }

  data = {
    Caddyfile = <<EOT
:80 {
    respond "Welcome to giga-caddy!"
}
EOT
  }
}

resource "kubernetes_deployment" "caddy" {
  metadata {
    name      = "caddy-deployment"
    namespace = "default"
    labels = {
      app = "caddy"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "caddy"
      }
    }

    template {
      metadata {
        labels = {
          app = "caddy"
        }
      }

      spec {
        container {
          name  = "caddy"
          image = "docker.io/khurshidumid/giga-caddy:latest"
          ports {
            container_port = 80
          }

          volume_mount {
            name       = "caddy-config"
            mount_path = "/etc/caddy"
          }
        }

        volume {
          name = "caddy-config"
          config_map {
            name = kubernetes_config_map.caddy_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "caddy" {
  metadata {
    name      = "caddy-service"
    namespace = "default"
  }

  spec {
    selector = {
      app = "caddy"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}
