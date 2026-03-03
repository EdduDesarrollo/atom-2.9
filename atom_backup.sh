#!/bin/bash

# Definir PATH completo para cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# CONFIG----------------------------------------------------------------------------
DATE=$(date '+%d_%m_%Y')
DATE_DELETE=$(date -d "2 weeks ago" +%d_%m_%Y)

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

# Configuración SMB
SMB_SERVER="//wdmycloudex4100.local/agu/Backup_atom"
SMB_USER="admin"
SMB_PASS="2025eddie"
SMB_MOUNT_POINT="/tmp/smb_backup_mount"
# -----------------------------------------------------------------------------------

# Crea la carpeta atom_backups si no existe
mkdir -p $FOLDER_BACKUP/$FOLDER_NAME

# Definir el archivo de log en la carpeta del backup actual
LOG_FILE="$FOLDER_BACKUP/$FOLDER_NAME/backup.log"


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

MYSQL_CNF="/etc/mysql/my.cnf"
MYSQL_CNF_BACKUP="/tmp/my.cnf.backup.$$"

# Función para comentar la línea sql-mode en my.cnf
comment_sql_mode() {
    if [ -f "$MYSQL_CNF" ]; then
        # Verificar permisos
        if [ ! -w "$MYSQL_CNF" ]; then
            log_message "ERROR: No se tienen permisos de escritura en $MYSQL_CNF"
            log_message "El script debe ejecutarse con permisos de root"
            exit 1
        fi
        
        # Crear backup del archivo original
        cp "$MYSQL_CNF" "$MYSQL_CNF_BACKUP"
        if [ $? -ne 0 ]; then
            log_message "ERROR: No se pudo crear backup de $MYSQL_CNF"
            exit 1
        fi
        log_message "Backup de $MYSQL_CNF creado en $MYSQL_CNF_BACKUP"
        
        # Comentar la línea que contiene sql-mode="" (si no está ya comentada)
        sed -i '/^[[:space:]]*sql-mode=""/s/^/# /' "$MYSQL_CNF"
        if [ $? -ne 0 ]; then
            log_message "ERROR: No se pudo comentar la línea sql-mode en $MYSQL_CNF"
            # Restaurar backup
            cp "$MYSQL_CNF_BACKUP" "$MYSQL_CNF"
            exit 1
        fi
        log_message "Línea sql-mode comentada en $MYSQL_CNF"
    else
        log_message "Advertencia: $MYSQL_CNF no existe"
    fi
}

# Función para descomentar la línea sql-mode en my.cnf
uncomment_sql_mode() {
    if [ -f "$MYSQL_CNF_BACKUP" ]; then
        # Restaurar el archivo original desde el backup
        cp "$MYSQL_CNF_BACKUP" "$MYSQL_CNF"
        if [ $? -eq 0 ]; then
            rm -f "$MYSQL_CNF_BACKUP"
            log_message "Línea sql-mode descomentada (archivo restaurado)"
        else
            log_message "ERROR: No se pudo restaurar $MYSQL_CNF desde el backup"
            log_message "Puedes restaurarlo manualmente desde: $MYSQL_CNF_BACKUP"
        fi
    elif [ -f "$MYSQL_CNF" ]; then
        # Si no hay backup, intentar descomentar manualmente
        sed -i '/^[[:space:]]*#.*sql-mode=""/s/^[[:space:]]*# //' "$MYSQL_CNF"
        if [ $? -eq 0 ]; then
            log_message "Línea sql-mode descomentada en $MYSQL_CNF"
        fi
    fi
}

# Funciones SMB ------------------------------------------------------------------------
check_and_install_cifs_utils() {
    log_message "Verificando si cifs-utils está instalado..."
    
    if command -v mount.cifs >/dev/null 2>&1; then
        log_message "cifs-utils ya está instalado"
        return 0
    fi
    
    log_message "cifs-utils no está instalado. Instalando..."
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y cifs-utils >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_message "cifs-utils instalado correctamente"
        return 0
    else
        log_message "ERROR: No se pudo instalar cifs-utils"
        return 1
    fi
}

mount_smb_share() {
    log_message "Montando recurso compartido SMB..."
    
    # Crear punto de montaje si no existe
    mkdir -p "$SMB_MOUNT_POINT"
    
    # Montar el recurso compartido SMB
    mount -t cifs "$SMB_SERVER" "$SMB_MOUNT_POINT" -o username="$SMB_USER",password="$SMB_PASS",uid=$(id -u),gid=$(id -g)
    
    if [ $? -ne 0 ]; then
        log_message "ERROR: No se pudo montar el recurso compartido SMB"
        return 1
    fi
    
    log_message "Recurso compartido SMB montado correctamente"
    return 0
}

unmount_smb_share() {
    if mountpoint -q "$SMB_MOUNT_POINT" 2>/dev/null; then
        log_message "Desmontando recurso compartido SMB..."
        umount "$SMB_MOUNT_POINT"
        if [ $? -eq 0 ]; then
            rmdir "$SMB_MOUNT_POINT" 2>/dev/null
            log_message "Recurso compartido SMB desmontado correctamente"
        else
            log_message "Advertencia: No se pudo desmontar el recurso compartido SMB"
        fi
    fi
}

copy_backup_to_smb() {
    log_message "Copiando backup a recurso compartido SMB..."
    
    if [ ! -d "$SMB_MOUNT_POINT" ]; then
        log_message "ERROR: El punto de montaje SMB no existe"
        return 1
    fi
    
    # Copiar la carpeta completa del backup
    cp -r "$FOLDER_BACKUP/$FOLDER_NAME" "$SMB_MOUNT_POINT/"
    
    if [ $? -ne 0 ]; then
        log_message "ERROR: No se pudo copiar el backup al recurso compartido SMB"
        return 1
    fi
    
    log_message "Backup copiado correctamente al recurso compartido SMB"
    return 0
}

cleanup_old_backups_smb() {
    log_message "Buscando backup de hace 2 semanas en SMB para eliminar..."
    
    if [ ! -d "$SMB_MOUNT_POINT" ]; then
        log_message "Advertencia: El punto de montaje SMB no existe, no se puede limpiar"
        return 1
    fi
    
    if [ -d "$SMB_MOUNT_POINT/$FOLDER_DELETE" ]; then
        rm -rf "$SMB_MOUNT_POINT/$FOLDER_DELETE"
        if [ $? -eq 0 ]; then
            log_message "Carpeta $FOLDER_DELETE eliminada del recurso compartido SMB"
        else
            log_message "Advertencia: No se pudo eliminar $FOLDER_DELETE del recurso compartido SMB"
        fi
    else
        log_message "No hay backup de hace 2 semanas en SMB para eliminar."
    fi
}

# Función de limpieza que se ejecuta al salir (incluso por error)
cleanup() {
    uncomment_sql_mode
    unmount_smb_share
}

# Registrar la función de limpieza para que se ejecute al salir
trap cleanup EXIT

cd /usr/share/nginx/atom || exit 1

# Comentar sql-mode en my.cnf antes del backup
comment_sql_mode

# Crea el backup de la base de datos
log_message "Creando backup de la base de datos..."
/usr/bin/mysqldump -u $USER -p"$PASS" "$DATABASE_NAME" > "$FOLDER_BACKUP/$FOLDER_NAME/$SQLDUMP_NAME"
check_error "Backup de la base de datos"

# Comprimir carpetas en partes
compress_folder_parts() {
    local FOLDER_PATH=$1
    local ARCHIVE_NAME=$2
    log_message "Comprimiendo $FOLDER_PATH..."
    
    /bin/tar -cf - -C "$(dirname "$FOLDER_PATH")" "$(basename "$FOLDER_PATH")" | /usr/bin/split -b 3800M - "$FOLDER_BACKUP/$FOLDER_NAME/$ARCHIVE_NAME.part"
    check_error "Compresión de $FOLDER_PATH"
}

# Comprimir carpetas
compress_folder() {
    local FOLDER_PATH=$1
    local ARCHIVE_NAME=$2
    log_message "Comprimiendo $FOLDER_PATH..."
    
    /bin/tar -czf "$FOLDER_BACKUP/$FOLDER_NAME/$ARCHIVE_NAME" -C "$(dirname "$FOLDER_PATH")" "$(basename "$FOLDER_PATH")"
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

log_message "SUCCESS: Backup local realizado con éxito"

# Copiar backup a recurso compartido SMB
log_message "Iniciando copia del backup al recurso compartido SMB..."
if check_and_install_cifs_utils && mount_smb_share; then
    copy_backup_to_smb
    if [ $? -eq 0 ]; then
        cleanup_old_backups_smb
    fi
    unmount_smb_share
    log_message "SUCCESS: Backup copiado al recurso compartido SMB con éxito"
else
    log_message "ERROR: No se pudo copiar el backup al recurso compartido SMB"
fi

log_message "SUCCESS: Proceso de backup completado"