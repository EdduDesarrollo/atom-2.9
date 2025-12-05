#!/bin/bash

# CONFIG----------------------------------------------------------------------------
DATE=$(date '+%d_%m_%Y')
DATE_DELETE=$(date -d "2 weeks ago" +%d_%m_%Y)

# FOLDER_BACKUP="$HOME/Documentos/atom_backups"
FOLDER_BACKUP="/media/magna/datos2/atom_backups"

FOLDER_NAME="backup_$DATE"
FOLDER_DELETE="backup_$DATE_DELETE"

SQLDUMP_NAME="base_$DATE.sql"
UPLOADS_NAME="uploads_$DATE.tar.gz"
DOWNLOADS_NAME="downloads_$DATE.tar.gz"
IMAGES_NAME="images_$DATE.tar.gz"

USER="atom"
PASS="12345"
DATABASE_NAME="atom"
LOG_FILE="$FOLDER_BACKUP/backup.log"
# -----------------------------------------------------------------------------------

# Crea la carpeta atom_backups si no existe
mkdir -p $FOLDER_BACKUP/$FOLDER_NAME


# Utils -------------------------------------------------------------------------------
log_message() {
    echo "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_error() {
    if [ $? -ne 0 ]; then
        log_message "Error en $1."
        exit 1
    else
        log_message "Ok: $1"
    fi
}

cd /usr/share/nginx/atom || exit 1

# Crea el backup de la base de datos
log_message "Creando buckup de la base de datos..."
mysqldump -u $USER -p"$PASS" "$DATABASE_NAME" > "$FOLDER_BACKUP/$FOLDER_NAME/$SQLDUMP_NAME"
check_error "Backup de la base de datos"

# Comprimir carpetas
compress_folder_parts() {
    local FOLDER_PATH=$1
    local ARCHIVE_NAME=$2
    log_message "Comprimiendo $FOLDER_PATH..."
    
    tar -cf - -C "$(dirname "$FOLDER_PATH")" "$(basename "$FOLDER_PATH")" | split -b 3800M - "$FOLDER_BACKUP/$FOLDER_NAME/$ARCHIVE_NAME.part"


    #tar -czf "$FOLDER_BACKUP/$FOLDER_NAME/$ARCHIVE_NAME" -C "$(dirname "$FOLDER_PATH")" "$(basename "$FOLDER_PATH")"
    check_error "Compresión de $FOLDER_PATH"
}

# Comprimir carpetas
compress_folder() {
    local FOLDER_PATH=$1
    local ARCHIVE_NAME=$2
    log_message "Comprimiendo $FOLDER_PATH..."
    
    #tar -cf - -C "$(dirname "$FOLDER_PATH")" "$(basename "$FOLDER_PATH")" | split -b 3500M - "$FOLDER_BACKUP/$FOLDER_NAME/$ARCHIVE_NAME.part"


    tar -czf "$FOLDER_BACKUP/$FOLDER_NAME/$ARCHIVE_NAME" -C "$(dirname "$FOLDER_PATH")" "$(basename "$FOLDER_PATH")"
    check_error "Compresión de $FOLDER_PATH"
}

compress_folder_parts "/usr/share/nginx/atom/uploads" "$UPLOADS_NAME"
compress_folder "/usr/share/nginx/atom/downloads" "$DOWNLOADS_NAME"
compress_folder "/usr/share/nginx/atom/images" "$IMAGES_NAME"

# Eliminar backup antiguo
log_message "Buscando backup de hace 2 semanas para eliminar..."
if [ -d "$FOLDER_BACKUP/$FOLDER_DELETE" ]; then
    rm -rf "$FOLDER_BACKUP/$FOLDER_DELETE"
    log_message "Carpeta $FOLDER_DELETE eliminada"
else
    log_message "No hay backup de hace 2 semanas para eliminar."
fi

log_message "SUCCESS: Backup realizado con éxito"
