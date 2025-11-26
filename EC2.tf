terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ua-central-1"
}

# Get the latest Ubuntu 22.04 (Jammy) image published by Canonical in the selected region
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Default VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Security group allowing SSH
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_ssh"
  }
}

variable "public_key_path" {
  description = "Path to the public SSH key for EC2 access"
  type        = string
  default     = "../keys/ansible_ssh.pub"
}

resource "aws_key_pair" "ansible" {
  key_name   = "ansible-ec2-key"
  public_key = file(var.public_key_path)
}

# EC2 instance
resource "aws_instance" "ubuntu" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  subnet_id                  = data.aws_subnet_ids.default.ids[0]
  vpc_security_group_ids     = [aws_security_group.allow_ssh.id]
  associate_public_ip_address = true
  key_name = aws_key_pair.ansible.key_name

  tags = {
    Name = "ubuntu-t3-micro"
  }
}

output "instance_id" {
  value = aws_instance.ubuntu.id
}

output "public_ip" {
  value = aws_instance.ubuntu.public_ip
}
