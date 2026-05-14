#!/bin/bash
# HoneyBeeBash SciKit Uninstaller (For Re-testing)
# Syntax: sudo ./uninstall-scikit.sh {USER}

USER="$1"
if [[ -z "$USER" ]]; then
    echo "🐝 Syntax: ./uninstall-scikit.sh {USER}"
    exit 1
fi

BACKPACK_DIR="/opt/honeybeebash/backpack"
TARGET_HOME=$(getent passwd "$USER" | cut -d: -f6)
USER_CONFIG_DIR="$TARGET_HOME/.config/honeybeebash"

echo "🧹 Sanitizing the HoneyBee environment..."

# 1. Remove the virtual environment (The Backpack)
if [ -d "$BACKPACK_DIR" ]; then
    echo "🗑️ Removing the Backpack: $BACKPACK_DIR"
    sudo rm -rf "$BACKPACK_DIR"
else
    echo "ℹ️ No backpack found at $BACKPACK_DIR."
fi

# 2. Revert the config file
if [[ -f "$USER_CONFIG_DIR/bee.conf" ]]; then
    echo "📝 Disabling SciKit in bee.conf..."
    # Remove the enable line
    sed -i '/ENABLE_SCIKIT/d' "$USER_CONFIG_DIR/bee.conf"
    echo 'ENABLE_SCIKIT="false"' >> "$USER_CONFIG_DIR/bee.conf"
fi

# 3. Optional: Clear Python cache files
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null

echo "✅ Environment reset. You are ready for a clean install test."