# You probably want to keep your ip address a secret as well
variable "ssh_cidr" {
  type        = string
  description = "Your home IP in CIDR notation"
}

# name of the existing AWS key pair
variable "ssh_key_name" {
  type        = string
  description = "Name of your existing AWS key pair"
}

# Your GitHub repository URL
variable "git_repo_url" {
  type        = string
  description = "URL of your GitHub repository to clone"
}

# The provider of your cloud service, in this case it is AWS. 
provider "aws" {
  region = "us-west-2" # Which region you are working on
}

# Your ec2 instance
resource "aws_instance" "demo-instance" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  iam_instance_profile   = "LabInstanceProfile"
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.web.id]
  key_name               = var.ssh_key_name

  # This script runs automatically when the instance first boots
  user_data = <<-EOF
              #!/bin/bash
              # Log all output for debugging
              exec > /var/log/user-data.log 2>&1
              set -x

              # Update the system
              yum update -y

              # Install Git
              yum install -y git

              # Install Docker
              yum install -y docker
              systemctl start docker
              systemctl enable docker

              # Add ec2-user to docker group
              usermod -aG docker ec2-user

              # Clone your repository
              cd /home/ec2-user
              git clone ${var.git_repo_url} app
              chown -R ec2-user:ec2-user app

              # Navigate to the docker-gs-ping directory and build/run the container
              cd app/HW2/docker-gs-ping
              docker build -t docker-gs-ping .
              docker run -d -p 8080:8080 docker-gs-ping
              EOF

  tags = {
    Name = "terraform-docker-instance"
  }
}

# Security group for SSH access from your IP
resource "aws_security_group" "ssh" {
  name        = "allow_ssh_from_me"
  description = "SSH from a single IP"
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for HTTP traffic (so you can access your app)
resource "aws_security_group" "web" {
  name        = "allow_web_traffic"
  description = "Allow inbound HTTP traffic for the app"
  ingress {
    description = "HTTP on port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allows access from anywhere
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# latest Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64-ebs"]
  }
}

output "ec2_public_dns" {
  value = aws_instance.demo-instance.public_dns
}

output "ec2_public_ip" {
  value = aws_instance.demo-instance.public_ip
}

output "app_url" {
  value = "http://${aws_instance.demo-instance.public_ip}:8080/albums"
}
