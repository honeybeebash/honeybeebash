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

echo "$ICON_BEE Initiating installation of scikit-learn + pandas + joblib)..."

echo "$ICON_SEARCH Detecting OS ..."

HOSTNAME="unknown"
LINEAGE=""
OS="unknown"
OS_VARIANT=""
VERSION_MAJOR=""

echo "$ICON_SEARCH Detecting OS name ..."

if command -v getprop &> /dev/null; then
    LINEAGE="debian"
    OS="android"
    OS_VARIANT=$(getprop ro.build.version.release)

elif [[ -f "/etc/os-release" ]]; then
    OS=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '\042\047' || true)
    OS=${OS// /_} 
    OS_ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '\042\047' || true)
    OS_ID_LIKE=$(grep '^ID_LIKE=' /etc/os-release | cut -d= -f2 | tr -d '\042\047' || true)
    VARIANT_ID=$(grep '^VARIANT_ID=' /etc/os-release | cut -d= -f2 | tr -d '\042\047' || true)
    VERSION_ID=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '\042\047' || true)
    VERSION_MAJOR=${VERSION_ID%%.*}

    echo "$ICON_SEARCH Detecting OS family ..."

    if [[ "$OS_ID" =~ ^(arch|archarm|steamos|manjaro)$ ]] || [[ "$OS_ID_LIKE" =~ ^(arch|archarm|steamos|manjaro)$ ]]; then
        LINEAGE="arch"

    elif [[ "$OS_ID" =~ ^(alpine|postmarketos|adelie)$ ]] || [[ "$OS_ID_LIKE" =~ ^(alpine|postmarketos|adelie)$ ]]; then
        LINEAGE="alpine"
    
    elif [[ "$OS_ID" =~ ^(debian|ubuntu|raspberrypi|kali|raspbian|pop)$ ]] || [[ "$OS_ID_LIKE" =~ ^(debian|ubuntu|raspberrypi|kali|raspbian|pop)$ ]]; then
        LINEAGE="debian"

    elif [[ "$OS_ID" == "fedora" ]]; then
        # Explicitly match known Fedora immutable variants
        if [[ "$VARIANT_ID" =~ ^(coreos|silverblue|kinoite|sericea|onyx|iot)$ ]]; then
            LINEAGE="atomic"
            OS_VARIANT="fedora-$VARIANT_ID" 
        else
            LINEAGE="fedora"
            OS_VARIANT="standard"
        fi

    elif [[ "$OS_ID" =~ ^(gentoo|calculate|pentoo)$ ]] || [[ "$OS_ID_LIKE" =~ ^(gentoo|calculate|pentoo)$ ]]; then
        LINEAGE="gentoo"

    elif [[ "$OS_ID" =~ ^(rhel|centos|almalinux|rocky)$ ]] || [[ "$OS_ID_LIKE" =~ ^(rhel|centos|almalinux|rocky)$ ]]; then
        if [[ "$VARIANT_ID" =~ ^(coreos|rhcos)$ ]]; then
            LINEAGE="atomic"
            OS_VARIANT="redhat-$VARIANT_ID" 
        else
            LINEAGE="redhat"
            OS_VARIANT="standard"
        fi

    elif [[ "$OS_ID" =~ ^(slackware|zenwalk|salix)$ ]] || [[ "$OS_ID_LIKE" =~ ^(slackware|zenwalk|salix)$ ]]; then
        LINEAGE="slackware"
        
    elif [[ "$OS_ID" =~ ^(opensuse.*|tumbleweed|sles|suse)$ ]] || [[ "$OS_ID_LIKE" =~ ^(opensuse.*|tumbleweed|sles|suse)$ ]]; then
        LINEAGE="suse"
    fi

fi

# Final Fallback Engine (Handles unrecognized Linux distros, macOS, BSD, etc.)
if [[ -n "$LINEAGE" ]]; then 
    echo "OS lineage $LINEAGE detected from $OS_ID."
else
    UNAME_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    echo "$ICON_SEARCH Detecting Lineage by uname '$UNAME_OS' ..."
    if [[ -n "$OS" ]]; then
        # If /etc/os-release existed but didn't match our known trees
        LINEAGE="$OS"
    else
        # If /etc/os-release didn't exist at all (e.g. macOS, FreeBSD, old Android)
        OS="$UNAME_OS"
        LINEAGE="$UNAME_OS"
    fi
fi

if [[ -z "$LINEAGE" ]]; then
    echo "$ICON_FAIL Error: OS Lineage cannot be detected for OS '$OS'. "
    exit 1
fi

echo "$ICON_SUCCES Sensing Environment: $LINEAGE:$OS_VARIANT detected from $OS_ID."



UPDATE_CMD=""
INSTALL_CMD=""
ACCEPT_CMD=""
PIP_PKG=""
VENV_PKG=""
INSTALL_FLAGS=""
INSTALL_PIP="install_pip"
INSTALL_PIP_PARAMS=""
case "$LINEAGE" in
    alpine)
        UPDATE_CMD="apk update"
        INSTALL_CMD="apk add --no-cache"
        PIP_PKG="py3-pip"
        VENV_PKG="py3-virtualenv"
        ;;
    android)
        UPDATE_CMD="pkg update"
        INSTALL_CMD="pkg install -y"
        PIP_PKG="python3-pip"
        VENV_PKG="python3-venv"
        ;;
    atomic)
        UPDATE_CMD="rpm-ostree upgrade"
        INSTALL_CMD="rpm-ostree install --apply-live"
        PIP_PKG="python3-pip"
        VENV_PKG="python3-virtualenv"
        ;;
    arch) 
        UPDATE_CMD="pacman -Syu" 
        INSTALL_CMD="pacman -S --noconfirm" 
        PIP_PKG="python-pip"
        VENV_PKG="python-virtualenv"
        ;;
    debian)
        UPDATE_CMD="apt-get update --allow-releaseinfo-change"
        INSTALL_CMD="apt-get install -y --allow-unauthenticated" 
        PIP_PKG="python3-pip"
        VENV_PKG="python3-venv"
        ;;
    fedora)
        UPDATE_CMD="dnf check-update"
        INSTALL_CMD="dnf install -y"
		INSTALL_FLAGS='CARGO_BUILD_JOBS=1 RUSTFLAGS="-C codegen-units=1 -C opt-level=z"'
        PIP_PKG="python3-pip"
        VENV_PKG="python3-virtualenv"
        ;;
    gentoo)
        DEPENDENCIES=(sys-devel/bc sys-apps/gawk net-misc/curl app-arch/unzip sys-apps/sed app-misc/jq app-arch/zip app-misc/screen dev-lang/python dev-python/pip dev-python/virtualenv dev-libs/openssl)
        UPDATE_CMD="emerge-webrsync"
        INSTALL_CMD="emerge --ask=n --update --deep --autounmask=y --autounmask-write=y"
        ACCEPT_CMD="etc-update --automode -5"
        PIP_PKG="dev-python/pip"
        VENV_PKG="dev-python/virtualenv"
        ;;
    slackware)
        UPDATE_CMD="echo 'n' | slackpkg -default_answer=y update"
        INSTALL_CMD="echo 'y' | slackpkg -default_answer=yes install"
        INSTALL_PIP="install_pip_slackware"
        INSTALL_PIP_PARAMS="--without-pip"
        PIP_PKG="python3-pip"
        VENV_PKG="python3-venv"
        ;;
    redhat) 
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
        PIP_PKG="python3-pip"
        VENV_PKG="python3-virtualenv"
        ;;
    suse)
        UPDATE_CMD="zypper refresh"
        INSTALL_CMD="zypper install -y"
        PIP_PKG="python3-pip"
        VENV_PKG="python3-venv"
        ;;
    *) 
        echo -e "\n$ICON_FAIL Unknown OS ($LINEAGE). Install dependencies manually: ${DEPENDENCIES[*]}"
        exit 1 
        ;;
esac


# --- Detect System Python (The Foundation) ---
echo "$ICON_SEARCH Detecting System Python3..."
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



echo "$ICON_SEARCH Verifying Intelligence Layer dependencies..."

# Check if ALL core packages are already working in a single quick check
if $PYTHON_BIN -c "import sklearn, pandas, joblib, numpy" &> /dev/null; then
    echo "$ICON_SUCCES Intelligence Layer is fully active."
else
    if [ "$BACKPACK_DIR" == "SYSTEM" ]; then
         echo "$ICON_FAIL System Python is missing dependencies and I cannot sudo-install globally."
         exit 1
    fi
    
    echo "$ICON_DOWNLOAD Fetching required dependencies into the backpack..."
    
    # Run the safe, unified single-line installation
    $PIP_BIN install --prefer-binary \
        "scikit-learn<1.4.0; python_version < '3.10'" \
        "scikit-learn>=1.4.0; python_version >= '3.10'" \
        "numpy<2.0.0; python_version < '3.10'" \
        pandas joblib
fi



echo "$ICON_BEE Intelligence Layer is Online. The Bee's backpack is packed and ready for flight!"