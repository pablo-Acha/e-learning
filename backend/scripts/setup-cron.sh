#!/bin/bash

###############################################################################
# Script de Configuración de Cron Job para Backups Automáticos
# Este script configura un cron job para ejecutar backups automáticamente
###############################################################################

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-db.sh"
CRON_JOB_NAME="postgresql-backup"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Configuración de Cron Job para Backups${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar que el script de backup existe
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo -e "${RED}ERROR: No se encontró el script de backup en: $BACKUP_SCRIPT${NC}"
    exit 1
fi

# Hacer el script ejecutable
chmod +x "$BACKUP_SCRIPT"
echo -e "${GREEN}✓ Script de backup hecho ejecutable${NC}"

# Obtener la ruta absoluta del script
BACKUP_SCRIPT_ABS=$(readlink -f "$BACKUP_SCRIPT" 2>/dev/null || realpath "$BACKUP_SCRIPT")

# Función para mostrar opciones de frecuencia
show_frequency_options() {
    echo -e "${YELLOW}Opciones de frecuencia:${NC}"
    echo "  1) Diario a las 2:00 AM"
    echo "  2) Diario a las 3:00 AM"
    echo "  3) Cada 12 horas (2:00 AM y 2:00 PM)"
    echo "  4) Cada 6 horas"
    echo "  5) Personalizado (ingresar expresión cron manualmente)"
    echo ""
}

# Función para obtener expresión cron según opción
get_cron_expression() {
    local option=$1
    case $option in
        1)
            echo "0 2 * * *"
            ;;
        2)
            echo "0 3 * * *"
            ;;
        3)
            echo "0 2,14 * * *"
            ;;
        4)
            echo "0 */6 * * *"
            ;;
        5)
            read -p "Ingresa la expresión cron (ej: '0 2 * * *' para diario a las 2 AM): " custom_cron
            echo "$custom_cron"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Verificar si ya existe un cron job
existing_cron=$(crontab -l 2>/dev/null | grep "$CRON_JOB_NAME")

if [ ! -z "$existing_cron" ]; then
    echo -e "${YELLOW}Ya existe un cron job configurado:${NC}"
    echo "  $existing_cron"
    echo ""
    read -p "¿Deseas reemplazarlo? (s/n): " replace
    if [ "$replace" != "s" ] && [ "$replace" != "S" ]; then
        echo -e "${YELLOW}Operación cancelada${NC}"
        exit 0
    fi
    # Eliminar el cron job existente
    crontab -l 2>/dev/null | grep -v "$CRON_JOB_NAME" | crontab -
    echo -e "${GREEN}✓ Cron job anterior eliminado${NC}"
fi

# Seleccionar frecuencia
show_frequency_options
read -p "Selecciona una opción (1-5): " frequency_option

cron_expression=$(get_cron_expression "$frequency_option")

if [ -z "$cron_expression" ]; then
    echo -e "${RED}Opción inválida${NC}"
    exit 1
fi

# Crear la línea del cron job
# Agregar variables de entorno y redirección de logs
cron_line="$cron_expression PATH=/usr/local/bin:/usr/bin:/bin && cd $BACKEND_DIR && $BACKUP_SCRIPT_ABS >> $BACKEND_DIR/logs/cron.log 2>&1 # $CRON_JOB_NAME"

# Agregar al crontab
(crontab -l 2>/dev/null; echo "$cron_line") | crontab -

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Cron job configurado exitosamente${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Configuración:${NC}"
    echo "  Frecuencia: $cron_expression"
    echo "  Script: $BACKUP_SCRIPT_ABS"
    echo "  Log: $BACKEND_DIR/logs/cron.log"
    echo ""
    echo -e "${YELLOW}Para ver el cron job configurado:${NC}"
    echo "  crontab -l"
    echo ""
    echo -e "${YELLOW}Para eliminar el cron job:${NC}"
    echo "  crontab -l | grep -v '$CRON_JOB_NAME' | crontab -"
    echo ""
    echo -e "${YELLOW}Para probar el backup manualmente:${NC}"
    echo "  $BACKUP_SCRIPT_ABS"
    echo ""
else
    echo -e "${RED}ERROR: Fallo al configurar el cron job${NC}"
    exit 1
fi

