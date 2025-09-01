# Enable required APIs for the network resources
resource "google_project_service" "project_services" {
  for_each = toset([
    "compute.googleapis.com",
    "servicenetworking.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}
