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
SMB_HOST="164.73.14.59"
SMB_SERVER="//${SMB_HOST}/12TB/agu/Backup_atom"
SMB_USER="lapa"
SMB_PASS="lapa2018"
SMB_MOUNT_POINT="/tmp/smb_backup_mount"
SMB_MOUNT_ATTEMPTS=5
SMB_MOUNT_RETRY_SLEEP=60
FAIL_MARKER="/var/log/atom_backup.FAILED"

# Mail (mismos destinatarios que backup_raid; comas SIN espacios)
# DESTINATARIOS="eddudesarrollo@gmail.com,mariano+agu@reperger.com,nacho.seimanas@gmail.com"
DESTINATARIOS="mariano+agu@reperger.com"
MUTT_BIN="/usr/bin/mutt"
MAIL_ATTACH_MAX_BYTES=$((5 * 1024 * 1024))
MAIL_FROM='AtoM <eddudesarrollo@gmail.com>'
MAIL_REALNAME="AtoM"
# -----------------------------------------------------------------------------------

START_EPOCH=$(date +%s)
START_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %z')
HOST_NAME=$(hostname 2>/dev/null || echo unknown)
LOCAL_OK=0
SMB_OK=0
MAIL_SENT=0
FINAL_RC=1

# Crea la carpeta atom_backups si no existe
mkdir -p "$FOLDER_BACKUP/$FOLDER_NAME"

# Definir el archivo de log en la carpeta del backup actual
LOG_FILE="$FOLDER_BACKUP/$FOLDER_NAME/backup.log"
: >"$LOG_FILE"


# Utils -------------------------------------------------------------------------------
log_message() {
    echo "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

mark_backup_failed() {
    local reason="$1"
    echo "$(date -Iseconds) $reason" > "$FAIL_MARKER"
    logger -t atom_backup "FAIL: $reason"
}

mark_backup_ok() {
    rm -f "$FAIL_MARKER"
    logger -t atom_backup "OK: backup local y réplica SMB completados"
}

check_error() {
    if [ $? -ne 0 ]; then
        log_message "Error en $1."
        mark_backup_failed "Error en $1"
        exit 1
    else
        log_message "Ok: $1"
    fi
}

send_mail() {
    local subject="$1"
    local body_file="$2"
    local attach="$3"
    local rc_mutt=0

    if [ -n "$attach" ] && [ -f "$attach" ]; then
        "$MUTT_BIN" \
            -e "set realname=\"${MAIL_REALNAME}\"" \
            -e "set from=\"${MAIL_FROM}\"" \
            -s "$subject" -a "$attach" -- $DESTINATARIOS <"$body_file"
        rc_mutt=$?
    else
        "$MUTT_BIN" \
            -e "set realname=\"${MAIL_REALNAME}\"" \
            -e "set from=\"${MAIL_FROM}\"" \
            -s "$subject" -- $DESTINATARIOS <"$body_file"
        rc_mutt=$?
    fi
    log_message "mutt exit=${rc_mutt} subject=${subject}"
    return 0
}

prepare_attachment() {
    ATTACH_PATH="$LOG_FILE"
    ATTACH_NOTE=""
    local size
    size=$(wc -c <"$LOG_FILE" 2>/dev/null || echo 0)
    size="${size//[[:space:]]/}"
    if [[ "$size" =~ ^[0-9]+$ ]] && [ "$size" -gt "$MAIL_ATTACH_MAX_BYTES" ]; then
        ATTACH_PATH=$(mktemp /tmp/atom_backup_mail_XXXXXX.log)
        {
            echo "=== LOG TRUNCADO PARA MAIL (tail) — completo en: ${LOG_FILE} ==="
            echo
            tail -c "$MAIL_ATTACH_MAX_BYTES" "$LOG_FILE"
        } >"$ATTACH_PATH"
        ATTACH_NOTE="Adjunto truncado (log >5MB). Completo en disco: ${LOG_FILE}"
    fi
}

build_and_send_result_mail() {
    local end_human duration body attach_cleanup="" subject global_state
    local status_local status_smb

    if [ "$MAIL_SENT" -eq 1 ]; then
        return 0
    fi
    MAIL_SENT=1

    end_human=$(date '+%Y-%m-%d %H:%M:%S %z')
    duration=$(( $(date +%s) - START_EPOCH ))

    if [ "$LOCAL_OK" -eq 1 ]; then
        status_local="ok"
    else
        status_local="fail"
    fi
    if [ "$SMB_OK" -eq 1 ]; then
        status_smb="ok"
    elif [ "$LOCAL_OK" -eq 1 ]; then
        status_smb="fail"
    else
        status_smb="omitted"
    fi

    if [ "$LOCAL_OK" -ne 1 ]; then
        subject="RESPALDO FALLÓ - AtoM"
        global_state="FAIL"
    elif [ "$SMB_OK" -eq 1 ]; then
        subject="RESPALDO OK - AtoM"
        global_state="OK"
    else
        subject="RESPALDO PARCIAL - AtoM"
        global_state="PARCIAL"
    fi

    prepare_attachment
    [ "$ATTACH_PATH" != "$LOG_FILE" ] && attach_cleanup="$ATTACH_PATH"

    body=$(mktemp /tmp/atom_backup_body_XXXXXX.txt)
    {
        echo "Estado global: ${global_state}"
        echo "Host: ${HOST_NAME}"
        echo "Inicio: ${START_HUMAN}"
        echo "Fin: ${end_human}"
        echo "Duración (s): ${duration}"
        echo "Exit code script: ${FINAL_RC}"
        echo "Log: ${LOG_FILE}"
        [ -n "$ATTACH_NOTE" ] && echo "$ATTACH_NOTE"
        echo
        echo "======== Local ========"
        echo "Estado: ${status_local}"
        echo "Carpeta: ${FOLDER_BACKUP}/${FOLDER_NAME}"
        echo
        echo "======== SMB ========"
        echo "Estado: ${status_smb}"
        echo "Destino: ${SMB_SERVER}"
        echo
        if [ -f "$FAIL_MARKER" ]; then
            echo "FAIL_MARKER (${FAIL_MARKER}):"
            cat "$FAIL_MARKER"
            echo
        fi
        echo "Ver adjunto / log para detalle."
    } >"$body"

    send_mail "$subject" "$body" "$ATTACH_PATH" || true
    rm -f "$body"
    [ -n "$attach_cleanup" ] && rm -f "$attach_cleanup"
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
            mark_backup_failed "Sin permisos de escritura en $MYSQL_CNF"
            exit 1
        fi
        
        # Crear backup del archivo original
        cp "$MYSQL_CNF" "$MYSQL_CNF_BACKUP"
        if [ $? -ne 0 ]; then
            log_message "ERROR: No se pudo crear backup de $MYSQL_CNF"
            mark_backup_failed "No se pudo crear backup de $MYSQL_CNF"
            exit 1
        fi
        log_message "Backup de $MYSQL_CNF creado en $MYSQL_CNF_BACKUP"
        
        # Comentar la línea que contiene sql-mode="" (si no está ya comentada)
        sed -i '/^[[:space:]]*sql-mode=""/s/^/# /' "$MYSQL_CNF"
        if [ $? -ne 0 ]; then
            log_message "ERROR: No se pudo comentar la línea sql-mode en $MYSQL_CNF"
            # Restaurar backup
            cp "$MYSQL_CNF_BACKUP" "$MYSQL_CNF"
            mark_backup_failed "No se pudo comentar sql-mode en $MYSQL_CNF"
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
check_cifs_utils() {
    log_message "Verificando si cifs-utils está instalado..."

    if command -v mount.cifs >/dev/null 2>&1; then
        log_message "cifs-utils ya está instalado"
        return 0
    fi

    log_message "ERROR: cifs-utils no está instalado (mount.cifs no encontrado)"
    return 1
}

smb_host_reachable() {
    timeout 5 bash -c "echo >/dev/tcp/${SMB_HOST}/445" 2>/dev/null
}

mount_smb_share() {
    local attempt
    local mount_rc

    log_message "Montando recurso compartido SMB..."
    mkdir -p "$SMB_MOUNT_POINT"

    for attempt in $(seq 1 "$SMB_MOUNT_ATTEMPTS"); do
        if ! smb_host_reachable; then
            log_message "SMB ${SMB_HOST}:445 no responde (intento ${attempt}/${SMB_MOUNT_ATTEMPTS})"
            if [ "$attempt" -lt "$SMB_MOUNT_ATTEMPTS" ]; then
                sleep "$SMB_MOUNT_RETRY_SLEEP"
            fi
            continue
        fi

        log_message "Intentando mount CIFS (intento ${attempt}/${SMB_MOUNT_ATTEMPTS})..."
        mount -t cifs "$SMB_SERVER" "$SMB_MOUNT_POINT" \
            -o "username=${SMB_USER},password=${SMB_PASS},vers=3.0,uid=0,gid=0,file_mode=0644,dir_mode=0755,cache=strict" \
            2>>"$LOG_FILE"
        mount_rc=$?

        if [ "$mount_rc" -eq 0 ] && mountpoint -q "$SMB_MOUNT_POINT"; then
            log_message "Recurso compartido SMB montado correctamente (intento ${attempt})"
            return 0
        fi

        log_message "ERROR: Falló mount CIFS (intento ${attempt}/${SMB_MOUNT_ATTEMPTS}, rc=${mount_rc}); ver detalle arriba en este log"
        if mountpoint -q "$SMB_MOUNT_POINT" 2>/dev/null; then
            umount "$SMB_MOUNT_POINT" 2>>"$LOG_FILE" || true
        fi
        if [ "$attempt" -lt "$SMB_MOUNT_ATTEMPTS" ]; then
            sleep "$SMB_MOUNT_RETRY_SLEEP"
        fi
    done

    log_message "ERROR: No se pudo montar el recurso compartido SMB tras ${SMB_MOUNT_ATTEMPTS} intentos"
    return 1
}

unmount_smb_share() {
    if mountpoint -q "$SMB_MOUNT_POINT" 2>/dev/null; then
        log_message "Desmontando recurso compartido SMB..."
        sync
        if umount "$SMB_MOUNT_POINT" 2>>"$LOG_FILE"; then
            rmdir "$SMB_MOUNT_POINT" 2>/dev/null
            log_message "Recurso compartido SMB desmontado correctamente"
            return 0
        else
            log_message "ERROR: No se pudo desmontar el recurso compartido SMB"
            return 1
        fi
    fi
    return 0
}

smb_write_test() {
    local test_file="$SMB_MOUNT_POINT/.atom_backup_write_test.$$"

    log_message "Verificando escritura en el recurso compartido SMB..."
    if ! mountpoint -q "$SMB_MOUNT_POINT"; then
        log_message "ERROR: $SMB_MOUNT_POINT no es un punto de montaje"
        return 1
    fi

    if ! touch "$test_file" 2>>"$LOG_FILE"; then
        log_message "ERROR: No se pudo escribir en el recurso compartido SMB (write test)"
        return 1
    fi
    rm -f "$test_file" 2>>"$LOG_FILE"
    log_message "Write test SMB OK"
    return 0
}

copy_backup_to_smb() {
    log_message "Copiando backup a recurso compartido SMB..."

    if ! mountpoint -q "$SMB_MOUNT_POINT"; then
        log_message "ERROR: $SMB_MOUNT_POINT no es un punto de montaje CIFS"
        return 1
    fi

    cp -r "$FOLDER_BACKUP/$FOLDER_NAME" "$SMB_MOUNT_POINT/" 2>>"$LOG_FILE"
    if [ $? -ne 0 ]; then
        log_message "ERROR: No se pudo copiar el backup al recurso compartido SMB"
        return 1
    fi

    log_message "Backup copiado correctamente al recurso compartido SMB"
    return 0
}

verify_backup_on_smb() {
    local src="$FOLDER_BACKUP/$FOLDER_NAME"
    local dst="$SMB_MOUNT_POINT/$FOLDER_NAME"
    local rel path_src path_dst size_src size_dst
    local checked=0

    log_message "Verificando backup en recurso compartido SMB..."

    if ! mountpoint -q "$SMB_MOUNT_POINT"; then
        log_message "ERROR: $SMB_MOUNT_POINT no es un punto de montaje al verificar"
        return 1
    fi

    if [ ! -d "$dst" ]; then
        log_message "ERROR: No existe $FOLDER_NAME en el share tras la copia"
        return 1
    fi

    while IFS= read -r -d '' path_src; do
        rel="${path_src#"$src"/}"
        if [ "$rel" = "backup.log" ]; then
            continue
        fi
        path_dst="$dst/$rel"
        if [ ! -f "$path_dst" ]; then
            log_message "ERROR: Falta en SMB: $rel"
            return 1
        fi
        size_src=$(stat -c%s "$path_src")
        size_dst=$(stat -c%s "$path_dst")
        if [ "$size_src" != "$size_dst" ]; then
            log_message "ERROR: Tamaño distinto en $rel (local=$size_src remoto=$size_dst)"
            return 1
        fi
        checked=$((checked + 1))
    done < <(find "$src" -type f -print0)

    if [ "$checked" -eq 0 ]; then
        log_message "ERROR: No hay archivos para verificar en el backup local"
        return 1
    fi

    log_message "Verificación OK: $checked archivos coinciden en tamaño (excepto backup.log)"
    return 0
}

cleanup_old_backups_smb() {
    log_message "Buscando backup de hace 2 semanas en SMB para eliminar..."

    if ! mountpoint -q "$SMB_MOUNT_POINT"; then
        log_message "Advertencia: el punto de montaje SMB no está activo, no se puede limpiar"
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

# Limpieza + mail de resultado (un solo envío; mutt no pisa el exit del backup)
cleanup() {
    local rc=$?
    FINAL_RC=$rc
    uncomment_sql_mode
    unmount_smb_share || true
    build_and_send_result_mail || true
    exit "$rc"
}

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
LOCAL_OK=1

# Copiar backup a recurso compartido SMB
log_message "Iniciando copia del backup al recurso compartido SMB..."
if check_cifs_utils && mount_smb_share; then
    if smb_write_test && copy_backup_to_smb && verify_backup_on_smb; then
        cleanup_old_backups_smb
        sync
        if unmount_smb_share; then
            SMB_OK=1
            log_message "SUCCESS: Backup copiado al recurso compartido SMB con éxito"
        else
            log_message "ERROR: Copia verificada pero falló el desmontaje SMB"
        fi
    else
        log_message "ERROR: Falló la copia o verificación en el recurso compartido SMB"
        sync
        unmount_smb_share || true
    fi
else
    log_message "ERROR: No se pudo montar el recurso compartido SMB"
fi

if [ "$SMB_OK" -eq 1 ]; then
    log_message "SUCCESS: Proceso de backup completado"
    mark_backup_ok
    exit 0
fi

log_message "ERROR: Backup local OK, réplica SMB falló"
mark_backup_failed "Backup local OK, réplica SMB falló"
exit 2
