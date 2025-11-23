#!/bin/bash

###############################################################################
# Script de Demostración de Restauración
# Este script demuestra cómo restaurar un backup de forma segura
###############################################################################

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$BACKEND_DIR/backups"
RESTORE_SCRIPT="$SCRIPT_DIR/restore-db.sh"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Demostración de Restauración de Backup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar que existen backups
if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR/*.sql.gz 2>/dev/null)" ]; then
    echo -e "${RED}No se encontraron backups para restaurar.${NC}"
    echo -e "${YELLOW}Primero crea un backup ejecutando:${NC}"
    echo "  ./scripts/backup-db.sh"
    exit 1
fi

echo -e "${GREEN}Backups disponibles:${NC}"
echo ""
ls -lh "$BACKUP_DIR"/*.sql.gz | awk '{print "  - " $9 " (" $5 ")"}'
echo ""

echo -e "${YELLOW}Para restaurar un backup, ejecuta:${NC}"
echo "  ./scripts/restore-db.sh"
echo ""
echo -e "${YELLOW}O especifica un archivo específico:${NC}"
echo "  ./scripts/restore-db.sh backup_[nombre_db]_[timestamp].sql.gz"
echo ""
echo -e "${BLUE}Nota: El script de restauración creará automáticamente${NC}"
echo -e "${BLUE}un backup de seguridad antes de restaurar.${NC}"
echo ""

