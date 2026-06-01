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
SET_BASE_DIR="$4"
if [[ -z "$USER" ]] || [[ -z "$GROUP" ]]; then
    echo "$ICON_BEE Syntax: install/install-scikit.sh {USER} {GROUP}"
    exit 0
fi


# --- Paths ---
if [[ "$SET_BASE_DIR" == "/opt/honeybeebash" ]]; then
    BASE_DIR="/opt/honeybeebash"

    # --- User specific directories ---
    TARGET_HOME=$(getent passwd "$USER" | cut -d: -f6)
    echo "$ICON_DIR Install directory detected at: $TARGET_HOME"
    USER_CONFIG_DIR="$TARGET_HOME/.config/honeybeebash"
    USER_LOCAL_DIR="$TARGET_HOME/.local/share/honeybeebash"

elif [[ -d "$SET_BASE_DIR" ]]; then
    BASE_DIR="$SET_BASE_DIR"
    echo "$ICON_DIR Custom directory detected at: $BASE_DIR"
    USER_CONFIG_DIR="$BASE_DIR/config"
    USER_LOCAL_DIR="$BASE_DIR"

else
    echo "ERROR: Could not find base directory."
    exit 1
fi

# --- Define our Backpack Tools ---
BACKPACK_DIR="$BASE_DIR/backpack"

# --- List of required modules ---
MODULES=("numpy" "scikit-learn" "pandas" "joblib")

echo "$ICON_BEE Initiating installation of scikit-learn + pandas + joblib)..."



# --- OS Detection ---
OS_FAMILY=""
if command -v getprop &> /dev/null; then
    echo "Android device detected. Adjusting configuration..."
    OS_FAMILY="android"
    VERSION_MAJOR=""

elif [ -f /etc/os-release ]; then
    . /etc/os-release
    
    # Extract the major version number (e.g., "7.9" or "8" or "9.2" becomes "7", "8", "9")
    # Removing quotes if present in VERSION_ID
    VERSION_MAJOR=$(echo "${VERSION_ID:-0}" | tr -d '"' | cut -d. -f1)
    OS_FAMILY="$ID"
    
else
    OS_FAMILY=$(uname -s | tr '[:upper:]' '[:lower:]')
    VERSION_MAJOR=0
fi
if [[ -z "$OS_FAMILY" ]]; then
    echo "$ICON_FAIL Error: OS cannot be detected. Force it in /etc/os-release"
    exit 1
fi

echo "$ICON_BEE Sensing Environment: $OS_FAMILY detected."


case "$OS_FAMILY" in
    ubuntu|debian|raspberrypi|kali|raspbian|pop)
        UPDATE_CMD="apt-get update --allow-releaseinfo-change"
        INSTALL_CMD="apt-get install -y --allow-unauthenticated" 
        ;;
    fedora)
        UPDATE_CMD="dnf check-update"
        INSTALL_CMD="dnf install -y"
        ;;
    rhel|almalinux|rocky|centos) 
        # Check if we are on RHEL 8+ / modern systems or RHEL 7 / legacy systems
        if [ "$VERSION_MAJOR" -ge 8 ]; then
            echo "$ICON_DOWNLOAD Ensuring EPEL repository for Enterprise Linux..."
            dnf install -y epel-release --nogpgcheck >/dev/null 2>&1
            
            UPDATE_CMD="dnf check-update"
            INSTALL_CMD="dnf install -y --nogpgcheck" 
        else
            echo "$ICON_DOWNLOAD Ensuring EPEL repository for Enterprise Linux 7..."
            # For RHEL 7, epel-release is typically pulled via yum
            yum install -y epel-release >/dev/null 2>&1
            
            UPDATE_CMD="yum check-update" # || true
            # Note: yum check-update returns an exit code of 100 if updates are available.
            # If your script uses 'set -e', you might want to append '|| true' to UPDATE_CMD
            INSTALL_CMD="yum install -y --nogpgcheck" 
        fi
        ;;
    arch|manjaro) 
        UPDATE_CMD="pacman -Sy" 
        INSTALL_CMD="pacman -S --noconfirm" 
        ;;
    opensuse*|tumbleweed|sles|suse)
        UPDATE_CMD="zypper refresh"
        INSTALL_CMD="zypper install -y"
        ;;
    android)
        UPDATE_CMD="pkg update"
        INSTALL_CMD="pkg install -y"
        ;;
    *) 
        echo -e "\n$ICON_FAIL Unknown OS ($OS_FAMILY). Install dependencies manually: ${DEPENDENCIES[*]}"
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