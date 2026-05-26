#!/bin/bash
# HoneyBeeBash tool install script
# Syntax: install/install-scikit.sh {USER} {GROUP}
#
# The Bee's Brain-Building Script
# Installs the Heuristic Intelligence Layer into a "Backpack" (venv)


# --- Obtain basic config ---
source "config-default/bee.conf-default"

# --- Requires user + group parameter ---
USER="$1"
GROUP="$2"
LLM_MODEL="$3"
if [[ -z "$USER" ]] || [[ -z "$GROUP" ]]; then
    echo "$ICON_BEE Syntax: install/install-scikit.sh {USER} {GROUP}"
    exit 0
fi


# --- Paths ---
BASE_DIR="/opt/honeybeebash"


# --- User specific directories ---
TARGET_HOME=$(getent passwd "$USER" | cut -d: -f6)
echo "$ICON_DIR User directory detected at: $TARGET_HOME"
USER_CONFIG_DIR="$TARGET_HOME/.config/honeybeebash"
USER_LOCAL_DIR="$TARGET_HOME/.local/share/honeybeebash"


# --- Define our Backpack Tools ---
BACKPACK_DIR="/opt/honeybeebash/backpack"

# --- List of required modules ---
MODULES=("numpy" "scikit-learn" "pandas" "joblib")

echo "$ICON_BEE Initiating installation of scikit-learn + pandas + joblib)..."



# --- OS Detection ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
fi
echo "$ICON_BEE Sensing Environment: $OS detected."

case "$OS" in
    ubuntu|debian|raspberrypi|kali|raspbian|pop)
        UPDATE_CMD="apt-get update --allow-releaseinfo-change"
        INSTALL_CMD="apt-get install -y --allow-unauthenticated" 
        ;;

    fedora|rhel|almalinux|rocky|centos)
        # Fedora is bleeding edge; no extra repos usually needed for standard nectar
        UPDATE_CMD="dnf check-update"
        INSTALL_CMD="dnf install -y" 
        ;;

    rhel|almalinux|rocky|centos)
        # Enterprise distros often need EPEL for common dependencies
        echo "$ICON_DOWNLOAD Ensuring EPEL repository for Enterprise Linux..."
        dnf install -y epel-release --nogpgcheck >/dev/null 2>&1
        
        UPDATE_CMD="dnf check-update"
        INSTALL_CMD="dnf install -y --nogpgcheck" 
        ;;

    arch|manjaro)
        UPDATE_CMD="pacman -Sy" 
        INSTALL_CMD="pacman -S --noconfirm" 
        ;;

    opensuse*|tumbleweed|sles|suse)
        UPDATE_CMD="zypper refresh"
        INSTALL_CMD="zypper install -y"
        ;;

    *)
        echo -e "\n$ICON_FAIL Unknown OS ($OS). Install dependencies manually: $DEPENDENCIES"
        exit 1 
        ;;
esac


# --- Detect System Python (The Foundation) ---
echo "Detecting System Python3..."
SYSTEM_PYTHON=$(command -v python3)

if [[ -z "$SYSTEM_PYTHON" ]]; then
    echo "$ICON_FAIL Python3 not found on system. Install it first." 
    exit 1
fi
echo "$ICON_SUCCES System Python: $SYSTEM_PYTHON"


# --- Branching Logic (Legacy vs Backpack) ---
if [[ "$LEGACY_MODE" == "true" ]]; then
    echo "$ICON_PACKAGE Legacy Mode Active: Using Global Environment."
    PYTHON_BIN="$SYSTEM_PYTHON"
    
    # Locate Global Pip
    PIP_BIN=$(command -v pip3)
    if [[ -z "$PIP_BIN" ]]; then
        if $SYSTEM_PYTHON -m pip --version &> /dev/null; then
            PIP_BIN="$SYSTEM_PYTHON -m pip"
        else
            echo "$ICON_FAIL Legacy Pip not found. Try: sudo apt install python3-pip"
            exit 1
        fi
    fi

else
    echo "$ICON_HAND Backpack Mode Active."
    # Set the Venv Binaries
    PYTHON_BIN="$BACKPACK_DIR/bin/python3"
    PIP_BIN="$BACKPACK_DIR/bin/pip3"
fi
# --- Final Validation ---
if [[ ! -x $(echo $PYTHON_BIN | cut -d' ' -f1) ]]; then
    echo "$ICON_FAIL Final Python binary not executable: $PYTHON_BIN"
    exit 1
fi

echo "$ICON_SUCCES Active Python: $PYTHON_BIN"
echo "$ICON_SUCCES Active Pip: $PIP_BIN"


# --- The Modified Install Function ---
install_module() {
    local module=$1
    local install_name=$1
    local import_name=$1

    if [[ "$module" == "scikit-learn" ]]; then install_name="scikit-learn"; import_name="sklearn"; fi

    echo "$ICON_SEARCH Verifying $import_name..."

    # This works for BOTH global and venv because $PYTHON_BIN is now dynamic
    if $PYTHON_BIN -c "import $import_name" &> /dev/null; then
        echo "$ICON_SUCCES $import_name is active."
    else
        if [ "$BACKPACK_DIR" == "SYSTEM" ]; then
             echo "$ICON_FAIL System Python is missing $import_name and I cannot sudo-install globally."
             exit 1
        fi
        
        echo "$ICON_DOWNLOAD Fetching $install_name into the backpack..."
        $PIP_BIN install "$install_name"
    fi
}


# --- Fill the Backpack (If not using system) ---
for module in "${MODULES[@]}"; do
    install_module "$module"
done


echo "$ICON_BEE Intelligence Layer is Online. The Bee's backpack is packed and ready for flight!"