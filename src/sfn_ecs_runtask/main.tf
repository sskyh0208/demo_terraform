locals {
  vpc_cidr_block = "10.0.0.0/16"

  az_1a = "${var.aws_region}a"
  az_1c = "${var.aws_region}c"

  instance_type = "t2.micro"
  image_id      = "ami-0847264f8522092f2"

  max_size = 1
  min_size = 0
  desired_capacity = 0

  container_name      = "nginx"
  container_image_uri = "public.ecr.aws/nginx/nginx:alpine-slim"

  definition_file_path = "./definitions/ecs_runtask.yaml"
}
###############################################################################
# VPC
###############################################################################
resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr_block
}

###############################################################################
# Subnet
###############################################################################
resource "aws_subnet" "pub_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 0)
  availability_zone = local.az_1a
}

resource "aws_subnet" "pub_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 1)
  availability_zone = local.az_1c
}

###############################################################################
# Internet Gateway
###############################################################################
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

###############################################################################
# Route Table
###############################################################################
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "pub_1a" {
  subnet_id      = aws_subnet.pub_1a.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "pub_1c" {
  subnet_id      = aws_subnet.pub_1c.id
  route_table_id = aws_route_table.main.id
}

###############################################################################
# Security Group
###############################################################################
resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###############################################################################
# IAM
###############################################################################
resource "aws_iam_role" "ec2" {
  name = "${var.product_name}-${local.env_name}-role-ec2"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
  ]
}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type        = "Service"
      identifiers = [ "ec2.amazonaws.com" ]
    }
  }
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.product_name}-${local.env_name}-instance-profile-ec2"
  role = aws_iam_role.ec2.name
}

data "aws_iam_policy_document" "assume_ecs" {
  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type        = "Service"
      identifiers = [ "ecs-tasks.amazonaws.com" ]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.product_name}-${local.env_name}-role-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.product_name}-${local.env_name}-role-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ]
}

resource "aws_iam_role" "sfn" {
  name                = "${var.product_name}-${local.env_name}-role-sfn"
  assume_role_policy  = data.aws_iam_policy_document.assume_sfn.json
  managed_policy_arns = [
    aws_iam_policy.custom_sfn.arn,
  ]
}

data "aws_iam_policy_document" "assume_sfn" {
  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type        = "Service"
      identifiers = [ "states.amazonaws.com" ]
    }
  }
}

resource "aws_iam_policy" "custom_sfn" {
  name        = "${var.product_name}-${local.env_name}-custom-policy-sfn"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:events:${var.aws_region}:${local.aws_account_id}:rule/StepFunctions*"
      },
      {
        Action  = [
          "ecs:RunTask",
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${local.aws_account_id}:task-definition/${var.product_name}-${local.env_name}-ecs-task-main:*",
        ]
      },
      {
        Action  = [
          "ecs:DescribeTasks",
          "ecs:StopTask",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action  = [
          "iam:PassRole",
        ]
        Effect   = "Allow"
        Resource = [
          aws_iam_role.ecs_execution.arn,
          aws_iam_role.ecs_task.arn,
        ]
      }
    ]
  })
}

###############################################################################
# Launch Template
###############################################################################
resource "aws_launch_template" "main" {
  name_prefix   = "${var.product_name}-${local.env_name}-lt-main"
  image_id      = local.image_id
  instance_type = local.instance_type
  user_data     = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${var.product_name}-${local.env_name}-ecs-main >> /etc/ecs/ecs.config
EOF
)

  monitoring {
    enabled = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.product_name}-${local.env_name}-instance-main"
    }
  }

  network_interfaces {
    security_groups = [ aws_security_group.main.id ]
    associate_public_ip_address = true
  }
}

###############################################################################
# AutoScalingGroup
###############################################################################
resource "aws_autoscaling_group" "main" {
  name                 = "${var.product_name}-${local.env_name}-asg-main"
  max_size             = local.max_size
  min_size             = local.min_size
  desired_capacity     = local.desired_capacity
  default_cooldown     = 60
  vpc_zone_identifier  = [ aws_subnet.pub_1a.id, aws_subnet.pub_1c.id ]

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [ desired_capacity ]
  }
}

###############################################################################
# ECS Cluster
###############################################################################
resource "aws_ecs_cluster" "main" {
  name = "${var.product_name}-${local.env_name}-ecs-main"
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [ aws_ecs_capacity_provider.main.name ]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    base   = 0
    weight = 1
  }
}

resource "aws_ecs_capacity_provider" "main" {
  name = "${var.product_name}-${local.env_name}-ecs-cp-main"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.main.arn
    managed_scaling {
      status                    = "ENABLED"
      instance_warmup_period    = 30
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      target_capacity           = 100
    }
  }
}

###############################################################################
# Task Definition
###############################################################################
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.product_name}-${local.env_name}-ecs-task-main"
  network_mode             = "bridge"
  requires_compatibilities = [ "EC2" ]
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  container_definitions    = jsonencode([
    {
      name      = local.container_name
      image     = local.container_image_uri
      cpu       = 128
      memory    = 256
      essential = true
      portMappings = [
        {
          name          = local.container_name
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true"
          awslogs-group         = "${var.product_name}-${local.env_name}-ecs-task-main-logs"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = local.container_name
        }
      }
    }
  ])
}

###############################################################################
# StepFunctions
###############################################################################
resource "aws_sfn_state_machine" "state" {
  name = "${var.product_name}-${local.env_name}-sfn-esc-runtask"
  role_arn = aws_iam_role.sfn.arn

  definition = jsonencode(yamldecode(templatefile(local.definition_file_path, {
    ClusterArn        = aws_ecs_cluster.main.arn,
    ContainerName     = local.container_name,
    TaskDefinitionArn = aws_ecs_task_definition.main.arn,
  })))
}