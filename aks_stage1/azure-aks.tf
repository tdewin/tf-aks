# change variables in variables.tf !!!

resource "tls_private_key" "private_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "local_file" "store_pem" { 
  depends_on = [tls_private_key.private_key]
  filename = "${path.module}/private_key.pem"
  content = tls_private_key.private_key.private_key_pem
}

resource "tls_self_signed_cert" "cert" {
  depends_on = [local_file.store_pem]
  private_key_pem = tls_private_key.private_key.private_key_pem

  subject {
    common_name  = var.certificatehost
    organization = var.certificateorg
  }

  dns_names = [
    var.certificatehost
  ]

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "data_encipherment" 
  ]

  validity_period_hours = 24*3650
}


resource "local_file" "store_cert" { 
  depends_on = [tls_self_signed_cert.cert]
  filename = "${path.module}/publickey.crt"
  content = tls_self_signed_cert.cert.cert_pem
}





resource "azurerm_resource_group" "rg" {
  location = var.azlocation
  name     = "${local.projectname}-rg"
  tags	   = local.tags
}

resource "random_string" "randomsa" {
  length           = 6
  special          = false
  upper            = false
  numeric          = true
  lower            = true
}

resource "azurerm_storage_account" "sa" {
  name                     = format("%s%s",var.ownerref,random_string.randomsa.result)
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  shared_access_key_enabled  = true
  allow_nested_items_to_be_public = false
  tags	   = local.tags
}

resource "azurerm_storage_container" "sacontainer" {
  name                  = "k10"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${local.projectname}-aks"

  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  web_app_routing {
    dns_zone_id = ""
  }

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = var.aksvmsize
    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags

  linux_profile {
    admin_username = var.ownerref

    ssh_key {
      key_data = "${file("${var.ssh_public_key}")}"
    }
  }

  dns_prefix = local.projectname

  api_server_access_profile {
    authorized_ip_ranges = local.allowipsarr
  }
}


resource "helm_release" "azvolumesnaphelmchart" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  name = "azvolumesnap"
  namespace = "azvolumesnap"
  create_namespace = true

  repository = "https://tdewin.github.io/azvolumesnaphelmchart/"
  chart      = "azvolumesnap"  
}

resource "kubernetes_namespace" "kastenio" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  metadata {
    name = "kasten-io"
    
    labels = {
      prodlevel = "backupinfra"
    }
  }
}

resource "kubernetes_secret" "tlscert" {
  depends_on = [kubernetes_namespace.kastenio,tls_private_key.private_key,tls_self_signed_cert.cert]

  metadata {
    name = "k10tlscert"
    namespace = kubernetes_namespace.kastenio.metadata.0.name
  }

  data = {
    "tls.crt" =  tls_self_signed_cert.cert.cert_pem  
    "tls.key" =  tls_private_key.private_key.private_key_pem
  }

  type = "kubernetes.io/tls"
}


resource "helm_release" "k10" {
  depends_on = [kubernetes_secret.tlscert]

  name = "k10"
  namespace = kubernetes_namespace.kastenio.metadata.0.name


  repository = "https://charts.kasten.io/"
  chart      = "k10"
  
  set {
    name  = "ingress.create"
    value = true
  }

  set {
    name  = "ingress.class"
    value = "webapprouting.kubernetes.azure.com"
  }

  set {
    name = "ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/whitelist-source-range"
    value = var.allowips
  }

  set {
    name = "ingress.host"
    value = var.certificatehost
  }

  set {
    name = "ingress.tls.enabled"
    value = true
  }

  set {
    name = "ingress.tls.secretName"
    value = "k10tlscert"
  }

  set {
    name  = "auth.tokenAuth.enabled"
    value = true
  }

  set {
    name  = "azure.useDefaultMSI"
    value = true
  }  
}

resource "kubernetes_token_request_v1" "k10token" {
  depends_on = [helm_release.k10]

  metadata {
    name = "k10-k10"
    namespace = kubernetes_namespace.kastenio.metadata.0.name
  }
  spec {
    expiration_seconds = var.tokenexpirehours*3600
  }
}


resource "kubernetes_namespace" "stock" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  metadata {
    name = "stock"
    
    labels = {
      prodlevel = "gold"
    }
  }
}


resource "kubernetes_secret" "tlscertstock" {
  depends_on = [kubernetes_namespace.stock,tls_private_key.private_key,tls_self_signed_cert.cert]

  metadata {
    name = "k10tlscert"
    namespace = "stock"
  }

  data = {
    "tls.crt" =  tls_self_signed_cert.cert.cert_pem  
    "tls.key" =  tls_private_key.private_key.private_key_pem
  }

  type = "kubernetes.io/tls"
}


resource "kubernetes_namespace" "hr" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  metadata {
    name = "hr"
    
    labels = {
      prodlevel = "gold"
    }
  }
}

resource "helm_release" "stockgres" {
  depends_on = [kubernetes_namespace.stock]

  name = "stockdb"
  namespace = kubernetes_namespace.stock.metadata[0].name
  create_namespace = false

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  
  set {
    name  = "global.postgresql.auth.username"
    value = "root"
  }

  set {
    name  = "global.postgresql.auth.password"
    value = "notsecure"
  }

  set {
    name  = "global.postgresql.auth.database"
    value = "stock"
  }
}

resource "kubernetes_config_map" "stockcm" {
  depends_on = [kubernetes_namespace.stock]

  metadata {
    name = "stock-demo-configmap"
    namespace = kubernetes_namespace.stock.metadata[0].name
  }

  data = {
    "initinsert.psql" = "${file("${path.module}/initinsert.psql")}"
  }
}

resource "kubernetes_deployment" "stock-deploy" {
  depends_on = [kubernetes_namespace.stock]

  metadata {
    name = "stock-demo-deploy"
    namespace = kubernetes_namespace.stock.metadata[0].name
    labels = {
      app = "stock-demo"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "stock-demo"
      }
    }

    template {
      metadata {
        labels = {
          app = "stock-demo"
        }
      }

      spec {
        volume {
          name = "config"
          config_map {
            name = "stock-demo-configmap"
          }
        }
        container {
          image = "tdewin/stock-demo"
          name  = "stock-demo"
          port {
            name = "stock-demo"
            container_port = "8080"
            protocol = "TCP"
          }
          volume_mount {
            name = "config"
            mount_path = "/var/stockdb"
            read_only = true
          }
          env {
              name = "POSTGRES_DB"
              value = "stock"
          }

          env {
              name = "POSTGRES_SERVER"
              value = "stockdb-postgresql"
          }

          env {
              name = "POSTGRES_USER"
              value = "root"
          }
          env {
              name = "POSTGRES_PORT"
              value = "5432"
          }
          env {
              name = "ADMINKEY"
              value = "unlock"
          }
          env {
              name = "POSTGRES_PASSWORD"
              value_from {
                secret_key_ref {
                  key = "password"
                  name = "stockdb-postgresql"
                }
              }
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "stock-demo-svc" {
  depends_on = [kubernetes_namespace.stock]

  metadata {
    name = "stock-demo-svc"
    namespace = kubernetes_namespace.stock.metadata[0].name
    labels = {
      app = "stock-demo"
    }
  }
  spec {
    selector = {
      app = "stock-demo"
    }
    
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "stock-demo-ingress" {
  depends_on = [kubernetes_secret.tlscertstock]

  wait_for_load_balancer = true

  metadata {
    name = "stock-demo-ingress"
    namespace = kubernetes_namespace.stock.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/use-regex" =  true
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
      "nginx.ingress.kubernetes.io/whitelist-source-range" = var.allowips
    }
  }

  spec {
    ingress_class_name = "webapprouting.kubernetes.azure.com"
    tls {
      hosts = [var.certificatehost ]
      secret_name = "k10tlscert"
    }
    rule {
      host = var.certificatehost
      http {
        path {
          backend {
            service {
              name = "stock-demo-svc"
              port {
                number = 80
              }
            }
          }
          path = "/stock(/|$)(.*)"
          path_type = "ImplementationSpecific"
        }
      }
    }
  }
}


