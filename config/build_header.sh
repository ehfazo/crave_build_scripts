# ================= TIMEZONE =================
echo "🕒 Switching system timezone"
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/${TZ} /etc/localtime
echo "🕒 Current system time: $(date)"

# ================= CONFIGS =================
if [ ! -f "uploads_logic.sh" ]; then
    echo "Fetching uploads_logic.sh"
    curl -sf https://raw.githubusercontent.com/ehfazo/crave_build_scripts/lineage-23.2/config/uploads_logic.sh -o uploads_logic.sh
fi
echo "Loading uploads_logic.sh"
source uploads_logic.sh
rm -rf build_config.sh

# ================= BUILD START =================
tg_send "┌───────────────────┐
  📢      *Buildbot* initialized      📢
└───────────────────┘

      🧬 *${PROJECT_VERSION}*     🧩 *${DEVICE}*

 *Android Version:  ${ANDROID_VERSION}*
 *Build Type:  ${BUILD_TYPE}*
 *Release:  ${RELEASE}*
 *Flavor:  ${BUILD_FLAVOUR}*

🌏 _$(date +"%d %b %Y %I:%M %p GST")_"
