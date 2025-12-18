terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.0.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "frontend_sg" {
  name        = "elearning-frontend-sg"
  description = "Security group para instancia frontend"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "elearning-frontend-sg"
  }
}

resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  subnet_id              = data.aws_subnet.default.id

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y ca-certificates curl gnupg lsb-release
              
              # Instalar Docker
              mkdir -m 0755 -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              
              # Agregar usuario ubuntu al grupo docker
              usermod -aG docker ubuntu
              
              # Instalar herramientas adicionales
              apt-get install -y git unzip
              
              # Crear directorio de la aplicación
              mkdir -p /opt/elearning-frontend
              
              # Configurar firewall (ufw)
              ufw allow 22/tcp
              ufw allow 80/tcp
              ufw allow 443/tcp
              ufw --force enable
              
              # Habilitar Docker al inicio
              systemctl enable docker
              systemctl start docker
              
              echo "Instalación completada. Instancia lista para despliegue del frontend."
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "elearning-frontend"
    Project = "e-learning"
    Environment = "production"
  }

  associate_public_ip_address = true
}

resource "aws_eip" "frontend_eip" {
  instance = aws_instance.frontend.id
  domain   = "vpc"
  
  tags = {
    Name = "elearning-frontend-eip"
    Project = "e-learning"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "elearning-deployer-key"
  public_key = file("/Users/leonardocarrillo/devKeys/terrafKey.pem.pub")
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "us-east-1a"
  default_for_az    = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "frontend_public_ip" {
  description = "IP pública de la instancia frontend"
  value       = aws_eip.frontend_eip.public_ip
}

output "frontend_public_dns" {
  description = "DNS público de la instancia frontend"
  value       = aws_instance.frontend.public_dns
}

output "ssh_command" {
  description = "Comando SSH para conectarse a la instancia"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.frontend_eip.public_ip}"
}

output "frontend_url" {
  description = "URL del frontend"
  value       = "http://${aws_eip.frontend_eip.public_ip}"
}