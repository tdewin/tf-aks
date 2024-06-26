resource "kubernetes_manifest" "azk10storagekey" {
    manifest = {
        apiVersion = "v1"
        kind       = "Secret"
        metadata = {
            name = "k10secret-${data.terraform_remote_state.aksone.outputs.storageaccount}"
            namespace = "kasten-io"
        }
        type =  "secrets.kanister.io/azure"
        data = {
            azure_storage_account_id = base64encode(data.terraform_remote_state.aksone.outputs.storageaccount)
            azure_storage_environment = base64encode("AzurePublicCloud")
            azure_storage_key = base64encode(data.terraform_remote_state.aksone.outputs.storageaccount_ak)
        }
    }
}

resource "kubernetes_manifest" "azk10storage" {
  depends_on = [
        kubernetes_manifest.azk10storagekey
  ]
  manifest = {
    apiVersion = "config.kio.kasten.io/v1alpha1"
    kind       = "Profile"

    metadata = {
      name = data.terraform_remote_state.aksone.outputs.storageaccount
      namespace = "kasten-io"
    }
    spec = {
        type = "Location"
        locationSpec = {
            type= "ObjectStore"
            credential = {
                secret = {
                    apiVersion = "v1"
                    kind = "secret"
                    namespace = "kasten-io"
                    name = "k10secret-${data.terraform_remote_state.aksone.outputs.storageaccount}"
                }
                secretType = "AzStorageAccount"
            }
            objectStore = {
                name = "k10"
                objectStoreType = "AZ"
                pathType: "Directory"
            }
        }
    }
  }
}



resource "kubernetes_manifest" "azk10goldsla" {
  depends_on = [
    kubernetes_manifest.azk10storage
  ]
  manifest = {
    apiVersion = "config.kio.kasten.io/v1alpha1"
    kind       = "PolicyPreset"

    metadata = {
      name = "golden-sla"
      namespace = "kasten-io"
    }
    spec = {
        comment = "Golden SLA with backup and export"
        backup = {
            frequency = "@daily"
            retention = {
                daily = 3
                weekly = 0
                monthly = 0
                yearly = 0
            }
            profile = {
                namespace = "kasten-io"
                name = data.terraform_remote_state.aksone.outputs.storageaccount
            }
        }
        export = {
            exportData = {
                enabled = "true"
            }
            profile = {
                namespace = "kasten-io"
                name = data.terraform_remote_state.aksone.outputs.storageaccount
            }
        }
    }
  }
}


resource "kubernetes_manifest" "bppostgres" {
  manifest = {
    apiVersion = "cr.kanister.io/v1alpha1"
    kind       = "Blueprint"

    metadata = {
      name = "postgresql-hooks"
      namespace = "kasten-io"
    }

    actions = {
       backupPrehook = {
            name = ""
            kind = ""
            phases = [
                {
                    func = "KubeExec"
                    name = "makePGCheckPoint"
                    args = {
                        command = [
                            "bash","-o","errexit","-o","pipefail","-c","PGPASSWORD=$${POSTGRES_POSTGRES_PASSWORD} psql -d $${POSTGRES_DATABASE} -U postgres -c \"CHECKPOINT;\""
                        ]
                        container = "postgresql"
                        namespace = "{{ .StatefulSet.Namespace }}"
                        pod= "{{ index .StatefulSet.Pods 0 }}"
                    }
                }
            ]
       } 
    }
  }
}

resource "kubernetes_manifest" "bpbinding" {
  depends_on = [
    kubernetes_manifest.bppostgres
  ]

  manifest = {
    apiVersion = "config.kio.kasten.io/v1alpha1"
    kind       = "BlueprintBinding"

    metadata = {
      name = "postgres-blueprint-binding"
      namespace = "kasten-io"
    }

    spec = {
        blueprintRef = {
            name = "postgresql-hooks"
            namespace = "kasten-io"
        }
        resources = {
            matchAll = [
                {
                    type = {
                        operator = "In"
                        values = [
                            {
                                group = "apps"
                                resource = "statefulsets"
                            }
                        ]
                    }
                },
                {
                    annotations = {
                        key = "kanister.kasten.io/blueprint"
                        operator = "DoesNotExist"
                    }
                },
                {
                    "labels"= {
                        key= "app.kubernetes.io/name"
                        operator= "In"
                        values= ["postgresql"]
                    }
                }
            ]
        }
    }
  }
}

resource "kubernetes_config_map_v1" "k10-eula-info" {
  metadata {
    name = "k10-eula-info"
    namespace = "kasten-io"
  }

  data = {
    accepted="true"
    company=split("@",data.terraform_remote_state.aksone.outputs.owneremail)[1]
    email=data.terraform_remote_state.aksone.outputs.owneremail
  }
}


resource "kubernetes_service_account" "vbr" {
  metadata {
    name = "vbr"
    namespace = "kasten-io"
  }

  automount_service_account_token = true
}

resource "kubernetes_secret" "vbrsecret" {
  metadata {
    namespace = "kasten-io"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.vbr.metadata.0.name
    }
    generate_name = "vbr-sa-"
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "kubernetes_cluster_role_binding" "vbrcrb" {
  metadata {
    name = "vbr-crb-k10admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "k10-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "vbr"
    namespace = "kasten-io"
  }
}

resource "kubernetes_role_binding" "vbrrbns" {
  metadata {
    name = "vbr-rb-ns-k10admin"
    namespace = "kasten-io"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "k10-ns-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "vbr"
    namespace = "kasten-io"
  }
}
