#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KSU_DIR="$SCRIPT_DIR/ksu"
OUTPUT_DIR="$PROJECT_DIR/build/ksu"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

cleanup() {
  if [ -d "$PROJECT_DIR/ksu-module" ]; then
    log_info "清理临时目录 ksu-module/"
    rm -rf "$PROJECT_DIR/ksu-module"
  fi
}

log_info "==> 构建 ACR KernelSU 模块 <=="
trap cleanup EXIT

# 1. 获取版本信息
log_info "获取版本信息..."
VERSION=$(git -C "$PROJECT_DIR" describe --tags --always 2>/dev/null || echo "unknown")
VERSION_CODE=$(git -C "$PROJECT_DIR" rev-list --count HEAD 2>/dev/null || echo "0")
log_info "  版本: v${VERSION} (code: ${VERSION_CODE})"

# 2. 构建 Flutter APK (必须先构建)
log_info "构建 Flutter APK..."
cd "$PROJECT_DIR"
flutter build apk --release
log_info "APK 构建完成"

# 3. 创建 KSU 模块目录结构
log_info "创建 KSU 模块目录结构..."
rm -rf "$PROJECT_DIR/ksu-module"

mkdir -p "ksu-module/system/priv-app/studio.unicom.acr"
mkdir -p "ksu-module/system/etc/permissions"
mkdir -p "ksu-module/META-INF/com/google/android"

# 4. 复制 APK
cp "$PROJECT_DIR/build/app/outputs/apk/release/app-release.apk" \
   "ksu-module/system/priv-app/studio.unicom.acr/studio.unicom.acr.apk"
log_info "已复制 APK"

# 5. 生成权限白名单
cat > "ksu-module/system/etc/permissions/privapp-permissions-studio.unicom.acr.xml" << 'XML'
<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <privapp-permissions package="studio.unicom.acr">
        <permission name="android.permission.CAPTURE_AUDIO_OUTPUT" />
        <permission name="android.permission.CONTROL_INCALL_EXPERIENCE" />
    </privapp-permissions>
</permissions>
XML
log_info "已生成权限白名单"

# 6. 复制脚本
if [ -d "$KSU_DIR" ]; then
  for f in customize.sh post-fs-data.sh service.sh boot_common.sh; do
    if [ -f "$KSU_DIR/$f" ]; then
      cp "$KSU_DIR/$f" "ksu-module/"
      chmod 755 "ksu-module/$f"
      log_info "已复制脚本: $f"
    else
      log_warn "脚本缺失: $f (跳过)"
    fi
  done
fi

# 7. 生成 module.prop
if [ -f "$KSU_DIR/module.prop.template" ]; then
  sed "s/{VERSION}/${VERSION}/g; s/{VERSION_CODE}/${VERSION_CODE}/g" \
      "$KSU_DIR/module.prop.template" > "ksu-module/module.prop"
  log_info "已生成 module.prop"
else
  log_warn "module.prop.template 缺失"
fi

# 8. META-INF (Magisk 兼容)
printf '#MAGISK\n' > "ksu-module/META-INF/com/google/android/updater-script"
log_info "已生成 META-INF/updater-script"

# 9. 打包 zip
mkdir -p "$OUTPUT_DIR"
ZIP_NAME="ACR-KSU-${VERSION}.zip"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

cd "$PROJECT_DIR/ksu-module"
zip -r "$ZIP_PATH" . > /dev/null
cd "$PROJECT_DIR"

log_info "==> 打包完成: ${ZIP_PATH}"
echo "$ZIP_PATH"
