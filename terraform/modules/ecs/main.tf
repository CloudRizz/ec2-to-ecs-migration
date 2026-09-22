# Creates the ECS cluster that will run the Fargate service.
resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  # Enables enhanced ECS metrics for operational visibility.
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-cluster"
    }
  )
}

# Allows application traffic only from the ALB to the Fargate tasks.
resource "aws_security_group" "ecs" {
  name        = "${var.name_prefix}-ecs-sg"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow application traffic from the ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  # Allows Fargate tasks to reach required AWS and external HTTPS endpoints through the NAT Gateway.
  egress {
    description = "Allow HTTPS traffic to required external services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ecs-sg"
    }
  )
}

# Stores application logs written by the Fargate containers.
resource "aws_cloudwatch_log_group" "ecs" {
  # checkov:skip=CKV_AWS_338:Thirty-day retention is intentional for this short-lived portfolio environment.
  # checkov:skip=CKV_AWS_158:AWS-managed encryption at rest is sufficient for this short-lived environment; customer-managed KMS is deferred.
  name              = "/ecs/${var.name_prefix}"
  retention_in_days = 30

  tags = var.tags
}

# Defines how the Flask application runs as a Fargate task.
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.name_prefix}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "APP_NAME"
          value = "ecs-migration-api"
        },
        {
          name  = "APP_VERSION"
          value = "1.0.0"
        },
        {
          name  = "ENVIRONMENT"
          value = "production"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-app"
    }
  )
}

# Runs the Flask task on Fargate and registers it with the ALB.
resource "aws_ecs_service" "app" {
  name            = "${var.name_prefix}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Lets Service Auto Scaling manage task count after the initial deployment.
  lifecycle {
    ignore_changes = [desired_count]
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = 60

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-service"
    }
  )
}

# Registers the ECS service as a scalable target between the configured task limits.
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Keeps average ECS service CPU near the target by scaling the task count.
resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${var.name_prefix}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.cpu_target_value

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
