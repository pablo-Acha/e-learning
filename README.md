# Plataforma E-Learning - DevOps Project

Una plataforma completa de e-learning con frontend en React, backend en Node.js, y una infraestructura DevOps automatizada con Docker, GitHub Actions y AWS EC2.

## Características

- **Frontend React** con Vite y Tailwind CSS
- **Backend Node.js/Express** con Prisma ORM
- **Base de datos PostgreSQL**
- **Containerización** con Docker multi-stage
- **CI/CD Automatizado** con GitHub Actions
- **Despliegue automático** en AWS EC2
- **Múltiples registries** (GHCR + Docker Hub)
- **Entorno de desarrollo** con Docker Compose
- **Scripts de mantenimiento** automatizados

## Prerrequisitos

- **Git** - Control de versiones
- **Docker** & **Docker Compose** - Containerización
- **Node.js** 18+ - Runtime de JavaScript
- **Cuenta AWS** - Para EC2 (opcional para desarrollo local)

## Instalación y Configuración

### 1. Clonar el Repositorio

```bash
git clone https://github.com/pablo-Acha/e-learning.git
cd e-learning
```

### 2. Configurar Variables de Entorno

#### Backend (.env):
```bash
cd backend
cp .env.example .env
# Editar .env con tus configuraciones
DATABASE_URL="postgresql://usuario:password@localhost:5432/elearning"
JWT_SECRET="tu-jwt-secret"
AWS_ACCESS_KEY_ID="tu-access-key"
AWS_SECRET_ACCESS_KEY="tu-secret-key"
AWS_REGION="us-east-1"
S3_BUCKET_NAME="tu-bucket"
```

#### Frontend (.env):
```bash
cd ../elearning-frontend
cp .env.example .env
# Editar .env con tus configuraciones
VITE_API_BASE_URL=http://localhost:3001/api
```

### 3. Instalar Dependencias

#### Backend:
```bash
cd backend
npm install
```

#### Frontend:
```bash
cd ../elearning-frontend
npm install
```

## Ejecución Local con Docker Compose

### Opción 1: Desarrollo con Hot Reload

```bash
# En la raíz del proyecto
cd elearning-frontend
docker-compose up elearning-frontend
```

**URLs de desarrollo:**
- Frontend: http://34.236.38.254   
- Backend: http://3.19.223.47
- Base de datos: localhost:5432

### Opción 2: Producción Local

```bash
cd elearning-frontend
docker-compose up elearning-frontend
```

**URL de producción:** http://localhost:3000

### Opción 3: Todos los servicios

```bash
cd elearning-frontend
docker-compose up
```

## URL Pública en Producción

La aplicación está desplegada automáticamente en AWS EC2:

**URL Pública:** http://34.236.38.254 


## CI/CD Pipeline

El proyecto incluye un pipeline automatizado con GitHub Actions que se ejecuta:

1. **On push to main branch**
2. **Build y test** del frontend y backend
3. **Construcción de imágenes Docker** multi-stage optimizadas
4. **Push a registries** (GitHub Container Registry + Docker Hub)
5. **Despliegue automático** a AWS EC2
6. **Zero-downtime deployment**

### Registries de Imágenes

- **GitHub Container Registry:** `ghcr.io/tu-usuario/elearning-frontend`
- **Docker Hub:** `tu-usuario/elearning-frontend`

## Despliegue Manual a EC2

### 1. Configurar Instancia EC2

```bash
# Conectarse a la EC2
ssh -i tu-key.pem ubuntu@tu-ec2-ip

# Instalar Docker (si no está instalado)
sudo apt update
sudo apt install docker.io docker-compose

# Agregar usuario a grupo docker
sudo usermod -aG docker $USER
```

### 2. Desplegar Aplicación

```bash
# Crear directorio de la aplicación
mkdir -p /opt/elearning
cd /opt/elearning

# Copiar archivos de configuración
# ... (copiar docker-compose.yml, .env, etc.)

# Ejecutar aplicación
docker-compose up -d
```

### 3. Verificar Despliegue

```bash
# Ver contenedores en ejecución
docker ps

# Ver logs de la aplicación
docker logs elearning-frontend

# Probar health check
curl http://localhost:3000/health
```

### Funcionalidades del Script

- **Backup automático** de base de datos RDS
- **Logs de backup** resultados de la accion de backup
- **Restauración** de base de datos utilizando backups previos
- **Monitoreo** de recursos  
- **Actualización automática** de backups todos los dias a las 7:00 de la mañana usando crontab

## Estructura del Proyecto

```
e-learning/
├── .github/
│   └── workflows/
│       ├── ci.yml          # Pipeline frontend
│       └── ci_back.yml     # Pipeline backend
├── backend/                # API Node.js
│   ├── src/
│   ├── prisma/
│   ├── Dockerfile
│   └── package.json
├── elearning-frontend/     # React App
│   ├── src/
│   ├── public/
│   ├── Dockerfile
│   ├── Dockerfile.dev
│   ├── docker-compose.yml
│   └── package.json
├── containerd-ops.sh       # Script mantenimiento
└── README.md
```

### Problemas Comunes

1. **Puerto 80 en uso en EC2:**
   ```bash
   sudo lsof -i :80
   sudo kill -9 <PID>
   ```

2. **Error de permisos Docker:**
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

3. **Imagen no encontrada:**
   ```bash
   docker pull ghcr.io/tu-usuario/elearning-frontend:latest
   ```

### Logs y Monitoreo

```bash
# Ver logs de contenedores
docker logs elearning-frontend

# Ver logs del sistema
journalctl -u docker --since "1 hour ago"

# Monitorear recursos
docker stats
```

## Soporte

- **Documentación:** Este README
- **Issues:** GitHub Issues del proyecto
- **CI/CD:** GitHub Actions logs
- **EC2:** AWS CloudWatch logs

## Licencia

Este proyecto es para fines educativos como parte de una evaluación de DevOps.

---

**Acceder a http://localhost:3000  para desarrollo o http://34.236.38.254 para producción.**