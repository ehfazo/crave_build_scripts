# ================= TIMEZONE =================
echo "🕒 Switching system timezone"
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/${TZ} /etc/localtime
echo "🕒 Current system time: $(date)"

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
