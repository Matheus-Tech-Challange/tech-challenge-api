data "aws_db_instance" "database" {
  db_instance_identifier = var.rds_cluster_name
}

locals {
  connection_string = "Server=${trimsuffix(data.aws_db_instance.database.endpoint, ":${data.aws_db_instance.database.port}")};Port=${data.aws_db_instance.database.port};Database=${data.aws_db_instance.database.db_name};Uid=${var.db_user};Pwd=${var.db_password};"
}

resource "kubernetes_secret" "api-secret" {
  metadata {
    name = "api-secret"
  }

  data = {
    "ConnectionStrings__Mysql" = local.connection_string
  }
}

resource "kubernetes_deployment" "api_deployment" {
  depends_on = [ kubernetes_secret.api-secret ]
  metadata {
    name = "api-deployment-tf"
    labels = {
      nome = "api"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        nome = "api"
      }
    }

    template {
      metadata {
        labels = {
          nome = "api"
        }
      }

      spec {
        container {
          name  = "api"
          image = var.ecr_repository_name

          port {
            container_port = 80
          }

          env_from {
            secret_ref {
              name = "api-secret"
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "120Mi"
            }
            limits = {
              cpu    = "150m"
              memory = "200Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "api_hpa" {
  metadata {
    name = "api-hpa"
  }

  spec {
    scale_target_ref {
      kind        = "Deployment"
      name        = "api-deployment"
      api_version = "apps/v1"
    }

    min_replicas = 1
    max_replicas = 2

    metric {
      type = "ContainerResource"
      container_resource {
        container = "api"
        name      = "cpu"
        target {
          average_utilization = 65
          type = "Utilization"
        }
      }
    }
  }
}

resource "kubernetes_service" "svc_api_loadbalancer" {
  metadata {
    name = "svc-api-loadbalancer"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-internal": "true"
      "service.beta.kubernetes.io/aws-load-balancer-type": "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type": "ip"
    }
  }

  spec {
    port {
      port        = 80
      target_port = 80
      node_port   = 30007
    }

    selector = {
      app = "api"
    }

    type = "LoadBalancer"
    load_balancer_source_ranges = ["0.0.0.0/0"]
  }
}