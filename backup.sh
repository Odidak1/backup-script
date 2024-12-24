#!/bin/bash
#==================================
# PENGATURAN UTAMA
#==================================
license_key=""
BACKUP_DATA=true
BACKUP_DB=true
RCLONE_REMOTE_NAME="your_remote_name"
BASE_DIR="/path/to/your/base/dir"

#==================================
# KONFIGURASI MYSQL
#==================================
MYSQL_HOST="your_mysql_host"
MYSQL_PORT="3306"
MYSQL_USER="your_mysql_user"
MYSQL_PASSWORD="your_mysql_password"
DATABASES=("example_db1" "example_db2") # bisa ditambah

#==================================
# DURASI RETENSI BACKUP
#==================================
BACKUP_RETENTION="7 hari" # menit, jam, hari

#==================================
# KONFIGURASI LOKASI GOOGLE DRIVE
#==================================
GDRIVE_DIR_DATA="AutoBackup/Data"
GDRIVE_DIR_DB="AutoBackup/DB"

#==================================
# KONFIGURASI WEBHOOK
#==================================
WEBHOOK_DATA_URL=""
WEBHOOK_DB_URL=""

#==================================
# KONFIGURASI NOTIFIKASI WEBHOOK
#==================================
TITLE_DATA="**Status Backup Data**"
DESCRIPTION_START_DATA="Proses backup data telah dimulai🚀."
DESCRIPTION_SUCCESS_DATA="Backup data berhasil."
DESCRIPTION_FAIL_DATA="Backup data gagal."
COLOR_START_DATA=16755456
COLOR_SUCCESS_DATA=58889
COLOR_FAIL_DATA=16721408

TITLE_DB="**Status Backup Database**"
DESCRIPTION_START_DB="Proses backup database telah dimulai🚀."
DESCRIPTION_SUCCESS_DB="Backup database berhasil."
DESCRIPTION_FAIL_DB="Backup database gagal."
COLOR_START_DB=16755456
COLOR_SUCCESS_DB=58889
COLOR_FAIL_DB=16721408

#==================================
# JANGAN UBAH DI BAWAH INI
#==================================
if [ -z "$license_key" ]; then
    echo "=============================="
    echo "Error: License key belum diisi."
    echo "=============================="
    exit 1
fi
EKHEM_URL="https://raw.githubusercontent.com/Odidak1/licensebackup/refs/heads/main/license.json"
check_license_key() {
    local license_key=$1
    response=$(curl -s "$EKHEM_URL" | jq --arg key "$license_key" \
        '.licenses[] | select(.key == $key)')
    if [ -z "$response" ]; then
        echo "=============================="
        echo "Error: License key tidak valid."
        echo "=============================="
        echo "Beli license key? hubungi:"
        echo "Email: raditm100308@gmail.com"
        echo "Wa: +62 851-5096-0915"
        echo "------------------------------"
        exit 1
    fi
    expired=$(echo "$response" | jq -r '.expired')
    username=$(echo "$response" | jq -r '.username')
    if [ "$expired" == "true" ]; then
        echo "=============================="
        echo "Halo, $username"
        echo "License key sudah expired."
        echo "=============================="
        echo "Silahkan perpanjang license:"
        echo "Email: raditm100308@gmail.com"
        echo "Wa: +62 851-5096-0915"
        echo "------------------------------"
        exit 1
    else
        echo "=============================="
        echo "Selamat datang, $username!"
        echo "=============================="
        echo "Tunggu sebentar, script akan dijalankan..."
        echo "------------------------------"
        sleep 1
    fi
}
check_license_key "$license_key"
set -euo pipefail
IFS=$'\n\t'
TEMP_DIR="$(mktemp -d)"
DATE_DIR="$(date +"%d-%m-%Y %H:%M")"
GDRIVE_DATE_DIR_DATA="${GDRIVE_DIR_DATA}/${DATE_DIR}"
GDRIVE_DATE_DIR_DB="${GDRIVE_DIR_DB}/${DATE_DIR}"
convert_to_seconds() {
    duration=$1
    value=$(echo "$duration" | awk '{print $1}')
    unit=$(echo "$duration" | awk '{print $2}')
    case "$unit" in
        menit)
            echo $(($value * 60))
            ;;
        jam)
            echo $(($value * 3600))
            ;;
        hari)
            echo $(($value * 86400))
            ;;
        *)
            echo "Format waktu tidak dikenal: $unit" >&2
            exit 1
            ;;
    esac
}
check_dependencies() {
    missing=0
    for cmd in rclone zip curl bc jq mysqldump; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Dependensi $cmd tidak ditemukan. Menginstal..."
            missing=1
        fi
    done
    if [ $missing -eq 1 ]; then
        echo "Menginstal dependensi yang diperlukan..."
        sudo apt-get update
        sudo apt-get install -y rclone zip curl bc jq mysqldump
    fi
}
delete_old_backups() {
    retention_secs=$(convert_to_seconds "$BACKUP_RETENTION")
    rclone lsf --dirs-only "${RCLONE_REMOTE_NAME}:${GDRIVE_DIR_DATA}" | while read -r folder; do
        folder_date=$(echo "$folder" | awk -F'/' '{print $2}')
        folder_ts=$(date -d "$folder_date" +%s)
        current_ts=$(date +%s)
        diff_secs=$((current_ts - folder_ts))
        if [ "$diff_secs" -gt "$retention_secs" ]; then
            rclone purge --drive-use-trash=false "${RCLONE_REMOTE_NAME}:${GDRIVE_DIR_DATA}/${folder}"
        fi
    done
    rclone lsf --dirs-only "${RCLONE_REMOTE_NAME}:${GDRIVE_DIR_DB}" | while read -r folder; do
        folder_date=$(echo "$folder" | awk -F'/' '{print $2}')
        folder_ts=$(date -d "$folder_date" +%s)
        current_ts=$(date +%s)
        diff_secs=$((current_ts - folder_ts))
        if [ "$diff_secs" -gt "$retention_secs" ]; then
            rclone purge --drive-use-trash=false "${RCLONE_REMOTE_NAME}:${GDRIVE_DIR_DB}/${folder}"
        fi
    done
}
format_size() {
    size_input=$1
    size_kb_fmt=$(echo "scale=2; $size_input / 1024" | bc)
    size_mb_fmt=$(echo "scale=2; $size_input / 1024 / 1024" | bc)
    size_gb_fmt=$(echo "scale=2; $size_input / 1024 / 1024 / 1024" | bc)
    kb_int=$(echo "$size_kb_fmt * 100" | bc | cut -d'.' -f1)
    mb_int=$(echo "$size_mb_fmt * 100" | bc | cut -d'.' -f1)
    gb_int=$(echo "$size_gb_fmt * 100" | bc | cut -d'.' -f1)
    if [ $gb_int -ge 100 ]; then
        echo "$size_gb_fmt GB"
    elif [ $mb_int -ge 100 ]; then
        echo "$size_mb_fmt MB"
    else
        echo "$size_kb_fmt KB"
    fi
}
get_gdrive_usage() {
    drive_info=$(rclone about "${RCLONE_REMOTE_NAME}:" --json 2>/dev/null)
    if [ $? -eq 0 ]; then
        space_used=$(echo "$drive_info" | jq -r '.used')
        space_total=$(echo "$drive_info" | jq -r '.total')
        fmt_used=$(format_size "$space_used")
        fmt_total=$(format_size "$space_total")
        echo "${fmt_used}/${fmt_total}"
    else
        echo "Tidak dapat mengambil informasi disk"
    fi
}
backup_folder() {
    src_folder="$1"
    dest_file="$2"
    if [ -z "$(ls -A "$src_folder")" ]; then
        echo "Folder $src_folder kosong, melewatkan backup." >&2
        return 1
    fi
    cp -r "${src_folder}" "${TEMP_DIR}/" || { echo "Gagal menyalin folder ${src_folder}"; return 1; }
    zip -r "${dest_file}" "${TEMP_DIR}/$(basename "$src_folder")" || { echo "Gagal mengompres folder ${src_folder}"; return 1; }
}
backup_database() {
    db="$1"
    dest_file="$2"
    if ! mysqldump -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$db" > "$dest_file"; then
        echo "Backup untuk database $db gagal" >&2
        return 1
    fi
}
send_webhook() {
    webhook_url=$1
    status=$2
    size=$3
    curr_time=$(date +"%d-%m-%Y %H:%M")
    disk_info=$(get_gdrive_usage)
    if [ "$webhook_url" == "$WEBHOOK_DATA_URL" ]; then
        title="$TITLE_DATA"
        desc_start="$DESCRIPTION_START_DATA"
        desc_success="$DESCRIPTION_SUCCESS_DATA"
        desc_fail="$DESCRIPTION_FAIL_DATA"
        color_start="$COLOR_START_DATA"
        color_success="$COLOR_SUCCESS_DATA"
        color_fail="$COLOR_FAIL_DATA"
    else
        title="$TITLE_DB"
        desc_start="$DESCRIPTION_START_DB"
        desc_success="$DESCRIPTION_SUCCESS_DB"
        desc_fail="$DESCRIPTION_FAIL_DB"
        color_start="$COLOR_START_DB"
        color_success="$COLOR_SUCCESS_DB"
        color_fail="$COLOR_FAIL_DB"
    fi
    case "$status" in
        "start")
            curl -H "Content-Type: application/json" -X POST -d '{
                "embeds": [{
                    "title": "'"${title}"'",
                    "description": "'"${desc_start}"'",
                    "color": '"${color_start}"'
                }]
            }' "${webhook_url}"
            ;;
        "success")
            curl -H "Content-Type: application/json" -X POST -d '{
                "embeds": [{
                    "title": "'"${title}"'",
                    "description": "**[:page_facing_up:] | Status: **'"${desc_success}"'\n**[:open_file_folder:] | Backup Size:** '"${size}"'\n**[:dividers:] | Cloud Drive:** '"${disk_info}"'\n**[:date:] | Date & Time:** '"${curr_time}"'",
                    "color": '"${color_success}"'
                }]
            }' "${webhook_url}"
            ;;
        "fail")
            curl -H "Content-Type: application/json" -X POST -d '{
                "embeds": [{
                    "title": "'"${title}"'",
                    "description": "**[:page_facing_up:] | Status: **'"${desc_fail}"'\n**[:date:] | Date & Time:** '"${curr_time}"'",
                    "color": '"${color_fail}"'
                }]
            }' "${webhook_url}"
            ;;
    esac
}
backup_data() {
    data_size=0
    failed=true
    send_webhook "$WEBHOOK_DATA_URL" "start" ""
    for folder in "${BASE_DIR}"/*; do
        if [ -d "${folder}" ]; then
            folder_name=$(basename "${folder}")
            backup_path="${TEMP_DIR}/${folder_name}.zip"
            if backup_folder "${folder}" "${backup_path}"; then
                file_size=$(stat -c%s "${backup_path}")
                data_size=$((data_size + file_size))
                if rclone copy "${backup_path}" "${RCLONE_REMOTE_NAME}:${GDRIVE_DATE_DIR_DATA}"; then
                    failed=false
                fi
            fi
        fi
    done
    size_fmt=$(format_size ${data_size})
    if [ "$failed" = true ]; then
        send_webhook "$WEBHOOK_DATA_URL" "fail" ""
    else
        send_webhook "$WEBHOOK_DATA_URL" "success" "$size_fmt"
    fi
}
backup_db() {
    db_size=0
    fails=0
    send_webhook "$WEBHOOK_DB_URL" "start" ""
    for db in "${DATABASES[@]}"; do
        backup_path="${TEMP_DIR}/${db}.sql"
        if backup_database "${db}" "${backup_path}"; then
            file_size=$(stat -c%s "${backup_path}")
            db_size=$((db_size + file_size))
            if ! rclone copy "${backup_path}" "${RCLONE_REMOTE_NAME}:${GDRIVE_DATE_DIR_DB}"; then
                fails=$((fails + 1))
            fi
        else
            fails=$((fails + 1))
        fi
    done
    size_fmt=$(format_size ${db_size})
    if [[ ${fails} -gt 0 ]]; then
        send_webhook "$WEBHOOK_DB_URL" "fail" ""
    else
        send_webhook "$WEBHOOK_DB_URL" "success" "$size_fmt"
    fi
}
trap '[[ -d "${TEMP_DIR}" ]] && rm -rf "${TEMP_DIR}"' EXIT
check_dependencies
mkdir -p "${TEMP_DIR}" || { echo "Gagal membuat direktori sementara"; exit 1; }
rclone mkdir "${RCLONE_REMOTE_NAME}:${GDRIVE_DATE_DIR_DATA}" || { echo "Gagal membuat direktori remote"; exit 1; }
rclone mkdir "${RCLONE_REMOTE_NAME}:${GDRIVE_DATE_DIR_DB}" || { echo "Gagal membuat direktori remote untuk DB"; exit 1; }
delete_old_backups
if [ "$BACKUP_DATA" = true ]; then
    backup_data &
fi
if [ "$BACKUP_DB" = true ]; then
    backup_db &
fi
wait
rm -rf "${TEMP_DIR}"