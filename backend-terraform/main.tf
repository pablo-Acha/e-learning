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

resource "aws_security_group" "backend_sg" {
  name        = "elearning-backend-sg"
  description = "Security group para instancia backend"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
    description = "API access"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
    description = "PostgreSQL access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "elearning-backend-sg"
  }
}

resource "aws_instance" "backend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  subnet_id              = data.aws_subnet.default.id

  root_block_device {
    volume_size = 30
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
              
              # Instalar Node.js 20.x
              curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
              apt-get install -y nodejs
              
              # Instalar PostgreSQL
              apt-get install -y postgresql postgresql-contrib
              
              # Configurar PostgreSQL
              sudo -u postgres psql -c "CREATE DATABASE elearning;"
              sudo -u postgres psql -c "CREATE USER elearning_user WITH PASSWORD 'elearning_password';"
              sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE elearning TO elearning_user;"
              
              # Configurar pg_hba.conf para conexiones remotas
              echo "host elearning elearning_user 0.0.0.0/0 md5" >> /etc/postgresql/*/main/pg_hba.conf
              
              # Configurar postgresql.conf para escuchar en todas las interfaces
              sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
              
              # Agregar usuario ubuntu al grupo docker
              usermod -aG docker ubuntu
              
              # Instalar herramientas adicionales
              apt-get install -y git unzip
              
              # Crear directorios de la aplicación
              mkdir -p /opt/elearning-backend
              
              # Configurar firewall
              ufw allow 22/tcp
              ufw allow 3001/tcp
              ufw allow 5432/tcp
              ufw --force enable
              
              # Habilitar servicios al inicio
              systemctl enable docker
              systemctl enable postgresql
              
              # Reiniciar PostgreSQL para aplicar configuraciones
              systemctl restart postgresql
              
              # Iniciar Docker
              systemctl start docker
              
              echo "Instalación completada. Instancia lista para despliegue del backend."
              echo "PostgreSQL disponible en: localhost:5432"
              echo "API disponible en: localhost:3001"
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "elearning-backend"
    Project = "e-learning"
    Environment = "production"
  }

  associate_public_ip_address = true
}

resource "aws_key_pair" "deployer" {
  key_name   = "elearning-deployer-key-backend"
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

output "backend_private_ip" {
  description = "IP privada de la instancia backend"
  value       = aws_instance.backend.private_ip
}

output "backend_private_dns" {
  description = "DNS privado de la instancia backend"
  value       = aws_instance.backend.private_dns
}

output "ssh_command_backend" {
  description = "Comando SSH para conectarse al backend (via bastion)"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.backend.private_ip}"
}

output "postgresql_connection_string" {
  description = "String de conexión a PostgreSQL"
  value       = "postgresql://elearning_user:elearning_password@${aws_instance.backend.private_ip}:5432/elearning"
}

output "api_url" {
  description = "URL de la API backend"
  value       = "http://${aws_instance.backend.private_ip}:3001"
}