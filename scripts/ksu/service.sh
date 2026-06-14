#!/system/bin/sh
source "${0%/*}/boot_common.sh" /data/local/tmp/acr_service.log

header "Remove hard restrictions"
run_cli_apk studio.unicom.acr.standalone.RemoveHardRestrictionsKt

header "Package state"
dumpsys package "${app_id}"

header "Fix DP storage SELinux label"
restorecon -RDv /data/user_de/0/"${app_id}"
