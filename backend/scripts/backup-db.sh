#!/bin/bash

###############################################################################
# Script de Backup Automático para PostgreSQL
# Este script crea backups de la base de datos y los almacena de forma segura
# con rotación automática de backups antiguos
###############################################################################

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$BACKEND_DIR/backups"
LOG_DIR="$BACKEND_DIR/logs"
LOG_FILE="$LOG_DIR/backup.log"
RETENTION_DAYS=30  # Días de retención de backups

# Cargar variables de entorno desde .env si existe
if [ -f "$BACKEND_DIR/.env" ]; then
    export $(cat "$BACKEND_DIR/.env" | grep -v '^#' | xargs)
fi

# Variables de base de datos (desde .env o variables de entorno)
DB_NAME="${DB_NAME:-${DATABASE_URL##*/}}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

# Si DATABASE_URL está definida, extraer información
if [ ! -z "$DATABASE_URL" ]; then
    # Extraer información de DATABASE_URL (formato: postgresql://user:password@host:port/database)
    # Remover el protocolo
    DB_URL_NO_PROTO=$(echo "$DATABASE_URL" | sed 's|^[^:]*://||')
    
    # Extraer usuario (puede incluir contraseña)
    DB_USER_PASS=$(echo "$DB_URL_NO_PROTO" | cut -d'@' -f1)
    DB_USER=$(echo "$DB_USER_PASS" | cut -d':' -f1)
    
    # Extraer host, puerto y base de datos
    DB_HOST_PORT_DB=$(echo "$DB_URL_NO_PROTO" | cut -d'@' -f2)
    DB_HOST=$(echo "$DB_HOST_PORT_DB" | cut -d':' -f1)
    DB_PORT_DB=$(echo "$DB_HOST_PORT_DB" | cut -d':' -f2)
    DB_PORT=$(echo "$DB_PORT_DB" | cut -d'/' -f1)
    DB_NAME=$(echo "$DB_PORT_DB" | cut -d'/' -f2 | cut -d'?' -f1)
    
    # Si no se pudo extraer el puerto, usar el default
    if [ -z "$DB_PORT" ] || [ "$DB_PORT" = "$DB_NAME" ]; then
        DB_PORT="5432"
    fi
fi

# Crear directorios si no existen
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

# Función de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Función para verificar si pg_dump está instalado
check_pg_dump() {
    if ! command -v pg_dump &> /dev/null; then
        log "${RED}ERROR: pg_dump no está instalado. Instálalo con: sudo apt-get install postgresql-client${NC}"
        exit 1
    fi
}

# Función para verificar conexión a la base de datos
check_db_connection() {
    log "${YELLOW}Verificando conexión a la base de datos...${NC}"
    
    local connection_ok=0
    if [ ! -z "$DATABASE_URL" ]; then
        # Verificar conexión usando DATABASE_URL
        if command -v psql &> /dev/null; then
            psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1
            connection_ok=$?
        else
            log "${YELLOW}⚠ psql no está instalado, no se puede verificar la conexión${NC}"
            return 0
        fi
    else
        # Verificar conexión usando variables individuales
        if [ -z "$DB_PASSWORD" ]; then
            log "${RED}ERROR: DB_PASSWORD no está definida${NC}"
            return 1
        fi
        if command -v psql &> /dev/null; then
            export PGPASSWORD="${DB_PASSWORD}"
            psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1
            connection_ok=$?
            unset PGPASSWORD
        else
            log "${YELLOW}⚠ psql no está instalado, no se puede verificar la conexión${NC}"
            return 0
        fi
    fi
    
    if [ $connection_ok -eq 0 ]; then
        log "${GREEN}✓ Conexión a la base de datos verificada${NC}"
        return 0
    else
        log "${RED}✗ ERROR: No se pudo conectar a la base de datos${NC}"
        log "${YELLOW}Verifica:${NC}"
        log "  - Que la base de datos esté accesible desde este servidor"
        log "  - Que las credenciales sean correctas"
        log "  - Que el host '$DB_HOST' sea accesible"
        log "  - Que el puerto '$DB_PORT' esté abierto"
        log "  - Que la base de datos '$DB_NAME' exista"
        return 1
    fi
}

# Función para crear backup
create_backup() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/backup_${DB_NAME}_${timestamp}.sql"
    local backup_file_compressed="${backup_file}.gz"
    local error_file="$LOG_DIR/backup_error_${timestamp}.log"
    
    log "${GREEN}Iniciando backup de la base de datos: $DB_NAME${NC}"
    log "  Host: ${DB_HOST:-N/A}"
    log "  Puerto: ${DB_PORT:-N/A}"
    log "  Usuario: ${DB_USER:-N/A}"
    log "  Base de datos: $DB_NAME"
    
    # Crear backup (incluyendo esquema Y datos)
    local pg_dump_exit_code=0
    # Opciones de pg_dump:
    # --clean: Incluye comandos DROP antes de CREATE (útil para restauración)
    # --if-exists: Usa IF EXISTS en los DROP (evita errores)
    # --no-owner: No incluye comandos de ownership (evita problemas de permisos)
    # --no-acl: No incluye permisos (evita problemas de permisos)
    # Sin --schema-only: Incluye DATOS además del esquema
    local pg_dump_options="--clean --if-exists --no-owner --no-acl"
    
    if [ ! -z "$DATABASE_URL" ]; then
        # Usar DATABASE_URL directamente
        log "${YELLOW}Usando DATABASE_URL para conexión${NC}"
        log "${YELLOW}Creando backup completo (esquema + datos)...${NC}"
        pg_dump $pg_dump_options "$DATABASE_URL" > "$backup_file" 2> "$error_file"
        pg_dump_exit_code=$?
    else
        # Usar variables individuales
        if [ -z "$DB_PASSWORD" ]; then
            log "${RED}ERROR: DB_PASSWORD no está definida${NC}"
            return 1
        fi
        export PGPASSWORD="${DB_PASSWORD}"
        log "${YELLOW}Usando variables individuales para conexión${NC}"
        log "${YELLOW}Creando backup completo (esquema + datos)...${NC}"
        pg_dump $pg_dump_options -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > "$backup_file" 2> "$error_file"
        pg_dump_exit_code=$?
        unset PGPASSWORD
    fi
    
    # Mostrar error si existe
    if [ $pg_dump_exit_code -ne 0 ]; then
        log "${RED}✗ ERROR: Fallo al crear el backup${NC}"
        if [ -f "$error_file" ] && [ -s "$error_file" ]; then
            log "${RED}Detalles del error:${NC}"
            local error_content=$(cat "$error_file")
            while IFS= read -r line; do
                log "${RED}  $line${NC}"
            done < "$error_file"
            
            # Detectar error de versión
            if echo "$error_content" | grep -q "server version mismatch"; then
                log ""
                log "${YELLOW}⚠ PROBLEMA DE VERSIÓN DETECTADO${NC}"
                log "${YELLOW}El cliente de PostgreSQL en este servidor no es compatible con la versión del servidor.${NC}"
                log ""
                log "${YELLOW}Solución: Actualizar PostgreSQL client a la versión 17${NC}"
                log "Ejecuta los siguientes comandos en el servidor EC2:"
                log ""
                log "  # Agregar repositorio oficial de PostgreSQL"
                log "  sudo sh -c 'echo \"deb http://apt.postgresql.org/pub/repos/apt \$(lsb_release -cs)-pgdg main\" > /etc/apt/sources.list.d/pgdg.list'"
                log "  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -"
                log "  sudo apt-get update"
                log ""
                log "  # Instalar PostgreSQL 17 client"
                log "  sudo apt-get install -y postgresql-client-17"
                log ""
                log "  # Verificar versión instalada"
                log "  pg_dump --version"
                log ""
                log "${YELLOW}Alternativa temporal (NO RECOMENDADO):${NC}"
                log "  Usar pg_dump con --no-version-check (puede causar problemas)"
                return 1
            fi
        fi
        log "${YELLOW}Verifica:${NC}"
        log "  - Que la base de datos esté accesible desde este servidor"
        log "  - Que las credenciales sean correctas"
        log "  - Que el usuario tenga permisos para hacer backup"
        log "  - Que la base de datos '$DB_NAME' exista"
        rm -f "$backup_file" "$error_file"
        return 1
    fi
    
    # Verificar que el archivo se creó y no está vacío
    if [ ! -f "$backup_file" ] || [ ! -s "$backup_file" ]; then
        log "${RED}✗ ERROR: El archivo de backup está vacío o no se creó${NC}"
        rm -f "$backup_file" "$error_file"
        return 1
    fi
    
    # Verificar tamaño mínimo del backup (debe tener al menos 1KB de contenido)
    local backup_size=$(wc -c < "$backup_file")
    if [ $backup_size -lt 1024 ]; then
        log "${YELLOW}⚠ Advertencia: El backup es muy pequeño (${backup_size} bytes)${NC}"
        log "${YELLOW}Esto puede indicar que la base de datos está vacía o que hubo un problema${NC}"
        
        # Mostrar primeras líneas para diagnóstico
        log "${YELLOW}Primeras líneas del backup:${NC}"
        head -n 10 "$backup_file" | while IFS= read -r line; do
            log "${YELLOW}  $line${NC}"
        done
    fi
    
    # Verificar que el backup contiene contenido SQL válido
    if ! head -n 20 "$backup_file" | grep -qiE "(CREATE|INSERT|COPY|SET|--|PostgreSQL)"; then
        log "${RED}✗ ERROR: El backup no contiene contenido SQL válido${NC}"
        log "${RED}El archivo puede estar corrupto o la base de datos puede estar vacía${NC}"
        rm -f "$backup_file" "$error_file"
        return 1
    fi
    
    # Limpiar archivo de error si todo salió bien
    rm -f "$error_file"
    
    if [ $pg_dump_exit_code -eq 0 ]; then
        # Comprimir backup
        gzip "$backup_file"
        
        if [ $? -eq 0 ]; then
            local file_size=$(du -h "$backup_file_compressed" | cut -f1)
            log "${GREEN}✓ Backup creado exitosamente: $backup_file_compressed (Tamaño: $file_size)${NC}"
            
            # Verificar integridad del backup comprimido
            if gzip -t "$backup_file_compressed" 2>/dev/null; then
                log "${GREEN}✓ Integridad del backup verificada${NC}"
            else
                log "${RED}✗ ERROR: El backup comprimido está corrupto${NC}"
                rm -f "$backup_file_compressed"
                return 1
            fi
            
            return 0
        else
            log "${RED}✗ ERROR: Fallo al comprimir el backup${NC}"
            rm -f "$backup_file"
            return 1
        fi
    fi
}

# Función para limpiar backups antiguos
cleanup_old_backups() {
    log "${YELLOW}Limpiando backups más antiguos de $RETENTION_DAYS días...${NC}"
    
    local deleted_count=$(find "$BACKUP_DIR" -name "backup_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete -print | wc -l)
    
    if [ $deleted_count -gt 0 ]; then
        log "${GREEN}✓ Eliminados $deleted_count backups antiguos${NC}"
    else
        log "${GREEN}✓ No hay backups antiguos para eliminar${NC}"
    fi
}

# Función para mostrar estadísticas
show_stats() {
    local total_backups=$(find "$BACKUP_DIR" -name "backup_*.sql.gz" -type f | wc -l)
    local total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    
    log "${GREEN}Estadísticas de backups:${NC}"
    log "  - Total de backups: $total_backups"
    log "  - Tamaño total: $total_size"
    log "  - Ubicación: $BACKUP_DIR"
}

# Función principal
main() {
    log "${GREEN}========================================${NC}"
    log "${GREEN}Iniciando proceso de backup${NC}"
    log "${GREEN}========================================${NC}"
    
    check_pg_dump
    
    # Verificar conexión (opcional, no bloquea si falla)
    check_db_connection || log "${YELLOW}⚠ Continuando sin verificación de conexión${NC}"
    
    if create_backup; then
        cleanup_old_backups
        show_stats
        log "${GREEN}========================================${NC}"
        log "${GREEN}Proceso de backup completado exitosamente${NC}"
        log "${GREEN}========================================${NC}"
        exit 0
    else
        log "${RED}========================================${NC}"
        log "${RED}El proceso de backup falló${NC}"
        log "${RED}========================================${NC}"
        exit 1
    fi
}

# Ejecutar función principal
main

