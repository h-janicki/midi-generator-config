resource "aws_cloudwatch_log_group" "ecs" {
  name              = local.resource_names.log_group
  retention_in_days = var.environment == "prod" ? 30 : 7
}

resource "aws_ecs_cluster" "main" {
  name = local.resource_names.ecs_cluster

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = local.resource_names.ecs_task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = templatefile("${path.module}/../taskdefs/task_definition.json", {
    container_name         = local.container_name
    container_port         = local.container_port
    container_image        = var.container_image
    environment            = var.environment
    aws_region             = var.region
    db_host                = aws_db_instance.main.address
    db_port                = aws_db_instance.main.port
    db_name                = var.db_name
    db_username            = var.db_username
    s3_bucket              = aws_s3_bucket.midi.bucket
    anthropic_secret_arn   = local.anthropic_api_key_secret_arn
    db_password_secret_arn = aws_db_instance.main.master_user_secret[0].secret_arn
    log_group              = aws_cloudwatch_log_group.ecs.name
  })

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

resource "aws_ecs_service" "api" {
  name            = local.resource_names.ecs_service
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = local.container_name
    container_port   = local.container_port
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition]
  }
}