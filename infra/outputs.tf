# ============================================================
# Outputs
# ============================================================

output "apig_endpoints" {
  description = "API Gateway endpoints for product and order CRUD APIs"
  value = {
    product_get    = "https://${huaweicloud_apig_instance.main.ingress_address}/${huaweicloud_apig_group.main.name}/product/{resourceId}"
    product_put    = "https://${huaweicloud_apig_instance.main.ingress_address}/${huaweicloud_apig_group.main.name}/product/{resourceId}"
    product_delete = "https://${huaweicloud_apig_instance.main.ingress_address}/${huaweicloud_apig_group.main.name}/product/{resourceId}"
    order_get      = "https://${huaweicloud_apig_instance.main.ingress_address}/${huaweicloud_apig_group.main.name}/order/{resourceId}"
    order_put      = "https://${huaweicloud_apig_instance.main.ingress_address}/${huaweicloud_apig_group.main.name}/order/{resourceId}"
    order_delete   = "https://${huaweicloud_apig_instance.main.ingress_address}/${huaweicloud_apig_group.main.name}/order/{resourceId}"
  }
}

output "apig_base_url" {
  description = "APIG base URL (append group name + path)"
  value       = "https://${huaweicloud_apig_instance.main.ingress_address}"
}

output "apig_group_name" {
  description = "APIG group name"
  value       = huaweicloud_apig_group.main.name
}

output "dds_connection_info" {
  description = "DDS MongoDB connection information"
  value = {
    host        = huaweicloud_dds_instance_v3.main.nodes[0].private_ip
    port        = 8635
    database    = "saas"
    username    = "rwuser"
    ssl         = true
    replica_set = "replica"
  }
  sensitive = true
}

output "dds_connection_string" {
  description = "DDS MongoDB connection string (for client use)"
  value       = "mongodb://rwuser:${urlencode(var.dds_password)}@${huaweicloud_dds_instance_v3.main.nodes[0].private_ip}:8635/saas?authSource=admin&replicaSet=replica&ssl=true"
  sensitive   = true
}

output "obs_buckets" {
  description = "OBS bucket names for logs, metrics, and code"
  value = {
    logs    = huaweicloud_obs_bucket.logs.bucket
    metrics = huaweicloud_obs_bucket.metrics.bucket
    code    = huaweicloud_obs_bucket.code.bucket
  }
}

output "dli_info" {
  description = "DLI queue and database for log/metrics querying"
  value = {
    queue_name    = "default" # Built-in default SQL queue, no dedicated queue provisioned
    database_name = huaweicloud_dli_database.saas.name
    logs_table    = huaweicloud_dli_table.logs.name
    metrics_table = huaweicloud_dli_table.metrics.name
  }
}

output "function_names" {
  description = "FunctionGraph function names"
  value = {
    product_get    = huaweicloud_fgs_function.product_get.name
    product_put    = huaweicloud_fgs_function.product_put.name
    product_delete = huaweicloud_fgs_function.product_delete.name
    order_get      = huaweicloud_fgs_function.order_get.name
    order_put      = huaweicloud_fgs_function.order_put.name
    order_delete   = huaweicloud_fgs_function.order_delete.name
  }
}

output "vpc_info" {
  description = "VPC and subnet information"
  value = {
    vpc_id      = huaweicloud_vpc.main.id
    subnet_id   = huaweicloud_vpc_subnet.main.id
    vpc_cidr    = huaweicloud_vpc.main.cidr
    subnet_cidr = huaweicloud_vpc_subnet.main.cidr
  }
}
