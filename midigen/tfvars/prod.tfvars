environment = "prod"
region      = "us-east-1"

container_image  = "PLACEHOLDER_REPLACE_AFTER_FIRST_ECR_PUSH"
container_cpu    = 512
container_memory = 1024
desired_count    = 2

db_instance_class    = "db.t4g.small"
db_allocated_storage = 50
