environment = "dev"
region      = "us-east-1"

container_image  = "589076184865.dkr.ecr.us-east-1.amazonaws.com/midigen-dev-api:initial"
container_cpu    = 256
container_memory = 512
desired_count    = 1

db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20