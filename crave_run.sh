#!/bin/bash

# set pipelined command flow
set -o pipefail

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️ .env file not found!"
    exit 1
fi

# Load your local secrets
set -o allexport
source .env
set +o allexport

# ================= CONFIG =================
if [ ! -f "build_header.sh" ]; then
    echo "Fetching build_header.sh"
    curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_scripts/lineage-23.2/config/build_header.sh -o build_header.sh
fi
echo "Loading build_header.sh"
source build_header.sh

# ================= BUILD =================
echo ">>>> [STEP] Clean"
# List the specific folders that cause issues for creek
remove=(
    .repo/local_manifests
    hardware/qcom-caf/common
    hardware/qcom-caf/sm6225/*
    device/xiaomi/*
    vendor/xiaomi/*
    vendor/lineage-priv/keys
    vendor/qcom/opensource/*
)

# Efficiently remove all of them
for folder in "${remove[@]}"; do
    rm -rf "$folder"
    echo "    Cleaned: $folder"
done

echo ">>>> [STEP] Repo Init"
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs

echo ">>>> [STEP] Local Manifests"
git clone https://github.com/nuruszama/local_manifest.git -b lineage-23.2 .repo/local_manifests

echo ">>>> [STEP] Repo Sync"
SYNC_START=$(date +%s)

if [ -f /opt/crave/resync.sh ]; then
    /opt/crave/resync.sh
else
    repo sync -c --force-sync --no-tags --no-clone-bundle -j$(nproc --all)
fi

rm -rf hardware/qcom-caf/common
git clone https://github.com/sapphire-sm6225/android_hardware_qcom-caf_common.git -b lineage-23.2 hardware/qcom-caf/common

SYNC_END=$(date +%s)
SYNC_DIFF=$((SYNC_END - SYNC_START))

if [ $SYNC_DIFF -ge 3600 ]; then
    SYNC_TIME="$((SYNC_DIFF/3600))h $(((SYNC_DIFF%3600)/60))min"
else
    SYNC_TIME="$((SYNC_DIFF/60)) min"
fi
  
echo ">>>> [STEP] Set up build environment"
source build/envsetup.sh

echo ">>>> [STEP] Lunch"
lunch ${ROM_NAME}_${DEVICE}-${RELEASE}-${BUILD_TYPE}
export BUILD_USERNAME=nuruszama
export BUILD_HOSTNAME=arch
make installclean

tg_send "🔄 _Synchronization took ${SYNC_TIME}_
🔥 Baconing for *${DEVICE}*"

# ================= BUILD RUN =================
set -o pipefail
mka bacon 2>&1 | tee "$BUILD_LOG"

# ============ POST SCRIPT UPLOADS ============
if [ ! -f "upload_script.sh" ]; then
    echo "Fetching upload_script.sh"
    curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_scripts/lineage-23.2/config/upload_script.sh -o upload_script.sh
fi
echo "Loading upload_script.sh"
source upload_script.sh
