#!/bin/bash
# HoneyBeeBash Uninstaller
# Syntax: sudo ./uninstall.sh {USER}

# --- Obtain basic config ---
if [[ ! -f "config-default/bee.conf-default" ]]; then
    echo "ERROR: Can not find config-default/bee.conf-default. "
    echo "Run this from the src directory or reinstall to correct the installation."
    exit 1
fi
source "config-default/bee.conf-default"

if [ "$EUID" -ne 0 ]; then 
  echo "$ICON_FAIL Please run as root (use sudo)"
  exit 1
fi

# --- Requires user  ---
echo " "
read -p "$ICON_QUESTION Enter the username to uninstall for: " USER
USER=${USER,,}
if [[ -z "$USER" ]]; then
    echo "$ICON_FAIL Uninstalling requires confirmation of the username."
    exit 1
fi

# Detect custom path, if config is next to install/ then its a custom path installation
REAL_SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$REAL_SCRIPT_PATH")
if [[ -f "$SCRIPT_DIR/config/bee.conf" ]]; then
    # --- Paths (Custom path) ---
    BASE_DIR=$(dirname "$SCRIPT_DIR")
    USER_CONFIG_DIR="$BASE_DIR/config"
    USER_LOCAL_DIR="$BASE_DIR/"
else
    # --- Paths (System environment) ---
    BASE_DIR="/opt/honeybeebash"
    TARGET_HOME=$(getent passwd "$USER" | cut -d: -f6)
    USER_CONFIG_DIR="$TARGET_HOME/.config/honeybeebash"
    USER_LOCAL_DIR="$TARGET_HOME/.local/share/honeybeebash"
fi

echo -e "\n-------------------------------------------------------"
echo "           $ICON_BEE HONEYBEE UNINSTALLER                     "
echo -e "-------------------------------------------------------\n"

echo ""
echo "Uninstalling from $BASE_DIR ..."
echo ""

read -p "$ICON_CRITICAL This will remove HoneyBee and ALL user configs for $USER. Continue? (Yes/No): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall aborted."
    exit 0
fi

# 1. Remove Symlinks
echo "$ICON_LINK Removing Symlinks ..."
rm -f /usr/local/bin/bee
rm -f /usr/local/bin/monitor


# 2. Optional: Python Cleanup
# Note: This doesn't remove global pip packages (like google-genai) 
# because other apps might use them.

# 3. SciKit cleanup
# --- Path to the user's active config ---
# Ensure this matches the variables defined earlier in your script
if [[ -f "$USER_CONFIG_DIR/bee.conf" ]]; then
    if grep -q '^ENABLE_SCIKIT="true"' "$USER_CONFIG_DIR/bee.conf"; then
        echo "$ICON_SUCCES SciKit detected in config. Running sub-uninstaller ..."
        if [[ -f "./install/uninstall-scikit.sh" ]]; then
            bash ./install/uninstall-scikit.sh "$USER"
        else
            echo "$ICON_CRITICAL  Warning: uninstall-scikit.sh not found. Cleaning backpack manually ..."
            sudo rm -rf "/opt/honeybeebash/backpack"
        fi
    else
        echo "$ICON_INFO  SciKit is not enabled in $USER_CONFIG_DIR/bee.conf. Skipping backpack removal."
    fi
else
    echo "$ICON_INFO  No bee.conf found at $USER_CONFIG_DIR/"
fi

# 4. Remove User Data
echo "$ICON_DIR Removing User Data and Configs ..."
rm -rf "$USER_CONFIG_DIR"
rm -rf "$USER_LOCAL_DIR"

# 5. Remove System Directories
echo "$ICON_DIR Removing System Files ..."
DIR_NAME=$(basename "$BASE_DIR")
if [[ "$DIR_NAME" != "src" ]]; then
    rm -rf "$BASE_DIR/"*
    # Check for remains 
    if [[ -f "$BASE_DIR/install/uninstall.sh" ]]; then
        echo "You can now remove the $BASE_DIR."
    fi
fi



# --- Final Farewell ---
echo -e "\n"
echo "    $ICON_BEE HoneyBee has left the system."
echo "    -------------------------------------------------------"
echo "    We're sorry to see you go! If you encountered any bugs"
echo "    or need help with a clean re-install, our community is"
echo "    ready to help."
echo ""
echo -e "    $ICON_HAND \e[90mJoin our Discord:\e[0m https://discord.gg/honeybeebash"
echo -e "    $ICON_LAUNCH \e[32mSee you soon for the next flight!\e[0m"
echo -e "    -------------------------------------------------------\n"