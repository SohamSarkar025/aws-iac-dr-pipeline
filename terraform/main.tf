terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "web_sg" {
  name        = "web-server-sg-dr"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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

# IAM Role so the EC2 instance can upload backups to S3 securely
resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2_s3_backup_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_s3_instance_profile"
  role = aws_iam_role.ec2_s3_role.name
}

resource "aws_s3_bucket" "dr_backup_bucket" {
  bucket        = "soham-dr-backup-bucket-2026"
  force_destroy = true
}

resource "aws_instance" "web_server" {
  ami                    = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS (us-east-1)
  instance_type          = "t2.micro"
  key_name               = "cloud-migration"
  subnet_id              = "subnet-0d98cba5e69bd6e68" # Subnet ID from the console
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  tags = {
    Name = "Infrastructure-DR-Node"
  }
}

output "instance_ip" {
  value = aws_instance.web_server.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.dr_backup_bucket.id
}
