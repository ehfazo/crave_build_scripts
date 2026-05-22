# Crave Custom ROM Build Scripts 🚀

This repository contains highly automated build scripts optimized for building custom Android ROMs (specifically LineageOS) using the **Crave.io** build environment. 

These scripts handle the entire lifecycle of a build: from environment preparation and source synchronization to automated notifications and artifact distribution.

---

## ✨ Features
*   **Automated Tooling:** Self-installs dependencies like `jq` if missing.
*   **Smart Sync:** Integrates with Crave's native resync logic for maximum speed.
*   **Real-time Notifications:** Sends build status, sync times, and errors directly to Telegram.
*   **Artifact Hosting:** Automatically uploads successful builds (`.zip`) and partition images (`.img`) to **PixelDrain** and **GoFile**.
*   **Error Logging:** On failure, the script captures and uploads build logs to help with debugging.

---

## 🛠️ Setup & Usage

### 1. Prerequisites
You must have a **Crave.io** account and the `crave` CLI tool configured on your local machine or devspace.

### 2. Secrets Management
This section should be depending on the script we use. By default crave supports option 2
#### OPTION 1
Create a `.env` file in your project root. **Never commit this file to GitHub.**

```env
TG_TOKEN="your_telegram_bot_token"
TG_CHAT="your_telegram_chat_id"
PIXELDRAIN="your_pixeldrain_api_key"
```
*   **TG_TOKEN** will be used to integrate your telegram bot to your script.
*   **TG_CHAT** is the telegram chat_id to which you want to send telegram notifications.
*   **PIXELDRAIN** is your pixeldrain api. This is required to upload your files from the crave out after successful build.

#### OPTION 2
You can also set the crave to load the crave.yaml by deafult instead of setting up the .env file. For this you have to keep the crave.yaml file in the root project directory.
example of crave.yaml is as follows
```
# Crave Configuration for POCO M7 (creek)
project: "<PROJECT NAME: FROM CRAVE LIST>"
branch: "<GITHUB BRANCH FOR TREE>"
device: "<DEVICE CODENAME>"

env:
  # Adjusted to your local time in Ajman
  TZ: "<YOUR TIMEZONE>"

  # Secure Key Signing Variables (Optional for custom signature)
  BUCKET_NAME: "<YOUR BUCKET NAME>"
  KEY_ENCRYPTION_PASSWORD: "<YOUR ENCRYPTION PASSWORD>"
  BKEY_ID: "<YOUR BUCKET KEY ID>"
  BAPP_KEY: "<YOUR BUCKET APPLICATION KEY>"

  # Telegram Notifications Configuration
  TG_TOKEN: "<YOUR BOT TOKEN>"
  TG_CHAT: "<YOUR TELEGRAM GROUP OR CHANNEL ID>"

  # Pixeldrain Uploads Configuration
  PIXELDRAIN: "<YOUR PIXELDRAIN API>"

  # Custom Build Variables (optional based on your script)
  ROM_NAME: "lineage"
  DEVICE: "<DEVICE CODENAME>"
  RELEASE: "<RELEASE TYPE>"
  BUILD_TYPE: "<BUILD TYPE>"
  BUILD_FLAVOUR: "<FLAVOR>"
  ANDROID_VERSION: "<ANDROID_VERSION>"
  PROJECT_VERSION: "<PROJECT_VERSION>"

  # Web url for ota config if support OTA.
  OTA_URL: "<replace with your ota device.json web url>"
```

### 3. Setting Build Configurations
By editing the **build_config.sh**, you can change the container time zone to your timezone, define the basic details of your build.

### 4. Adding custom messages for queue notification
The script uses random messages in telegram to notify the users that the build has been successfully queued. If you required to edit or add any custom messages of your own, you can do the same by editing messages.sh.
Minimal messages.sh looks like
```
MESSAGES=(
"<Your
Custom
Message>"
)
```

### 5. Running the Build
To start a build inside the crave, execute the following command in your crave-devspaces terminal:
```
curl -sf https://raw.githubusercontent.com/nuruszama/crave_build_scripts/blob/lineage-23.2/crave_build.sh | bash
```
Don't forget to replace the above script link with your own.

---

## Push the .env file to the root of the Crave workspace
Additionally, you can push your .env file to crave server/workspace using the following script
```
crave push .env -d /tmp/src/android
```

---

# 🤝 Credits

A huge thanks to the original author for the foundation of these scripts:

*   **[EternalMikaelson](https://github.com/EternalMikaelson)** - For the original script architecture, automated workflow logic, and Telegram integration.
*   **[SoundDrill31](https://github.com/sounddrill31)** - For helping me to understand how to push the .env file to the workspace
*   **[{⚡}crave.io](https://crave.io/)** - For giving the the free server to the developers who doesn't have a workspace 
