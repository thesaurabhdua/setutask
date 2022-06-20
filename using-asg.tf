terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "setu-demo"

  cidr = "10.10.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnets = ["10.10.3.0/24", "10.10.4.0/24" ]
  database_subnets = ["10.10.5.0/24", "10.10.6.0/24" ]

  enable_nat_gateway = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  create_igw           = true
}



# Create Web Security Group
resource "aws_security_group" "web-sg" {
  name        = "Web-SG"
  description = "Allow HTTP inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-SG"
  }
}

# Create Application Security Group
resource "aws_security_group" "appserver-sg" {
  name        = "appserver-SG"
  description = "Allow inbound traffic from ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow traffic from web layer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Webserver-SG"
  }
}

#Create EC2 Instance
resource "aws_instance" "webserver1" {
  ami                    = "ami-08d4ac5b634553e16"
  count                  = 1
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a"
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  subnet_id              = module.vpc.private_subnets[0]
  user_data              = file("install_apache.sh")
  key_name               = "demo-key"
  tags = {
    Name = "Web Server"
  }

}

resource "aws_launch_template" "app-new" {
  name = "app-new"
  block_device_mappings {
    device_name = "/dev/sda1"
  }
  image_id = "ami-08d4ac5b634553e16"
  instance_type = "t2.micro"
  key_name = "demo-key"
  user_data              = file("install_apache.sh")
  vpc_security_group_ids = [aws_security_group.appserver-sg.id]

}

resource "aws_autoscaling_group" "applayer-asg" {
availability_zones = ["us-east-1a" , "us-east-1b"]
desired_capacity   = 2
max_size           = 2
min_size           = 2
launch_template {
  id      = aws_launch_template.app-new.id
  version = "$Latest"

}
}

# Create Database Security Group
resource "aws_security_group" "database-sg" {
  name        = "Database-SG"
  description = "Allow inbound traffic from application layer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow traffic from application layer"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web-sg.id]
  }

  egress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Database-SG"
  }
}

resource "aws_lb" "app-elb" {
  name               = "External-LB-new"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-sg.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "app-elb" {
  name     = "APP-TG-new"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_listener" "app-elb" {
  load_balancer_arn = aws_lb.app-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app-elb.arn
  }
}
resource "aws_db_instance" "default" {
  allocated_storage      = 10
  db_subnet_group_name   = "main-new"
  engine                 = "mysql"
  engine_version         = "8.0.20"
  instance_class         = "db.t2.micro"
  multi_az               = true
  name                   = "mydb"
  username               = "username"
  password               = "password"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.database-sg.id]
}

resource "aws_db_subnet_group" "default" {
  name       = "main-new"
  subnet_ids = module.vpc.database_subnets

  tags = {
    Name = "My DB subnet group"
  }
}

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.app-elb.dns_name
}
