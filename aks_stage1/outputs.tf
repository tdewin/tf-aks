output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "owneremail" {
  value = var.owneremail
}

output "storageaccount" {
  value = azurerm_storage_account.sa.name
  
}
output "storageaccount_ak" {
  value = azurerm_storage_account.sa.secondary_access_key 
  sensitive = true
}
output "storagecontainer" {
  value = azurerm_storage_container.sacontainer.name
}

output "azurerm_kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config_pass" {
  value     = azurerm_kubernetes_cluster.aks.kube_config[0]
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

output "ingressip" {
  value = kubernetes_ingress_v1.stock-demo-ingress.status.0.load_balancer.0.ingress.0.ip
}
output "ingresshost" {
  value = kubernetes_ingress_v1.stock-demo-ingress.spec.0.rule.0.host
}

output "etchostsingress" {
  value = format("%s %s",kubernetes_ingress_v1.stock-demo-ingress.status.0.load_balancer.0.ingress.0.ip,kubernetes_ingress_v1.stock-demo-ingress.spec.0.rule.0.host)
}

output "k10url" {
  value = format("https://%s/k10/#",kubernetes_ingress_v1.stock-demo-ingress.spec.0.rule.0.host)
}

output "k10login" {
  value = format("https://%s/k10/?page=Login#/login",kubernetes_ingress_v1.stock-demo-ingress.spec.0.rule.0.host)
}

output "k10token" {
  value = kubernetes_token_request_v1.k10token.token
  sensitive = true
}

output "pubcert" {
  value = local_file.store_cert.filename
}

output "stockurl" {
  value = format("https://%s/stock/init",kubernetes_ingress_v1.stock-demo-ingress.spec.0.rule.0.host)
}