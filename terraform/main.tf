
# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group
resource "aws_security_group" "allow_ssh_http" {
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "App port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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


# IAM Role for EC2 to access ECR
resource "aws_iam_role" "ec2_ecr_role" {
  name = "ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Amazon ECR read-only policy to the role
resource "aws_iam_role_policy_attachment" "ec2_ecr_attach" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_ecr_profile" {
  name = "ec2-ecr-profile"
  role = aws_iam_role.ec2_ecr_role.name
}


# EC2 Instance
resource "aws_instance" "app_server" {
  ami           = "ami-01776cde0c6f0677c"
  instance_type = "t2.micro"
  key_name      = var.key_name
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_ecr_profile.name
  user_data_replace_on_change = true

  root_block_device {
    delete_on_termination = true
  }

  tags = {
    Name = "App-Server"
  }
  user_data = <<-EOF
  #!/bin/bash
  set -ex

  # Update system
  sudo dnf update -y

  # Install required packages for rootless Docker
  sudo dnf install -y \
      shadow-utils \
      fuse-overlayfs \
      curl \
      git \
      systemd \
      dbus \
      iptables \
      unzip \
      jq

  # Enable lingering for ec2-user (allows user services to run without login)
  sudo loginctl enable-linger ec2-user

  # Install Docker rootless for ec2-user
  sudo -u ec2-user bash -c '
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      mkdir -p "$XDG_RUNTIME_DIR"
      
      # Download and install rootless Docker
      curl -fsSL https://get.docker.com/rootless | sh
      
      # Add Docker paths to bashrc
      echo "export PATH=\$HOME/bin:\$PATH" >> ~/.bashrc
      echo "export DOCKER_HOST=unix://\$XDG_RUNTIME_DIR/docker.sock" >> ~/.bashrc
      
      # Create systemd user directory
      mkdir -p ~/.config/systemd/user
      
      # Install Docker service for user
      ~/bin/dockerd-rootless-setuptool.sh install
  '

  # Install AWS CLI v2
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  rm -rf awscliv2.zip aws/

  # Install & enable SSM Agent
  sudo dnf install -y amazon-ssm-agent
  sudo systemctl enable --now amazon-ssm-agent

  # Wait for Docker to initialize
  sleep 10

  # Start Docker service for ec2-user and configure ECR login
  sudo -u ec2-user bash -c '
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      export PATH="$HOME/bin:$PATH"
      export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
      
      # Start Docker daemon
      systemctl --user start docker
      systemctl --user enable docker
      
      # Wait for Docker to be ready
      for i in {1..30}; do
          if docker version >/dev/null 2>&1; then
              echo "Docker is ready"
              break
          fi
          echo "Waiting for Docker to start... ($i/30)"
          sleep 2
      done
      
      # ECR login
      aws ecr get-login-password --region '${var.aws_region}' | docker login --username AWS --password-stdin '${var.aws_account_id}'.dkr.ecr.'${var.aws_region}'.amazonaws.com
  '
  echo "Rootless Docker setup completed successfully!"
  EOF
}