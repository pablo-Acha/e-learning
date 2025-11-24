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
    # Escribir a stderr para que no interfiera con la captura de stdout
    echo -e "${BLUE}Backups disponibles:${NC}" >&2
    echo "" >&2
    local backups=($(find "$BACKUP_DIR" -name "backup_*.sql.gz" -type f | sort -r))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}No se encontraron backups en $BACKUP_DIR${NC}" >&2
        return 1
    fi
    
    local index=1
    for backup in "${backups[@]}"; do
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo -e "  ${GREEN}[$index]${NC} $filename" >&2
        echo -e "      Tamaño: $size | Fecha: $date" >&2
        ((index++))
    done
    echo "" >&2
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
    
    # El prompt debe ir a stderr para que no interfiera con stdout
    echo -n "Selecciona el número del backup a restaurar (1-${#backups[@]}): " >&2
    read selection
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#backups[@]} ]; then
        log "${RED}Selección inválida${NC}"
        return 1
    fi
    
    # Devolver solo el path del archivo seleccionado
    local selected_backup="${backups[$((selection-1))]}"
    echo "$selected_backup"
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
    echo -e "${YELLOW}Se eliminarán todos los datos y esquemas existentes antes de restaurar${NC}"
    read -p "¿Estás seguro de que deseas continuar? (escribe 'SI' para confirmar): " confirmation
    
    if [ "$confirmation" != "SI" ]; then
        log "${YELLOW}Restauración cancelada por el usuario${NC}"
        return 1
    fi
    
    # Limpiar la base de datos antes de restaurar
    log "${YELLOW}Limpiando base de datos existente (eliminando TODOS los datos)...${NC}"
    
    local cleanup_status=0
    local cleanup_output="${LOG_DIR}/cleanup_$(date +%s).log"
    
    if [ ! -z "$DATABASE_URL" ]; then
        # Eliminar TODOS los objetos del esquema public (incluyendo datos)
        # Primero desconectar todas las conexiones activas
        psql "$DATABASE_URL" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();" > "$cleanup_output" 2>&1
        
        # Eliminar el esquema completo (esto elimina TODAS las tablas y datos)
        psql "$DATABASE_URL" -c "DROP SCHEMA IF EXISTS public CASCADE;" >> "$cleanup_output" 2>&1
        
        # Recrear el esquema limpio
        psql "$DATABASE_URL" -c "CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO postgres; GRANT ALL ON SCHEMA public TO public;" >> "$cleanup_output" 2>&1
        cleanup_status=$?
    else
        export PGPASSWORD="${DB_PASSWORD}"
        # Desconectar conexiones activas
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();" > "$cleanup_output" 2>&1
        
        # Eliminar el esquema completo
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "DROP SCHEMA IF EXISTS public CASCADE;" >> "$cleanup_output" 2>&1
        
        # Recrear el esquema limpio
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO postgres; GRANT ALL ON SCHEMA public TO public;" >> "$cleanup_output" 2>&1
        cleanup_status=$?
        unset PGPASSWORD
    fi
    
    # Verificar que la limpieza fue exitosa
    if [ $cleanup_status -eq 0 ]; then
        # Verificar que no hay tablas
        local table_count=0
        if [ ! -z "$DATABASE_URL" ]; then
            table_count=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
        else
            export PGPASSWORD="${DB_PASSWORD}"
            table_count=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
            unset PGPASSWORD
        fi
        
        if [ "$table_count" = "0" ]; then
            log "${GREEN}✓ Base de datos limpiada correctamente (0 tablas encontradas)${NC}"
        else
            log "${YELLOW}⚠ Advertencia: Aún existen $table_count tablas después de la limpieza${NC}"
        fi
    else
        log "${YELLOW}⚠ Advertencia: No se pudo limpiar completamente la base de datos${NC}"
        log "${YELLOW}Revisa el log: $cleanup_output${NC}"
        log "${YELLOW}Continuando con la restauración (pueden aparecer errores de objetos duplicados)${NC}"
    fi
    
    # Limpiar archivo de log de limpieza
    rm -f "$cleanup_output"
    
    # Descomprimir backup si está comprimido
    local temp_file="${LOG_DIR}/restore_temp_$(date +%s).sql"
    if [[ "$backup_file" == *.gz ]]; then
        log "${YELLOW}Descomprimiendo backup...${NC}"
        gunzip -c "$backup_file" > "$temp_file" 2>> "$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "${RED}ERROR: Fallo al descomprimir el backup${NC}"
            rm -f "$temp_file"
            return 1
        fi
    else
        cp "$backup_file" "$temp_file"
    fi
    
    # Verificar que el archivo temporal existe y no está vacío
    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        log "${RED}ERROR: El archivo SQL está vacío o no se pudo crear${NC}"
        rm -f "$temp_file"
        return 1
    fi
    
    # Verificar integridad del archivo SQL (mejorar validación)
    local first_lines=$(head -n 10 "$temp_file" | tr '\n' ' ')
    local is_valid_dump=false
    
    # Verificar múltiples patrones que indican un dump válido
    if echo "$first_lines" | grep -qiE "PostgreSQL database dump"; then
        is_valid_dump=true
        log "${GREEN}✓ Backup identificado como dump de PostgreSQL${NC}"
    elif echo "$first_lines" | grep -qiE "(pg_dump|Dumped from database)"; then
        is_valid_dump=true
        log "${GREEN}✓ Backup identificado como dump de PostgreSQL${NC}"
    elif echo "$first_lines" | grep -qiE "(CREATE|SET statement_timeout|SET lock_timeout)"; then
        is_valid_dump=true
        log "${GREEN}✓ Backup contiene comandos SQL de PostgreSQL${NC}"
    fi
    
    if [ "$is_valid_dump" = false ] && [ $(wc -l < "$temp_file") -lt 20 ]; then
        log "${YELLOW}⚠ Advertencia: El archivo puede no ser un dump de PostgreSQL válido${NC}"
        log "${YELLOW}Primeras líneas del archivo:${NC}"
        head -n 5 "$temp_file" | while IFS= read -r line; do
            log "${YELLOW}  $line${NC}"
        done
    fi
    
    # Verificar tamaño del archivo
    local file_size=$(wc -c < "$temp_file")
    if [ $file_size -lt 100 ]; then
        log "${RED}ERROR: El archivo SQL es demasiado pequeño (${file_size} bytes). Puede estar corrupto.${NC}"
        rm -f "$temp_file"
        return 1
    fi
    
    # Formatear tamaño del archivo
    local size_display="${file_size} bytes"
    if [ $file_size -gt 1048576 ]; then
        size_display=$(awk "BEGIN {printf \"%.2f MB\", $file_size/1048576}")
    elif [ $file_size -gt 1024 ]; then
        size_display=$(awk "BEGIN {printf \"%.2f KB\", $file_size/1024}")
    fi
    log "${GREEN}Archivo SQL válido. Tamaño: $size_display${NC}"
    
    # Restaurar
    log "${YELLOW}Restaurando base de datos...${NC}"
    
    local error_file="${LOG_DIR}/restore_error_$(date +%s).log"
    local restore_status=0
    
    if [ ! -z "$DATABASE_URL" ]; then
        # Usar DATABASE_URL directamente
        psql "$DATABASE_URL" < "$temp_file" > "$error_file" 2>&1
        restore_status=$?
    else
        # Usar variables individuales
        export PGPASSWORD="${DB_PASSWORD}"
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" < "$temp_file" > "$error_file" 2>&1
        restore_status=$?
        unset PGPASSWORD
    fi
    
    # Mostrar errores si existen
    if [ -f "$error_file" ] && [ -s "$error_file" ]; then
        local error_content=$(cat "$error_file")
        # Filtrar mensajes informativos comunes y errores esperados después de limpiar
        local actual_errors=$(echo "$error_content" | grep -vE "^(SET|CREATE|ALTER|COMMENT|--|$)" | grep -iE "(error|fatal|failed|invalid)" | grep -vE "(already exists|duplicate key|multiple primary keys)")
        
        if [ ! -z "$actual_errors" ]; then
            log "${RED}Errores durante la restauración:${NC}"
            echo "$actual_errors" | while IFS= read -r line; do
                log "${RED}  $line${NC}"
            done
        else
            # Si solo hay errores de "already exists", son esperados y no críticos
            local duplicate_errors=$(echo "$error_content" | grep -iE "(already exists|duplicate key|multiple primary keys)")
            if [ ! -z "$duplicate_errors" ]; then
                local error_count=$(echo "$duplicate_errors" | wc -l)
                log "${YELLOW}⚠ Se encontraron $error_count advertencias sobre objetos duplicados (esto es normal si la base de datos no se limpió completamente)${NC}"
            fi
        fi
    fi
    
    # Limpiar archivo temporal
    rm -f "$temp_file" "$error_file"
    
    if [ $restore_status -eq 0 ]; then
        log "${GREEN}========================================${NC}"
        log "${GREEN}✓ Restauración completada exitosamente${NC}"
        log "${GREEN}========================================${NC}"
        
        # Verificar que la base de datos tiene contenido
        log "${YELLOW}Verificando restauración...${NC}"
        local verify_query="SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'public';"
        local table_count=0
        
        if [ ! -z "$DATABASE_URL" ]; then
            table_count=$(psql "$DATABASE_URL" -t -c "$verify_query" 2>/dev/null | tr -d ' ')
        else
            export PGPASSWORD="${DB_PASSWORD}"
            table_count=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "$verify_query" 2>/dev/null | tr -d ' ')
            unset PGPASSWORD
        fi
        
        if [ ! -z "$table_count" ] && [ "$table_count" -gt 0 ]; then
            log "${GREEN}✓ Base de datos restaurada. Tablas encontradas: $table_count${NC}"
            
            # Verificar que hay datos en las tablas
            log "${YELLOW}Verificando datos restaurados...${NC}"
            local data_check_query="SELECT 
                (SELECT COUNT(*) FROM \"User\" WHERE table_schema = 'public') as users,
                (SELECT COUNT(*) FROM \"Class\" WHERE table_schema = 'public') as classes,
                (SELECT COUNT(*) FROM \"Enrollment\" WHERE table_schema = 'public') as enrollments;"
            
            # Intentar contar registros en tablas principales
            local user_count=0
            if [ ! -z "$DATABASE_URL" ]; then
                user_count=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM \"User\";" 2>/dev/null | tr -d ' ' || echo "0")
            else
                export PGPASSWORD="${DB_PASSWORD}"
                user_count=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM \"User\";" 2>/dev/null | tr -d ' ' || echo "0")
                unset PGPASSWORD
            fi
            
            if [ ! -z "$user_count" ] && [ "$user_count" != "0" ]; then
                log "${GREEN}✓ Datos restaurados. Registros en tabla User: $user_count${NC}"
            else
                log "${YELLOW}⚠ Advertencia: La tabla User está vacía. El backup puede no contener datos.${NC}"
                log "${YELLOW}Verifica que el backup fue creado con datos usando: gunzip -c backup_file.sql.gz | grep -i INSERT${NC}"
            fi
        else
            log "${YELLOW}⚠ Advertencia: No se pudieron verificar las tablas en la base de datos${NC}"
        fi
        
        return 0
    else
        log "${RED}========================================${NC}"
        log "${RED}✗ ERROR: La restauración falló (código de salida: $restore_status)${NC}"
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
        # Ejecutar select_backup y capturar solo stdout (el path), stderr va a la terminal
        backup_file=$(select_backup 2>/dev/tty)
        local select_exit_code=$?
        
        # Si select_backup falló, salir
        if [ $select_exit_code -ne 0 ] || [ -z "$backup_file" ]; then
            log "${RED}No se seleccionó ningún backup${NC}"
            exit 1
        fi
        
        # Limpiar el path del archivo (eliminar espacios y saltos de línea)
        backup_file=$(echo "$backup_file" | head -n 1 | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Verificar que el archivo existe
        if [ ! -f "$backup_file" ]; then
            log "${RED}ERROR: El archivo de backup no existe: $backup_file${NC}"
            log "${YELLOW}Archivo buscado: $backup_file${NC}"
            log "${YELLOW}Verifica que el path sea correcto${NC}"
            exit 1
        fi
        
        log "${GREEN}Backup seleccionado: $(basename "$backup_file")${NC}"
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

