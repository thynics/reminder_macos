#!/bin/bash
set -euo pipefail

# ---- config you may tweak ----
USE_NOTIFICATION=0  # 0=弹窗(display dialog) 1=通知横幅(display notification)
TITLE="提醒"
# -----------------------------

die() { echo "ERROR: $*" >&2; exit 1; }

if [[ "${EUID}" -ne 0 ]]; then
  die "请用 sudo 运行：sudo bash $0"
fi

# 目标用户：优先 sudo 发起者；否则取当前 GUI 控制台用户
TARGET_USER="${SUDO_USER:-}"
if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
  TARGET_USER="$(/usr/bin/stat -f%Su /dev/console)"
fi
[[ -n "${TARGET_USER}" && "${TARGET_USER}" != "root" ]] || die "无法确定目标用户（SUDO_USER 为空且控制台用户异常）"

# 必须有 GUI 登录会话，否则无法弹窗
CONSOLE_USER="$(/usr/bin/stat -f%Su /dev/console)"
if [[ "${CONSOLE_USER}" == "loginwindow" ]]; then
  die "当前没有 GUI 用户登录（/dev/console=loginwindow）。请先登录桌面后再运行本脚本。"
fi

TARGET_UID="$(/usr/bin/id -u "${TARGET_USER}")"

# 取 home 目录
HOME_DIR="$(/usr/bin/dscl . -read "/Users/${TARGET_USER}" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}')"
if [[ -z "${HOME_DIR}" || ! -d "${HOME_DIR}" ]]; then
  HOME_DIR="$(eval echo "~${TARGET_USER}")"
fi
[[ -d "${HOME_DIR}" ]] || die "找不到用户 home：${HOME_DIR}"

BIN_DIR="${HOME_DIR}/bin"
LA_DIR="${HOME_DIR}/Library/LaunchAgents"
SCRIPT_PATH="${BIN_DIR}/health_popup.sh"

PLIST_STAND="${LA_DIR}/com.cheng.reminder.standwater.plist"
PLIST_SIT="${LA_DIR}/com.cheng.reminder.sitdown.plist"

mkdir -p "${BIN_DIR}" "${LA_DIR}"

# 写弹窗脚本
cat > "${SCRIPT_PATH}" <<'EOF'
#!/bin/zsh
set -euo pipefail

MSG="$1"
TITLE="${2:-提醒}"

# 0=弹窗 1=通知
USE_NOTIFICATION="${3:-0}"

if [[ "${USE_NOTIFICATION}" == "1" ]]; then
  /usr/bin/osascript -e "display notification \"${MSG}\" with title \"${TITLE}\""
else
  /usr/bin/osascript <<OSA
display dialog "${MSG}" with title "${TITLE}" buttons {"知道了"} default button 1 giving up after 20
OSA
fi
EOF

chmod +x "${SCRIPT_PATH}"
chown "${TARGET_USER}":staff "${SCRIPT_PATH}" || true

# 写 plist（:45 站立喝水，13-20）
cat > "${PLIST_STAND}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key><string>com.cheng.reminder.standwater</string>

    <key>ProgramArguments</key>
    <array>
      <string>/bin/zsh</string>
      <string>-lc</string>
      <string>${SCRIPT_PATH} "站立&喝水" "${TITLE}" "${USE_NOTIFICATION}"</string>
    </array>

    <key>StartCalendarInterval</key>
    <array>
      <dict><key>Hour</key><integer>13</integer><key>Minute</key><integer>45</integer></dict>
      <dict><key>Hour</key><integer>14</integer><key>Minute</key><integer>45</integer></dict>
      <dict><key>Hour</key><integer>15</integer><key>Minute</key><integer>45</integer></dict>
      <dict><key>Hour</key><integer>16</integer><key>Minute</key><integer>45</integer></dict>
      <dict><key>Hour</key><integer>17</integer><key>Minute</key><integer>45</integer></dict>
      <dict><key>Hour</key><integer>18</integer><key>Minute</key><integer>45</integer></dict>
      <dict><key>Hour</key><integer>19</integer><key>Minute</key><integer>45</integer></dict>
      <dict><key>Hour</key><integer>20</integer><key>Minute</key><integer>45</integer></dict>
    </array>

    <key>RunAtLoad</key><false/>

    <key>StandardOutPath</key><string>/tmp/com.cheng.reminder.standwater.out</string>
    <key>StandardErrorPath</key><string>/tmp/com.cheng.reminder.standwater.err</string>

    <key>LimitLoadToSessionType</key>
    <array><string>Aqua</string></array>
  </dict>
</plist>
EOF

# 写 plist（:00 坐下，13-21）
cat > "${PLIST_SIT}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key><string>com.cheng.reminder.sitdown</string>

    <key>ProgramArguments</key>
    <array>
      <string>/bin/zsh</string>
      <string>-lc</string>
      <string>${SCRIPT_PATH} "坐下" "${TITLE}" "${USE_NOTIFICATION}"</string>
    </array>

    <key>StartCalendarInterval</key>
    <array>
      <dict><key>Hour</key><integer>13</integer><key>Minute</key><integer>0</integer></dict>
      <dict><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
      <dict><key>Hour</key><integer>15</integer><key>Minute</key><integer>0</integer></dict>
      <dict><key>Hour</key><integer>16</integer><key>Minute</key><integer>0</integer></dict>
      <dict><key>Hour</key><integer>17</integer><key>Minute</key><integer>0</integer></dict>
      <dict><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
      <dict><key>Hour</key><integer>19</integer><key>Minute</key><integer>0</integer></dict>
      <dict><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
      <dict><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
    </array>

    <key>RunAtLoad</key><false/>

    <key>StandardOutPath</key><string>/tmp/com.cheng.reminder.sitdown.out</string>
    <key>StandardErrorPath</key><string>/tmp/com.cheng.reminder.sitdown.err</string>

    <key>LimitLoadToSessionType</key>
    <array><string>Aqua</string></array>
  </dict>
</plist>
EOF

chmod 644 "${PLIST_STAND}" "${PLIST_SIT}"
chown "${TARGET_USER}":staff "${PLIST_STAND}" "${PLIST_SIT}" || true

# 先卸载旧的（忽略失败）
/bin/launchctl bootout "gui/${TARGET_UID}" "${PLIST_STAND}" 2>/dev/null || true
/bin/launchctl bootout "gui/${TARGET_UID}" "${PLIST_SIT}" 2>/dev/null || true

# 安装并立即生效
/bin/launchctl bootstrap "gui/${TARGET_UID}" "${PLIST_STAND}"
/bin/launchctl bootstrap "gui/${TARGET_UID}" "${PLIST_SIT}"

echo "OK ✅ 已安装到用户：${TARGET_USER}（uid=${TARGET_UID}）"
echo "  - :45 站立&喝水（13-20点）"
echo "  - :00 坐下（13-21点）"
echo "文件："
echo "  ${SCRIPT_PATH}"
echo "  ${PLIST_STAND}"
echo "  ${PLIST_SIT}"
echo ""
echo "手动测试："
echo "  launchctl kickstart -k gui/${TARGET_UID}/com.cheng.reminder.standwater"
echo "  launchctl kickstart -k gui/${TARGET_UID}/com.cheng.reminder.sitdown"
echo ""
echo "卸载："
echo "  sudo launchctl bootout gui/${TARGET_UID} ${PLIST_STAND} || true"
echo "  sudo launchctl bootout gui/${TARGET_UID} ${PLIST_SIT} || true"
echo "  rm -f ${PLIST_STAND} ${PLIST_SIT} ${SCRIPT_PATH}"
