#!/bin/bash

###############################################################################
# Script de Restauración para PostgreSQL
# Este script restaura un backup de la base de datos
###############################################################################

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$BACKEND_DIR/backups"
LOG_DIR="$BACKEND_DIR/logs"
LOG_FILE="$LOG_DIR/restore.log"

# Cargar variables de entorno desde .env si existe
if [ -f "$BACKEND_DIR/.env" ]; then
    export $(cat "$BACKEND_DIR/.env" | grep -v '^#' | xargs)
fi

# Variables de base de datos
DB_NAME="${DB_NAME:-${DATABASE_URL##*/}}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

# Si DATABASE_URL está definida, extraer información
if [ ! -z "$DATABASE_URL" ]; then
    DB_USER=$(echo $DATABASE_URL | sed -n 's|.*://\([^:]*\):.*|\1|p')
    DB_HOST=$(echo $DATABASE_URL | sed -n 's|.*@\([^:]*\):.*|\1|p')
    DB_PORT=$(echo $DATABASE_URL | sed -n 's|.*:\([0-9]*\)/.*|\1|p')
    DB_NAME=$(echo $DATABASE_URL | sed -n 's|.*/\([^?]*\).*|\1|p')
fi

# Crear directorios si no existen
mkdir -p "$LOG_DIR"

# Función de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Función para listar backups disponibles
list_backups() {
    echo -e "${BLUE}Backups disponibles:${NC}"
    echo ""
    local backups=($(find "$BACKUP_DIR" -name "backup_*.sql.gz" -type f | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}No se encontraron backups en $BACKUP_DIR${NC}"
        return 1
    fi
    
    local index=1
    for backup in "${backups[@]}"; do
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo -e "  ${GREEN}[$index]${NC} $filename"
        echo -e "      Tamaño: $size | Fecha: $date"
        ((index++))
    done
    echo ""
    return 0
}

# Función para seleccionar backup interactivamente
select_backup() {
    local backups=($(find "$BACKUP_DIR" -name "backup_*.sql.gz" -type f | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        log "${RED}No se encontraron backups${NC}"
        return 1
    fi
    
    list_backups
    
    read -p "Selecciona el número del backup a restaurar (1-${#backups[@]}): " selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#backups[@]} ]; then
        log "${RED}Selección inválida${NC}"
        return 1
    fi
    
    echo "${backups[$((selection-1))]}"
}

# Función para verificar si psql está instalado
check_psql() {
    if ! command -v psql &> /dev/null; then
        log "${RED}ERROR: psql no está instalado. Instálalo con: sudo apt-get install postgresql-client${NC}"
        exit 1
    fi
}

# Función para crear backup antes de restaurar
create_safety_backup() {
    log "${YELLOW}Creando backup de seguridad antes de restaurar...${NC}"
    "$SCRIPT_DIR/backup-db.sh" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log "${GREEN}✓ Backup de seguridad creado${NC}"
        return 0
    else
        log "${YELLOW}⚠ Advertencia: No se pudo crear el backup de seguridad${NC}"
        return 1
    fi
}

# Función para restaurar backup
restore_backup() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        log "${RED}ERROR: El archivo de backup no existe: $backup_file${NC}"
        return 1
    fi
    
    log "${GREEN}========================================${NC}"
    log "${GREEN}Iniciando restauración${NC}"
    log "${GREEN}========================================${NC}"
    log "Backup: $(basename "$backup_file")"
    log "Base de datos: $DB_NAME"
    log "Host: $DB_HOST"
    log ""
    
    # Confirmación
    echo -e "${RED}⚠ ADVERTENCIA: Esta operación sobrescribirá la base de datos actual${NC}"
    read -p "¿Estás seguro de que deseas continuar? (escribe 'SI' para confirmar): " confirmation
    
    if [ "$confirmation" != "SI" ]; then
        log "${YELLOW}Restauración cancelada por el usuario${NC}"
        return 1
    fi
    
    # Descomprimir backup si está comprimido
    local temp_file="${backup_file%.gz}"
    if [[ "$backup_file" == *.gz ]]; then
        log "${YELLOW}Descomprimiendo backup...${NC}"
        gunzip -c "$backup_file" > "$temp_file" 2>> "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "${RED}ERROR: Fallo al descomprimir el backup${NC}"
            return 1
        fi
    else
        temp_file="$backup_file"
    fi
    
    # Verificar integridad del archivo SQL
    if ! head -n 1 "$temp_file" | grep -q "PostgreSQL database dump"; then
        log "${YELLOW}⚠ Advertencia: El archivo no parece ser un dump de PostgreSQL válido${NC}"
    fi
    
    # Restaurar
    log "${YELLOW}Restaurando base de datos...${NC}"
    
    if [ ! -z "$DATABASE_URL" ]; then
        # Usar DATABASE_URL directamente
        psql "$DATABASE_URL" < "$temp_file" >> "$LOG_FILE" 2>&1
    else
        # Usar variables individuales
        export PGPASSWORD="${DB_PASSWORD}"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" < "$temp_file" >> "$LOG_FILE" 2>&1
    fi
    
    local restore_status=$?
    
    # Limpiar archivo temporal si fue descomprimido
    if [[ "$backup_file" == *.gz ]] && [ -f "$temp_file" ]; then
        rm -f "$temp_file"
    fi
    
    if [ $restore_status -eq 0 ]; then
        log "${GREEN}========================================${NC}"
        log "${GREEN}✓ Restauración completada exitosamente${NC}"
        log "${GREEN}========================================${NC}"
        return 0
    else
        log "${RED}========================================${NC}"
        log "${RED}✗ ERROR: La restauración falló${NC}"
        log "${RED}Revisa el log en $LOG_FILE para más detalles${NC}"
        log "${RED}========================================${NC}"
        return 1
    fi
}

# Función principal
main() {
    check_psql
    
    local backup_file=""
    
    # Si se proporciona un archivo como argumento, usarlo
    if [ $# -eq 1 ]; then
        backup_file="$1"
        if [[ "$backup_file" != /* ]]; then
            # Si es una ruta relativa, buscar en BACKUP_DIR
            backup_file="$BACKUP_DIR/$backup_file"
        fi
    else
        # Modo interactivo
        backup_file=$(select_backup)
        if [ $? -ne 0 ] || [ -z "$backup_file" ]; then
            exit 1
        fi
    fi
    
    # Crear backup de seguridad
    create_safety_backup
    
    # Restaurar
    if restore_backup "$backup_file"; then
        exit 0
    else
        exit 1
    fi
}

# Ejecutar función principal
main "$@"

