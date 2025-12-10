# Scripts de Backup y Restauración para PostgreSQL

Este directorio contiene scripts para realizar backups automáticos y restauración de la base de datos PostgreSQL del proyecto e-learning.

## Estructura de Archivos

- `backup-db.sh` - Script principal para crear backups de la base de datos
- `restore-db.sh` - Script para restaurar backups
- `setup-cron.sh` - Script para configurar el cron job automático
- `README.md` - Esta documentación

## Instalación y Configuración

### Prerrequisitos

1. **PostgreSQL Client Tools**: Asegúrate de tener `pg_dump` y `psql` instalados:
   ```bash
   sudo apt-get update
   sudo apt-get install postgresql-client
   ```

2. **Permisos de ejecución**: Los scripts deben tener permisos de ejecución:
   ```bash
   chmod +x scripts/*.sh
   ```

### Configuración de Variables de Entorno

El script lee las variables de base de datos desde el archivo `.env` en el directorio `backend/`. Asegúrate de que esté configurado con una de estas opciones:

**Opción 1: Usando DATABASE_URL**
```env
DATABASE_URL=postgresql://usuario:contraseña@host:puerto/nombre_db
```

**Opción 2: Usando variables individuales**
```env
DB_NAME=nombre_db
DB_USER=usuario
DB_PASSWORD=contraseña
DB_HOST=host
DB_PORT=5432
```

## Uso de los Scripts

### 1. Backup Manual

Para crear un backup manual de la base de datos:

```bash
cd /ruta/al/backend
./scripts/backup-db.sh
```

El backup se guardará en: `backend/backups/backup_[nombre_db]_[timestamp].sql.gz`

### 2. Configurar Backups Automáticos (Cron Job)

Para configurar backups automáticos:

```bash
cd /ruta/al/backend
./scripts/setup-cron.sh
```

El script te permitirá elegir la frecuencia:
- Diario a las 2:00 AM
- Diario a las 3:00 AM
- Cada 12 horas
- Cada 6 horas
- Personalizado (expresión cron manual)

**Verificar cron job configurado:**
```bash
crontab -l
```

**Eliminar cron job:**
```bash
crontab -l | grep -v 'postgresql-backup' | crontab -
```

### 3. Restaurar un Backup

#### Modo Interactivo (listar y seleccionar):
```bash
cd /ruta/al/backend
./scripts/restore-db.sh
```

#### Modo con archivo específico:
```bash
cd /ruta/al/backend
./scripts/restore-db.sh backup_nombre_db_20241102_140530.sql.gz
```

**IMPORTANTE:** El script de restauración crea automáticamente un backup de seguridad antes de restaurar.

## Estructura de Directorios

Después de ejecutar los scripts, se crearán los siguientes directorios:

```
backend/
├── backups/          # Backups comprimidos (.sql.gz)
├── logs/            # Logs de backups y restauraciones
│   ├── backup.log
│   ├── restore.log
│   └── cron.log
└── scripts/         # Scripts de backup y restauración
```

## Seguridad

- Los backups se almacenan localmente en `backend/backups/`
- Los backups están comprimidos para ahorrar espacio
- Se verifica la integridad de los backups después de crearlos
- Los backups antiguos se eliminan automáticamente después de 30 días (configurable)

## Características

### Script de Backup (`backup-db.sh`)
- Crea backups comprimidos (gzip)
- Verifica integridad del backup
- Rotación automática de backups antiguos (30 días por defecto)
- Logging detallado
- Estadísticas de backups

### Script de Restauración (`restore-db.sh`)
- Modo interactivo para seleccionar backup
- Modo con archivo específico
- Crea backup de seguridad antes de restaurar
- Confirmación antes de restaurar
- Verificación de integridad

### Script de Configuración (`setup-cron.sh`)
- Configuración interactiva de frecuencia
- Soporte para expresiones cron personalizadas
- Reemplazo de cron jobs existentes

## Configuración Avanzada

### Cambiar días de retención

Edita `backup-db.sh` y modifica la variable:
```bash
RETENTION_DAYS=30  # Cambiar a los días deseados
```

### Cambiar ubicación de backups

Edita `backup-db.sh` y modifica:
```bash
BACKUP_DIR="$BACKEND_DIR/backups"  # Cambiar a la ruta deseada
```

## Logs

Los logs se guardan en `backend/logs/`:
- `backup.log` - Logs de backups manuales y automáticos
- `restore.log` - Logs de restauraciones
- `cron.log` - Logs específicos del cron job

## Pruebas

### Probar backup manual:
```bash
./scripts/backup-db.sh
```

### Verificar backups creados:
```bash
ls -lh backups/
```

### Probar restauración (en ambiente de desarrollo):
```bash
./scripts/restore-db.sh
```

## Solución de Problemas

### Error: "pg_dump no está instalado"
```bash
sudo apt-get install postgresql-client
```

### Error: "Permission denied"
```bash
chmod +x scripts/*.sh
```

### Error: "No se puede conectar a la base de datos"
- Verifica que las variables de entorno estén correctamente configuradas
- Verifica que la base de datos esté accesible desde el servidor
- Verifica credenciales y permisos del usuario de PostgreSQL

### Ver logs de errores:
```bash
tail -f logs/backup.log
tail -f logs/restore.log
tail -f logs/cron.log
```

## Checklist de Despliegue en EC2

1. Conectarse a la instancia EC2 del backend
2. Instalar PostgreSQL client: `sudo apt-get install postgresql-client`
3. Copiar los scripts al servidor
4. Dar permisos de ejecución: `chmod +x scripts/*.sh`
5. Verificar que el archivo `.env` tenga las variables de base de datos correctas
6. Probar backup manual: `./scripts/backup-db.sh`
7. Configurar cron job: `./scripts/setup-cron.sh`
8. Verificar que el cron job esté activo: `crontab -l`
9. Monitorear logs después de 24 horas para confirmar que funciona

## Integración con CI/CD

Si deseas integrar estos scripts en tu pipeline de CI/CD, puedes ejecutar:

```bash
# En tu pipeline
./scripts/backup-db.sh
```

## Soporte

Para problemas o preguntas, revisa los logs en `backend/logs/` o contacta al equipo de desarrollo.

