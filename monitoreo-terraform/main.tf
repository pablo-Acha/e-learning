# 1. Obtener la VPC existente por nombre
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["pablo-vpc-vpc"]
  }
}

# 2. Obtener subnets de esa VPC
data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

# 3. Obtener el último AMI Amazon Linux 2023
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }

  owners = ["amazon"]
}

# 4. Crear EC2 usando esos data sources
resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.small"
  subnet_id                   = data.aws_subnets.selected.ids[2]
  associate_public_ip_address = true

  key_name               = "redes-app"
  vpc_security_group_ids = [aws_security_group.ssh_sg.id]

  tags = {
    Name = "pablo-web-datasource"
  }
}


resource "aws_security_group" "ssh_sg" {
  name        = "pablo-ssh-sg"
  description = "Allow SSH access"
  vpc_id      = data.aws_vpc.selected.id

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
    Name = "pablo-ssh-sg"
  }
}
