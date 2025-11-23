# 🚀 Guía de Despliegue de Backups en EC2

Esta guía te ayudará a configurar el sistema de backups automáticos en tu instancia EC2 de Ubuntu donde está desplegado el backend.

## 📍 Ubicación de los Scripts

Los scripts deben estar ubicados en la **instancia EC2 del backend**, ya que es donde se encuentra la conexión a la base de datos PostgreSQL.

**Ruta recomendada en EC2:**
```
/home/ubuntu/e-learning/backend/scripts/
```

O la ruta donde tengas desplegado tu backend.

## 🔧 Paso 1: Conectarse a la Instancia EC2 del Backend

```bash
ssh -i tu-clave.pem ubuntu@tu-ip-ec2-backend
```

## 📦 Paso 2: Instalar PostgreSQL Client

```bash
sudo apt-get update
sudo apt-get install -y postgresql-client
```

Verifica la instalación:
```bash
pg_dump --version
psql --version
```

## 📁 Paso 3: Copiar los Scripts al Servidor

### Opción A: Si usas Git
```bash
cd /home/ubuntu/e-learning/backend
git pull  # Si los scripts están en el repositorio
```

### Opción B: Si copias manualmente
```bash
# Desde tu máquina local, usa scp:
scp -i tu-clave.pem -r scripts/ ubuntu@tu-ip-ec2:/home/ubuntu/e-learning/backend/
```

## 🔐 Paso 4: Configurar Permisos

```bash
cd /home/ubuntu/e-learning/backend
chmod +x scripts/*.sh
```

## ⚙️ Paso 5: Verificar Variables de Entorno

Asegúrate de que el archivo `.env` en el directorio `backend/` tenga las variables de base de datos:

```bash
cd /home/ubuntu/e-learning/backend
cat .env | grep -E "DATABASE_URL|DB_NAME|DB_USER|DB_PASSWORD|DB_HOST|DB_PORT"
```

**Formato esperado:**
```env
DATABASE_URL=postgresql://usuario:contraseña@host:puerto/nombre_db
```

O:
```env
DB_NAME=nombre_db
DB_USER=usuario
DB_PASSWORD=contraseña
DB_HOST=host
DB_PORT=5432
```

## 🧪 Paso 6: Probar Backup Manual

Antes de configurar el cron job, prueba que el backup funcione:

```bash
cd /home/ubuntu/e-learning/backend
./scripts/backup-db.sh
```

**Salida esperada:**
```
[2024-11-02 14:05:30] ========================================
[2024-11-02 14:05:30] Iniciando proceso de backup
[2024-11-02 14:05:30] ========================================
[2024-11-02 14:05:30] Iniciando backup de la base de datos: nombre_db
[2024-11-02 14:05:32] ✓ Backup creado exitosamente: backup_nombre_db_20241102_140532.sql.gz (Tamaño: 2.5M)
[2024-11-02 14:05:32] ✓ Integridad del backup verificada
...
```

Verifica que se creó el backup:
```bash
ls -lh backups/
```

## ⏰ Paso 7: Configurar Cron Job Automático

Ejecuta el script de configuración:

```bash
cd /home/ubuntu/e-learning/backend
./scripts/setup-cron.sh
```

Sigue las instrucciones interactivas para seleccionar la frecuencia.

**Verificar que se configuró correctamente:**
```bash
crontab -l
```

Deberías ver algo como:
```
0 2 * * * PATH=/usr/local/bin:/usr/bin:/bin && cd /home/ubuntu/e-learning/backend && /home/ubuntu/e-learning/backend/scripts/backup-db.sh >> /home/ubuntu/e-learning/backend/logs/cron.log 2>&1 # postgresql-backup
```

## 📊 Paso 8: Monitorear los Backups

### Ver logs del cron job:
```bash
tail -f /home/ubuntu/e-learning/backend/logs/cron.log
```

### Ver todos los logs:
```bash
tail -f /home/ubuntu/e-learning/backend/logs/backup.log
```

### Listar backups creados:
```bash
ls -lh /home/ubuntu/e-learning/backend/backups/
```

### Ver estadísticas de espacio:
```bash
du -sh /home/ubuntu/e-learning/backend/backups/
```

## 🔄 Paso 9: Probar Restauración (Opcional - Solo en Desarrollo)

**⚠️ ADVERTENCIA: Solo prueba la restauración en un ambiente de desarrollo o staging, nunca en producción sin estar seguro.**

```bash
cd /home/ubuntu/e-learning/backend
./scripts/restore-db.sh
```

El script te mostrará los backups disponibles y te pedirá confirmación antes de restaurar.

## 🛡️ Paso 10: Configurar Almacenamiento Seguro (Opcional)

### Opción A: Montar un volumen EBS adicional

1. Crea un volumen EBS en AWS Console
2. Adjúntalo a tu instancia EC2
3. Monta el volumen:
```bash
sudo mkfs -t ext4 /dev/xvdf  # Ajusta según tu dispositivo
sudo mkdir /mnt/backups
sudo mount /dev/xvdf /mnt/backups
sudo chown ubuntu:ubuntu /mnt/backups
```

4. Edita `backup-db.sh` y cambia:
```bash
BACKUP_DIR="/mnt/backups"
```

5. Agrega al `/etc/fstab` para montaje automático:
```bash
/dev/xvdf /mnt/backups ext4 defaults,nofail 0 2
```

### Opción B: Sincronizar con S3 (Recomendado para producción)

Puedes crear un script adicional que sincronice los backups con S3:

```bash
#!/bin/bash
# sync-to-s3.sh
BACKUP_DIR="/home/ubuntu/e-learning/backend/backups"
S3_BUCKET="s3://tu-bucket/backups/database/"

aws s3 sync "$BACKUP_DIR" "$S3_BUCKET" --delete
```

Y agregarlo al cron job después del backup.

## 📋 Checklist de Verificación

- [ ] PostgreSQL client instalado
- [ ] Scripts copiados y con permisos de ejecución
- [ ] Variables de entorno configuradas correctamente
- [ ] Backup manual funciona correctamente
- [ ] Cron job configurado
- [ ] Logs se están generando correctamente
- [ ] Backups se están creando automáticamente
- [ ] Rotación de backups antiguos funciona (después de 30 días)

## 🔍 Solución de Problemas Comunes

### Error: "pg_dump: error: connection to server failed"
- Verifica que la base de datos esté accesible desde la instancia EC2
- Verifica las credenciales en `.env`
- Verifica el grupo de seguridad de EC2 permite conexión a PostgreSQL

### Error: "Permission denied"
```bash
chmod +x scripts/*.sh
```

### El cron job no se ejecuta
1. Verifica que el cron service esté corriendo:
```bash
sudo service cron status
```

2. Verifica los logs del sistema:
```bash
grep CRON /var/log/syslog
```

3. Verifica que las rutas en el cron job sean absolutas

### Los backups no se están creando
1. Verifica los logs:
```bash
cat logs/cron.log
cat logs/backup.log
```

2. Ejecuta manualmente el script para ver errores:
```bash
./scripts/backup-db.sh
```

## 📞 Soporte

Si encuentras problemas:
1. Revisa los logs en `backend/logs/`
2. Verifica las variables de entorno
3. Prueba ejecutar los scripts manualmente para ver errores detallados

## 🔐 Seguridad Adicional

### Proteger los backups con permisos restrictivos:
```bash
chmod 700 backups/
chmod 600 backups/*.sql.gz
```

### Encriptar backups (Opcional):
Puedes modificar `backup-db.sh` para usar `gpg` y encriptar los backups antes de guardarlos.

