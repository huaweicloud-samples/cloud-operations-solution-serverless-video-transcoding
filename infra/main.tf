# ============================================================
# Main infrastructure: VPC, DDS, OBS, FunctionGraph, APIG, DLI
# ============================================================

# Random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  suffix         = lower(random_id.suffix.hex)
  logs_bucket    = "${var.name_prefix}-logs-${local.suffix}"
  metrics_bucket = "${var.name_prefix}-metrics-${local.suffix}"
  code_bucket    = "${var.name_prefix}-code-${local.suffix}"
  dds_db_name    = "saas"
}

# ============================================================
# Network: VPC, Subnet, Security Group
# ============================================================

resource "huaweicloud_vpc" "main" {
  name = "${var.name_prefix}-vpc"
  cidr = var.vpc_cidr
}

resource "huaweicloud_vpc_subnet" "main" {
  name       = "${var.name_prefix}-subnet"
  vpc_id     = huaweicloud_vpc.main.id
  cidr       = var.subnet_cidr
  gateway_ip = cidrhost(var.subnet_cidr, 1)
}

resource "huaweicloud_networking_secgroup" "main" {
  name        = "${var.name_prefix}-sg"
  description = "Security group for DDS and APIG"
}

resource "huaweicloud_networking_secgroup_rule" "dds_mongo" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8635
  port_range_max    = 8635
  remote_ip_prefix  = var.subnet_cidr
  security_group_id = huaweicloud_networking_secgroup.main.id
}

resource "huaweicloud_networking_secgroup_rule" "apig_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.main.id
}

resource "huaweicloud_networking_secgroup_rule" "egress" {
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.main.id
}

# ============================================================
# DDS MongoDB Instance
# ============================================================

resource "huaweicloud_dds_instance_v3" "main" {
  name              = "${var.name_prefix}-dds"
  availability_zone = var.availability_zone
  vpc_id            = huaweicloud_vpc.main.id
  subnet_id         = huaweicloud_vpc_subnet.main.id
  security_group_id = huaweicloud_networking_secgroup.main.id
  mode              = "ReplicaSet"
  password          = var.dds_password
  ssl               = true

  datastore {
    type           = "DDS-Community"
    version        = "4.0"
    storage_engine = "wiredTiger"
  }

  flavor {
    type      = "replica"
    num       = 1
    spec_code = var.dds_flavor
    size      = var.dds_storage
    storage   = "ULTRAHIGH"
  }

  backup_strategy {
    start_time = "03:00-04:00"
    keep_days  = 3
  }
}

# ============================================================
# OBS Buckets: logs, metrics, function code
# ============================================================

resource "huaweicloud_obs_bucket" "logs" {
  bucket = local.logs_bucket
  acl    = "private"
}

resource "huaweicloud_obs_bucket" "metrics" {
  bucket = local.metrics_bucket
  acl    = "private"
}

resource "huaweicloud_obs_bucket" "code" {
  bucket = local.code_bucket
  acl    = "private"
}

# ============================================================
# Build function packages locally
# ============================================================

resource "null_resource" "build_packages" {
  triggers = {
    build_hash = filesha256("${path.module}/../src/layers/helper.js")
  }

  provisioner "local-exec" {
    command = "cd ${path.module}/../src && bash build.sh"
  }
}

# Upload function packages to OBS
resource "huaweicloud_obs_bucket_object" "product_manager_zip" {
  depends_on = [null_resource.build_packages]
  bucket     = huaweicloud_obs_bucket.code.bucket
  key        = "product-manager.zip"
  source     = "${path.module}/../src/dist/product-manager.zip"
}

resource "huaweicloud_obs_bucket_object" "order_manager_zip" {
  depends_on = [null_resource.build_packages]
  bucket     = huaweicloud_obs_bucket.code.bucket
  key        = "order-manager.zip"
  source     = "${path.module}/../src/dist/order-manager.zip"
}

# IAM Agency for FunctionGraph to access VPC and OBS
resource "huaweicloud_iam_agency" "fgs_access" {
  name                   = "fgs_vpc_obs_access"
  description            = "Agency for FunctionGraph to access VPC and OBS"
  duration               = "FOREVER"
  delegated_service_name = "op_svc_fgs"
  all_resources_roles    = ["VPC Administrator", "OBS Administrator"]
}

# ============================================================
# FunctionGraph Functions (6 functions)
# ============================================================

# Common environment variables for all functions
locals {
  function_envs = {
    LogsBucketName        = local.logs_bucket
    MetricsBucketName     = local.metrics_bucket
    DDS_CONNECTION_STRING = "mongodb://rwuser:${urlencode(var.dds_password)}@${huaweicloud_dds_instance_v3.main.nodes[0].private_ip}:8635/${local.dds_db_name}?authSource=admin&replicaSet=replica&ssl=true"
    OBS_ENDPOINT          = "obs.${var.region}.myhuaweicloud.com"
  }
}

# Product Manager Functions
resource "huaweicloud_fgs_function" "product_get" {
  depends_on = [huaweicloud_obs_bucket_object.product_manager_zip]

  name        = "${var.name_prefix}-product-get"
  app         = "default"
  handler     = "product-manager.get"
  memory_size = var.function_memory
  runtime     = var.function_runtime
  timeout     = var.function_timeout
  code_type   = "obs"
  code_url    = "https://${huaweicloud_obs_bucket.code.bucket_domain_name}/${huaweicloud_obs_bucket_object.product_manager_zip.key}"

  vpc_id     = huaweicloud_vpc.main.id
  network_id = huaweicloud_vpc_subnet.main.id

  agency = huaweicloud_iam_agency.fgs_access.name


  user_data = jsonencode(local.function_envs)
}

resource "huaweicloud_fgs_function" "product_put" {
  depends_on = [huaweicloud_obs_bucket_object.product_manager_zip]

  name        = "${var.name_prefix}-product-put"
  app         = "default"
  handler     = "product-manager.put"
  memory_size = var.function_memory
  runtime     = var.function_runtime
  timeout     = var.function_timeout
  code_type   = "obs"
  code_url    = "https://${huaweicloud_obs_bucket.code.bucket_domain_name}/${huaweicloud_obs_bucket_object.product_manager_zip.key}"

  vpc_id     = huaweicloud_vpc.main.id
  network_id = huaweicloud_vpc_subnet.main.id

  agency = huaweicloud_iam_agency.fgs_access.name


  user_data = jsonencode(local.function_envs)
}

resource "huaweicloud_fgs_function" "product_delete" {
  depends_on = [huaweicloud_obs_bucket_object.product_manager_zip]

  name        = "${var.name_prefix}-product-delete"
  app         = "default"
  handler     = "product-manager.delete"
  memory_size = var.function_memory
  runtime     = var.function_runtime
  timeout     = var.function_timeout
  code_type   = "obs"
  code_url    = "https://${huaweicloud_obs_bucket.code.bucket_domain_name}/${huaweicloud_obs_bucket_object.product_manager_zip.key}"

  vpc_id     = huaweicloud_vpc.main.id
  network_id = huaweicloud_vpc_subnet.main.id

  agency = huaweicloud_iam_agency.fgs_access.name


  user_data = jsonencode(local.function_envs)
}

# Order Manager Functions
resource "huaweicloud_fgs_function" "order_get" {
  depends_on = [huaweicloud_obs_bucket_object.order_manager_zip]

  name        = "${var.name_prefix}-order-get"
  app         = "default"
  handler     = "order-manager.get"
  memory_size = var.function_memory
  runtime     = var.function_runtime
  timeout     = var.function_timeout
  code_type   = "obs"
  code_url    = "https://${huaweicloud_obs_bucket.code.bucket_domain_name}/${huaweicloud_obs_bucket_object.order_manager_zip.key}"

  vpc_id     = huaweicloud_vpc.main.id
  network_id = huaweicloud_vpc_subnet.main.id

  agency = huaweicloud_iam_agency.fgs_access.name


  user_data = jsonencode(local.function_envs)
}

resource "huaweicloud_fgs_function" "order_put" {
  depends_on = [huaweicloud_obs_bucket_object.order_manager_zip]

  name        = "${var.name_prefix}-order-put"
  app         = "default"
  handler     = "order-manager.put"
  memory_size = var.function_memory
  runtime     = var.function_runtime
  timeout     = var.function_timeout
  code_type   = "obs"
  code_url    = "https://${huaweicloud_obs_bucket.code.bucket_domain_name}/${huaweicloud_obs_bucket_object.order_manager_zip.key}"

  vpc_id     = huaweicloud_vpc.main.id
  network_id = huaweicloud_vpc_subnet.main.id

  agency = huaweicloud_iam_agency.fgs_access.name


  user_data = jsonencode(local.function_envs)
}

resource "huaweicloud_fgs_function" "order_delete" {
  depends_on = [huaweicloud_obs_bucket_object.order_manager_zip]

  name        = "${var.name_prefix}-order-delete"
  app         = "default"
  handler     = "order-manager.delete"
  memory_size = var.function_memory
  runtime     = var.function_runtime
  timeout     = var.function_timeout
  code_type   = "obs"
  code_url    = "https://${huaweicloud_obs_bucket.code.bucket_domain_name}/${huaweicloud_obs_bucket_object.order_manager_zip.key}"

  vpc_id     = huaweicloud_vpc.main.id
  network_id = huaweicloud_vpc_subnet.main.id

  agency = huaweicloud_iam_agency.fgs_access.name


  user_data = jsonencode(local.function_envs)
}

# ============================================================
# APIG Instance, Group, APIs, Environment
# ============================================================

resource "huaweicloud_apig_instance" "main" {
  name               = "${var.name_prefix}-apig"
  edition            = "BASIC"
  availability_zones = ["cn-north-4a", "cn-north-4b"]
  vpc_id             = huaweicloud_vpc.main.id
  subnet_id          = huaweicloud_vpc_subnet.main.id
  security_group_id  = huaweicloud_networking_secgroup.main.id
}

resource "huaweicloud_apig_group" "main" {
  instance_id = huaweicloud_apig_instance.main.id
  name        = "${var.name_prefix}-api-group"
  description = "API group for multi-tenant SaaS CRUD APIs"
}

resource "huaweicloud_apig_environment" "prod" {
  instance_id = huaweicloud_apig_instance.main.id
  name        = "production"
  description = "Production environment"
}

# API definitions: Product endpoints
resource "huaweicloud_apig_api" "product_get" {
  instance_id      = huaweicloud_apig_instance.main.id
  group_id         = huaweicloud_apig_group.main.id
  name             = "ProductGet"
  type             = "FunctionGraph"
  request_method   = "GET"
  request_path     = "/product/{resourceId}"
  request_protocol = "HTTPS"
  matching         = "Exact"
  description      = "Get a product by ID"

  func_graph {
    function_urn    = huaweicloud_fgs_function.product_get.urn
    invocation_type = "sync"
    timeout         = var.function_timeout
  }

  request_params {
    name     = "resourceId"
    type     = "STRING"
    location = "PATH"
    required = true
  }
}

resource "huaweicloud_apig_api" "product_put" {
  instance_id      = huaweicloud_apig_instance.main.id
  group_id         = huaweicloud_apig_group.main.id
  name             = "ProductPut"
  type             = "FunctionGraph"
  request_method   = "PUT"
  request_path     = "/product/{resourceId}"
  request_protocol = "HTTPS"
  matching         = "Exact"
  description      = "Add or update a product"

  func_graph {
    function_urn    = huaweicloud_fgs_function.product_put.urn
    invocation_type = "sync"
    timeout         = var.function_timeout
  }

  request_params {
    name     = "resourceId"
    type     = "STRING"
    location = "PATH"
    required = true
  }
}

resource "huaweicloud_apig_api" "product_delete" {
  instance_id      = huaweicloud_apig_instance.main.id
  group_id         = huaweicloud_apig_group.main.id
  name             = "ProductDelete"
  type             = "FunctionGraph"
  request_method   = "DELETE"
  request_path     = "/product/{resourceId}"
  request_protocol = "HTTPS"
  matching         = "Exact"
  description      = "Delete a product by ID"

  func_graph {
    function_urn    = huaweicloud_fgs_function.product_delete.urn
    invocation_type = "sync"
    timeout         = var.function_timeout
  }

  request_params {
    name     = "resourceId"
    type     = "STRING"
    location = "PATH"
    required = true
  }
}

# API definitions: Order endpoints
resource "huaweicloud_apig_api" "order_get" {
  instance_id      = huaweicloud_apig_instance.main.id
  group_id         = huaweicloud_apig_group.main.id
  name             = "OrderGet"
  type             = "FunctionGraph"
  request_method   = "GET"
  request_path     = "/order/{resourceId}"
  request_protocol = "HTTPS"
  matching         = "Exact"
  description      = "Get an order by ID"

  func_graph {
    function_urn    = huaweicloud_fgs_function.order_get.urn
    invocation_type = "sync"
    timeout         = var.function_timeout
  }

  request_params {
    name     = "resourceId"
    type     = "STRING"
    location = "PATH"
    required = true
  }
}

resource "huaweicloud_apig_api" "order_put" {
  instance_id      = huaweicloud_apig_instance.main.id
  group_id         = huaweicloud_apig_group.main.id
  name             = "OrderPut"
  type             = "FunctionGraph"
  request_method   = "PUT"
  request_path     = "/order/{resourceId}"
  request_protocol = "HTTPS"
  matching         = "Exact"
  description      = "Add or update an order"

  func_graph {
    function_urn    = huaweicloud_fgs_function.order_put.urn
    invocation_type = "sync"
    timeout         = var.function_timeout
  }

  request_params {
    name     = "resourceId"
    type     = "STRING"
    location = "PATH"
    required = true
  }
}

resource "huaweicloud_apig_api" "order_delete" {
  instance_id      = huaweicloud_apig_instance.main.id
  group_id         = huaweicloud_apig_group.main.id
  name             = "OrderDelete"
  type             = "FunctionGraph"
  request_method   = "DELETE"
  request_path     = "/order/{resourceId}"
  request_protocol = "HTTPS"
  matching         = "Exact"
  description      = "Delete an order by ID"

  func_graph {
    function_urn    = huaweicloud_fgs_function.order_delete.urn
    invocation_type = "sync"
    timeout         = var.function_timeout
  }

  request_params {
    name     = "resourceId"
    type     = "STRING"
    location = "PATH"
    required = true
  }
}

# Publish all APIs to the production environment
resource "huaweicloud_apig_api_publishment" "product_get" {
  instance_id = huaweicloud_apig_instance.main.id
  api_id      = huaweicloud_apig_api.product_get.id
  env_id      = huaweicloud_apig_environment.prod.id
}

resource "huaweicloud_apig_api_publishment" "product_put" {
  instance_id = huaweicloud_apig_instance.main.id
  api_id      = huaweicloud_apig_api.product_put.id
  env_id      = huaweicloud_apig_environment.prod.id
}

resource "huaweicloud_apig_api_publishment" "product_delete" {
  instance_id = huaweicloud_apig_instance.main.id
  api_id      = huaweicloud_apig_api.product_delete.id
  env_id      = huaweicloud_apig_environment.prod.id
}

resource "huaweicloud_apig_api_publishment" "order_get" {
  instance_id = huaweicloud_apig_instance.main.id
  api_id      = huaweicloud_apig_api.order_get.id
  env_id      = huaweicloud_apig_environment.prod.id
}

resource "huaweicloud_apig_api_publishment" "order_put" {
  instance_id = huaweicloud_apig_instance.main.id
  api_id      = huaweicloud_apig_api.order_put.id
  env_id      = huaweicloud_apig_environment.prod.id
}

resource "huaweicloud_apig_api_publishment" "order_delete" {
  instance_id = huaweicloud_apig_instance.main.id
  api_id      = huaweicloud_apig_api.order_delete.id
  env_id      = huaweicloud_apig_environment.prod.id
}

# ============================================================
# DLI: Database, Tables for log/metrics querying (uses built-in default SQL queue, no dedicated queue needed)
# ============================================================

resource "huaweicloud_dli_database" "saas" {
  name        = "${replace(var.name_prefix, "-", "_")}_db"
  description = "Database for SaaS log and metrics analytics"
}

resource "huaweicloud_dli_table" "logs" {
  database_name = huaweicloud_dli_database.saas.name
  name          = "application_logs"
  data_location = "OBS"
  data_format   = "JSON"

  bucket_location = "obs://${huaweicloud_obs_bucket.logs.bucket}/"

  columns {
    name = "tenantId"
    type = "string"
  }
  columns {
    name = "message"
    type = "string"
  }
  columns {
    name = "timestamp"
    type = "string"
  }
  columns {
    name = "productId"
    type = "string"
  }
  columns {
    name = "orderId"
    type = "string"
  }
}

resource "huaweicloud_dli_table" "metrics" {
  database_name = huaweicloud_dli_database.saas.name
  name          = "application_metrics"
  data_location = "OBS"
  data_format   = "JSON"

  bucket_location = "obs://${huaweicloud_obs_bucket.metrics.bucket}/"

  columns {
    name = "tenantId"
    type = "string"
  }
  columns {
    name = "source"
    type = "string"
  }
  columns {
    name = "action"
    type = "string"
  }
  columns {
    name = "duration"
    type = "int"
  }
  columns {
    name = "timestamp"
    type = "string"
  }
}
