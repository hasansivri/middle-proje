provider "aws" {
  region = "us-east-1"
}

variable "sec-gr-mutual" {
  default = "petclinic-k8s-mutual-sec-group"
}

variable "sec-gr-k8s-master" {
  default = "petclinic-k8s-master-sec-group"
}

variable "sec-gr-k8s-worker" {
  default = "petclinic-k8s-worker-sec-group"
}

data "aws_vpc" "name" {
  default = true
}

resource "aws_security_group" "petclinic-mutual-sg" {
  name   = var.sec-gr-mutual
  vpc_id = data.aws_vpc.name.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    self        = true
  }

  ingress {
    protocol    = "udp"
    from_port   = 8080
    to_port     = 8080
    self        = true
  }

  ingress {
    protocol    = "tcp"
    from_port   = 5000
    to_port     = 5000
    self        = true
  }
}

resource "aws_security_group" "petclinic-kube-worker-sg" {
  name   = var.sec-gr-k8s-worker
  vpc_id = data.aws_vpc.name.id

  ingress {
    protocol    = "tcp"
    from_port   = 30000
    to_port     = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kube-worker-secgroup"
  }
}

resource "aws_security_group" "petclinic-kube-master-sg" {
  name   = var.sec-gr-k8s-master
  vpc_id = data.aws_vpc.name.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 5000
    to_port     = 5000
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    self        = true
  }

  ingress {
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    self        = true
  }

  ingress {
    protocol    = "tcp"
    from_port   = 30000
    to_port     = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "kube-master-secgroup"
  }
}

resource "aws_iam_role" "roleforjenkins" {
  name               = "ecr_jenkins_permission_${local.user}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
    "arn:aws:iam::aws:policy/AdministratorAccess",
    "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
  ]
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "jenkinsprofile-${local.user}"
  role = aws_iam_role.roleforjenkins.name
}

resource "aws_instance" "kube-master" {
  ami                    = "ami-07d9b9ddc6cd8dd30"
  instance_type          = "t3a.medium"
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.petclinic-kube-master-sg.id, aws_security_group.petclinic-mutual-sg.id]
  key_name               = "clarus"
  subnet_id              = "subnet-012b73e2614cfbe2b"  # Select your own subnet_id of us-east-1a
  availability_zone      = "us-east-1a"
  
  tags = {
    Name        = "kube-master"
    Project     = "tera-kube-ans"
    Role        = "master"
    Id          = "1"
    environment = "dev"
  }
}

resource "aws_instance" "worker-1" {
  ami                    = "ami-07d9b9ddc6cd8dd30"
  instance_type          = "t3a.medium"
  vpc_security_group_ids = [aws_security_group.petclinic-kube-worker-sg.id, aws_security_group.petclinic-mutual-sg.id]
  key_name               = "clarus"
  subnet_id              = "subnet-012b73e2614cfbe2b"  # Select your own subnet_id of us-east-1a
  availability_zone      = "us-east-1a"
  
  tags = {
    Name        = "worker-1"
    Project     = "tera-kube-ans"
    Role        = "worker"
    Id          = "1"
    environment = "dev"
  }
}

output "kube-master-ip" {
  value       = aws_instance.kube-master.public_ip
  sensitive   = false
  description = "Public IP of the kube-master"
}

output "worker-1-ip" {
  value       = aws_instance.worker-1.public_ip
  sensitive   = false
  description = "Public IP of the worker-1"
}
