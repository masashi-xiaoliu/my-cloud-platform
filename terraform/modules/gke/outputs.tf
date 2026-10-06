output "name" { value = google_container_cluster.this.name }
output "location" { value = google_container_cluster.this.location }
output "endpoint" {
  value     = google_container_cluster.this.endpoint
  sensitive = true
}
output "ca_certificate" {
  value     = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive = true
}
output "get_credentials_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.this.name} --location ${google_container_cluster.this.location} --project ${var.project_id}"
}
