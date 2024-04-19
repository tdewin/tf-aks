terraform {
  required_version = ">=1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.27"   
    }
  }
}

data "terraform_remote_state" "aksone" {
  backend = "local"

  config = {
    path = "../aks_stage1/terraform.tfstate"
  }
}


provider "kubernetes" {
    host                   = data.terraform_remote_state.aksone.outputs.kube_config_pass.host
    client_certificate     = base64decode(data.terraform_remote_state.aksone.outputs.kube_config_pass.client_certificate)
    client_key             = base64decode(data.terraform_remote_state.aksone.outputs.kube_config_pass.client_key)
    cluster_ca_certificate = base64decode(data.terraform_remote_state.aksone.outputs.kube_config_pass.cluster_ca_certificate)
}
