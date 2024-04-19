
output "vbrsa" {
  value = kubernetes_service_account.vbr.metadata.0.name
  sensitive = true
}

output "vbrtoken" {
  value = kubernetes_secret.vbrsecret.data.token
  sensitive = true
}
