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