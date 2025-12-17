
variable "aws_region" {
  description = "Región de AWS donde desplegar los recursos"
  type        = string
  default     = "us-east-1"
}

variable "backend_instance_type" {
  description = "Tipo de instancia EC2 para el backend"
  type        = string
  default     = "t3.micro"
}

variable "backend_volume_size" {
  description = "Tamaño del volumen root en GB"
  type        = number
  default     = 30
}

variable "ssh_public_key_path" {
  description = "Ruta a la clave pública SSH para acceso a las instancias"
  type        = string
  default     = "/Users/leonardocarrillo/devKeys/devKey.pem.pub"
}

variable "allowed_ssh_cidr_blocks" {
  description = "Bloques CIDR permitidos para acceso SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_api_cidr_blocks" {
  description = "Bloques CIDR permitidos para acceso a la API (puerto 3001)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_postgres_cidr_blocks" {
  description = "Bloques CIDR permitidos para acceso a PostgreSQL (puerto 5432)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "environment" {
  description = "Ambiente de despliegue (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Nombre del proyecto para tagging"
  type        = string
  default     = "e-learning"
}

variable "availability_zone" {
  description = "Zona de disponibilidad para la instancia"
  type        = string
  default     = "us-east-1a"
}

variable "database_name" {
  description = "Nombre de la base de datos PostgreSQL"
  type        = string
  default     = "elearning"
}

variable "database_user" {
  description = "Usuario de la base de datos PostgreSQL"
  type        = string
  default     = "elearning_user"
}

variable "database_password" {
  description = "Contraseña del usuario de la base de datos"
  type        = string
  default     = "elearning_password"
  sensitive   = true
}