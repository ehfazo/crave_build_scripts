# ================= ON FAIL =================
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    on_fail
fi

if grep -q -E "ninja failed|failed to build some targets" "$BUILD_LOG"; then
    on_fail
fi

# ================= SUCCESS =================
END_TIME=$(date +%s)
DUR=$((END_TIME - START_TIME))

if [ $DUR -ge 3600 ]; then
    BUILD_TIME="$((DUR/3600))h $(((DUR%3600)/60))min"
else
    BUILD_TIME="$((DUR/60)) min"
fi

ROM_ZIP=$(ls -t ${OUT_DIR}/*.zip 2>/dev/null | head -n 1)

if [ -n "$ROM_ZIP" ]; then
    BUILD_ID=$(basename "$ROM_ZIP" .zip)
    ROM_SIZE=$(du -h "$ROM_ZIP" | awk '{print $1}')

    tg_send "┌───────────────────┐
    ✧ _Buildbot finished its job_ ✧
└───────────────────┘
🆔: \`${BUILD_ID}\`
📦 Size: *${ROM_SIZE}*
⏳ _Compilation took ${BUILD_TIME}_"

    tg_send "🚨 _Compiler gave up arguing. Uploading artifacts🥃…_"
fi

# ================= UPLOAD =================
echo ">>>> [STEP] Upload Artifacts"

HEADER_MSG="✧ ${ROM_NAME} Artifacts ✧
────────────────
🧩 ${DEVICE} | ${BUILD_TYPE} | ${ANDROID_VERSION}
🆔: \`${BUILD_ID}\`
"

UPLOAD_MSG=""
IMG_MSG=""

# ROM
if [ -n "$ROM_ZIP" ]; then
    GO_URL=$(gofile_upload "$ROM_ZIP")
    PD_URL=$(pixeldrain_upload "$ROM_ZIP")

    UPLOAD_MSG="${UPLOAD_MSG}
⋄ [GoFile](${GO_URL})
⋄ [PixelDrain](${PD_URL})
"
fi

# IMAGES
for IMG in boot.img vendor_boot.img init_boot.img super_empty.img recovery.img; do
    FILE="${OUT_DIR}/${IMG}"

    if [ -f "$FILE" ]; then
        GO_URL=$(gofile_upload "$FILE")

        IMG_MSG="${IMG_MSG}
⋄ [${IMG}](${GO_URL})"
    fi
done

# OTA
OTA_JSON="${OUT_DIR}/GMS/${DEVICE}.json"

if [ -f "$OTA_JSON" ]; then
    GO_URL=$(gofile_upload "$OTA_JSON")

    IMG_MSG="${IMG_MSG}

╭─ 📜 JSON
⋄ [OTA JSON](${GO_URL})"
fi

if [ -n "$IMG_MSG" ]; then
    IMG_MSG="╭─ 🧩 IMAGES${IMG_MSG}"
fi

FINAL_MESSAGE="${HEADER_MSG}${UPLOAD_MSG}${IMG_MSG}"

tg_upload "$FINAL_MESSAGE"

if [ -n "$ROM_ZIP" ]; then
    tg_send "🥀 _Artifacts released into the wild._"
fi
