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
    DB_USER=$(echo $DATABASE_URL | sed -n 's|.*://\([^:]*\):.*|\1|p')
    DB_HOST=$(echo $DATABASE_URL | sed -n 's|.*@\([^:]*\):.*|\1|p')
    DB_PORT=$(echo $DATABASE_URL | sed -n 's|.*:\([0-9]*\)/.*|\1|p')
    DB_NAME=$(echo $DATABASE_URL | sed -n 's|.*/\([^?]*\).*|\1|p')
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

# Función para crear backup
create_backup() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/backup_${DB_NAME}_${timestamp}.sql"
    local backup_file_compressed="${backup_file}.gz"
    
    log "${GREEN}Iniciando backup de la base de datos: $DB_NAME${NC}"
    
    # Crear backup
    if [ ! -z "$DATABASE_URL" ]; then
        # Usar DATABASE_URL directamente
        pg_dump "$DATABASE_URL" > "$backup_file" 2>> "$LOG_FILE"
    else
        # Usar variables individuales
        export PGPASSWORD="${DB_PASSWORD}"
        pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > "$backup_file" 2>> "$LOG_FILE"
    fi
    
    if [ $? -eq 0 ]; then
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
    else
        log "${RED}✗ ERROR: Fallo al crear el backup${NC}"
        rm -f "$backup_file"
        return 1
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

