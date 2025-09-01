output "cloud_sql_instance_name" {
  description = "The name of the Cloud SQL for MySQL instance."
  value       = module.debezium-source.cloud_sql_instance_name
}

output "cloud_sql_instance_private_ip" {
  description = "The private IP address of the Cloud SQL instance."
  value       = module.debezium-source.cloud_sql_instance_private_ip
  sensitive   = true
}

output "admin_user_name" {
  description = "The username for the database admin."
  value       = module.debezium-source.admin_user_name
}

output "admin_user_password" {
  description = "The password for the database admin user."
  value       = module.debezium-source.admin_user_password
  sensitive   = true
}

output "datastream_user_name" {
  description = "The username for the Cloud SQL user for Datastream."
  value       = module.debezium-source.datastream_user_name
}

output "datastream_user_password" {
  description = "The password for the Cloud SQL user for Datastream. This is a sensitive value."
  value       = module.debezium-source.datastream_user_password
  sensitive   = true
}

output "cloud_sql_psc_endpoint_name" {
  description = "The name of the PSC Endpoint for Cloud SQL."
  value       = module.debezium-source.cloud_sql_psc_endpoint_name
}

output "cloud_sql_psc_endpoint_ip" {
  description = "The internal IP address of the PSC Endpoint for Cloud SQL. Use this IP for all in-VPC connections."
  value       = module.debezium-source.cloud_sql_psc_endpoint_ip
}

output "gce_client_instance_name" {
  description = "The name of the GCE client instance used for testing."
  value       = module.gce-client.gce_client_instance_name
}

output "gce_client_instance_private_ip" {
  description = "The private IP of the GCE client instance used for testing."
  value       = module.gce-client.gce_client_instance_private_ip
}

output "gce_client_zone" {
  description = "The zone of the GCE client VM."
  value       = module.gce-client.gce_client_zone
}
