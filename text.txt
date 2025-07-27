# This block configures Terraform itself, including the required providers.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Added the random provider, which is needed for the random_pet resource.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider, setting the region for our resources.
provider "aws" {
  region = "us-east-1"
}

# --- Data Source to find the latest Amazon Linux 2 AMI ---
# This is the fix. Instead of hardcoding an AMI ID, this data source
# dynamically looks up the latest one in the specified region.
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# --- 1. The Network Foundation ---

# Create a dedicated VPC for our application.
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "terraform-project-vpc"
  }
}

# Create a public subnet in the first Availability Zone.
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  # This ensures instances launched here get a public IP.
  map_public_ip_on_launch = true
  tags = {
    Name = "terraform-public-subnet-a"
  }
}

# Create a second public subnet in a different Availability Zone for high availability.
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "terraform-public-subnet-b"
  }
}

# Create an Internet Gateway to allow traffic to and from the internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "terraform-project-igw"
  }
}

# Create a Route Table to route internet-bound traffic to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "terraform-public-rt"
  }
}

# Associate our public subnets with the public route table.
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# --- 2. Security Groups (Firewall Rules) ---

# Security Group for the Application Load Balancer.
# It allows inbound HTTP traffic from anywhere.
resource "aws_security_group" "alb_sg" {
  name        = "terraform-example-alb-sg"
  description = "Allow HTTP inbound traffic for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
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
}

# Security Group for the EC2 instances.
# It only allows inbound HTTP traffic *from the ALB's security group*.
resource "aws_security_group" "ec2_sg" {
  name        = "terraform-example-ec2-sg"
  description = "Allow HTTP inbound traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # This is the key security rule!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 3. The Server Blueprint (Launch Template) ---

# This template defines the configuration for the EC2 instances.
resource "aws_launch_template" "web_server" {
  name_prefix   = "terraform-web-server-lt"
  # Use the ID from the data source instead of a hardcoded value.
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # This script runs automatically when a new instance is launched.
  # It updates the server, installs Nginx, and starts the service.
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1 -y
              systemctl start nginx
              systemctl enable nginx
              echo "<h1>Hello from Terraform ASG!</h1>" > /usr/share/nginx/html/index.html
EOF
  )

  tags = {
    Name = "terraform-asg-instance"
  }
}

# --- 4. The Load Balancer and Target Group ---

# The Application Load Balancer itself.
resource "aws_lb" "main" {
  name               = "terraform-asg-example-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

# The Target Group, which the ALB forwards traffic to.
# It keeps track of which instances from the ASG are healthy.
resource "aws_lb_target_group" "main" {
  name     = "terraform-asg-example-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# The Listener tells the ALB to listen on port 80 and forward
# traffic to our target group.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# --- 5. The Auto Scaling Group ---

# This is the core resource that manages our fleet of servers.
resource "aws_autoscaling_group" "main" {
  name_prefix = "terraform-asg-example"
  
  # Reference the subnets where instances can be launched.
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  
  # Reference the Target Group to register new instances with the ALB.
  target_group_arns = [aws_lb_target_group.main.arn]

  # Use the Launch Template as the blueprint for new instances.
  launch_template {
    id      = aws_launch_template.web_server.id
    version = "$Latest"
  }

  # Scaling parameters
  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  # Health check settings
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "terraform-asg-instance"
    propagate_at_launch = true
  }
}

# --- 6. Outputs ---

output "load_balancer_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}
