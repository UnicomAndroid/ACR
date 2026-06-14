#!/system/bin/sh
# Common boot script functions for ACR

app_id="studio.unicom.acr"
log_file="${1:-/dev/null}"

header() {
    echo "" >> "$log_file"
    echo "=== $(date) - ${1} ===" >> "$log_file"
}

run_cli_apk() {
    # Execute a Kotlin standalone CLI through app_process as system UID
    CLASSPATH="/system/priv-app/${app_id}/${app_id}.apk" \
        app_process / com.android.internal.util.WithFramework "${1}" >> "$log_file" 2>&1
}
