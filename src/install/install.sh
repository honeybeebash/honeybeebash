#!/bin/bash
# HoneyBeeBash install script
# Syntax: install/install.sh {USER} {GROUP}
#
# Run from base directory of bee.sh tool.
# Installs to /opt/honeybeebash
# Symlinks from /usr/local/bin/bee and /usr/local/bin/monitor
#
# Configuration in $HOME/.config/honeybeebash
# Workspace in $HOME/.local/share/honeybeebash


echo -e "\n-------------------------------------------------------"
echo "           $ICON_BEE HONEYBEE BASH INSTALLER                  "
echo -e "-------------------------------------------------------\n"

# --- Obtain basic config ---
source "config-default/bee.conf-default"


# --- Legal Acknowledgement ---
echo "------------------------------------------------------------"
echo "Before proceeding, please review our Terms of Service and"
echo "Privacy Policy at: https://honeybeebash.com or in .md files"
echo "------------------------------------------------------------"

read -p "Do you accept these terms? (y/N): " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        echo "Terms accepted. Proceeding with installation..."
        ;;
    *)
        echo "Installation aborted. You must accept the terms to continue."
        exit 1
        ;;
esac


# --- Handle parameters ---
LEGACY_MODE="false"
while [[ $# -gt 0 ]]; do
    case $1 in
        --legacy) LEGACY_MODE="true"; shift 1  ;;
    esac
done


# --- Run from base dir ---
if [ -f "install.sh" ]; then
    echo "$ICON_BEE Changing to base dir of bee.sh for installation"
    cd ..
fi
chmod +x install/uninstall.sh
chmod +x install/install-scikit.sh
chmod +x install/uninstall-scikit.sh

 # Detect user
if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER="$(whoami)"
fi



# --- Requires user + group ---
echo " "
read -p "$ICON_INPUT Enter the username to install for (or Enter for $REAL_USER): " USER
USER=${USER:-}
if [[ -z "$USER" ]]; then
    USER="$REAL_USER"
    echo "$ICON_SUCCES Applying user $USER."
fi
if [[ -z "$USER" ]]; then
    echo "$ICON_FAIL User could not be detected. Enter the username."
fi

REAL_GROUP=$(id -gn $REAL_USER)

echo " "
read -p "$ICON_INPUT Enter the groupname (Enter for $REAL_GROUP): " GROUP
GROUP=${GROUP:-}
if [[ -z "$GROUP" ]]; then
    GROUP="$REAL_GROUP"
    echo "$ICON_SUCCES Applying user $USER."
fi
if [[ -z "$GROUP" ]]; then
    echo "$ICON_FAIL Group could not be detected. Enter the username."
fi

# --- Run with Sudo ---
if [ "$EUID" -ne 0 ]; then 
    echo "$ICON_FAIL Please run as root (use sudo)"
    exit 1
fi


# --- Package validation ---
echo "$ICON_SEARCH Auditing package..."  
HONEYBEE_PATHS=(
    "bee.sh"
    "monitor.sh"
    "detector.py"
    "config-default/bee.conf-default"
    "config-default/notify.conf-default"
    "config-default/default-dataset.csv"
    "config-default/BEE_PROFILE"
    "config-default/BEE_PLANNING"
    "config-default/BEE_RULES"
    "config-default/DEFAULT_INPUT"
    "config-default/RUN_FORBIDDEN"
    "config-default/RUN_ALWAYS"
    "config-default/RUN_NEVER"
    "config-default/RUN_REPLACE"
)
FAIL=""
for path in "${HONEYBEE_PATHS[@]}"; do
    if [ ! -f "$path" ]; then
        echo "ICON_CRITICAL Missing file: $path"
        FAIL="$ICON_FAIL There were one or more files missing. Check your download and try again."
    fi
done
echo "$ICON_SUCCES Package is valid"


# Check for at least one available LLM model and config
if [ $(ls -1 "models"/*.py 2>/dev/null | wc -l) -eq 0 ]; then
    echo "$ICON_FAIL Error: No .py LLM model files found in models/"
    FAIL="$ICON_FAIL There were one or more files missing. Check your download and try again."
    exit 1
fi
if [[ -n "$FAIL" ]]; then 
    echo $FAIL; 
    exit 1
fi


# --- Paths ---
BIN_DIR="/usr/local/bin"
BASE_DIR="/opt/honeybeebash"
BACKPACK_DIR="$BASE_DIR/backpack"


# --- User specific directories ---
TARGET_HOME=$(getent passwd "$USER" | cut -d: -f6)
echo "$ICON_DIR User directory detected at: $TARGET_HOME"
USER_CONFIG_DIR="$TARGET_HOME/.config/honeybeebash"
USER_LOCAL_DIR="$TARGET_HOME/.local/share/honeybeebash"


# --- Required common tools ---
DEPENDENCIES=(bc awk curl wget jq zip unzip dos2unix screen python3 python3-pip python3-venv openssl)


# --- Permissions & Cleaning ---
echo "$ICON_DIR Preparing scripts"
chmod +x install/*.sh tools/*.sh bee.sh
# CRLF Cleaning (Ensures scripts run on Linux if edited on Windows)
if [[ -f tools/crlf.sh ]]; then
    sed -i 's/\r$//' tools/crlf.sh
    tools/crlf.sh bee.sh monitor.sh install/* tools/* config/* models/* 
fi


# Directory creation
echo "$ICON_DIR Creating directories..."

echo "$ICON_DIR Creating $BASE_DIR for apllication bash scripts ..."
mkdir -p "$BASE_DIR"
chown $USER:$GROUP "$BASE_DIR"
chmod 750 "$BASE_DIR"

echo "$ICON_DIR Creating $USER_CONFIG_DIR for global configuration ..."
mkdir -p "$USER_CONFIG_DIR"
chown $USER:$GROUP "$USER_CONFIG_DIR"
chmod 750 "$USER_CONFIG_DIR"

echo "$ICON_DIR Creating $USER_LOCAL_DIR for LLM models and job files ..."
mkdir -p "$USER_LOCAL_DIR"
chown $USER:$GROUP "$USER_LOCAL_DIR"
chmod 750 "$USER_LOCAL_DIR"

mkdir -p "$USER_LOCAL_DIR/workspace"
chown $USER:$GROUP "$USER_LOCAL_DIR/workspace"
chmod 750 "$USER_LOCAL_DIR/workspace"

echo "$ICON_DIR Creating $BACKPACK_DIR for python modules ..."
mkdir -p "$BACKPACK_DIR"
chown $USER:$GROUP "$BACKPACK_DIR"
chmod 750 "$BACKPACK_DIR"

# Copy application
echo "$ICON_DIR Copying files..."

# Copy model files if 
mkdir -p "$USER_LOCAL_DIR/models"
chown $USER:$GROUP "$USER_LOCAL_DIR/models"
chmod 750 "$USER_LOCAL_DIR/models"

for src_item in "models/"*; do
    filename=$(basename "$src_item")
    dest_item="$USER_LOCAL_DIR/models/$filename"
    if [[ "$filename" == *".py"* ]] || [[ ! -e "$dest_item" ]]; then
        cp -f "$src_item" "$dest_item"
        chown -R $USER:$GROUP "$dest_item"
        chmod 640 "$dest_item" 
    fi
done


# Copying default run config
cp -f config-default/* "$USER_CONFIG_DIR/"
cp "$USER_CONFIG_DIR/bee.conf-default" "$USER_CONFIG_DIR/bee.conf"

# Copying default notify config
cp "$USER_CONFIG_DIR/notify.conf-default" "$USER_CONFIG_DIR/notify.conf"

chown $USER:$GROUP "$USER_CONFIG_DIR/"*
chmod 640 "$USER_CONFIG_DIR/"*

# Copy readme
cp ../*.md "$BASE_DIR/"
cp ../LICENSE "$BASE_DIR/"
cp ../gpl-3.0.txt "$BASE_DIR/"
chown $USER:$GROUP "$BASE_DIR/"*.md "$BASE_DIR/LICENSE" "$BASE_DIR/gpl-3.0.txt"

# Copy run files 
cp bee.sh "$BASE_DIR/bee.sh"
cp monitor.sh "$BASE_DIR/monitor.sh"
cp detector.py "$BASE_DIR/detector.py"
chown $USER:$GROUP "$BASE_DIR/bee.sh" "$BASE_DIR/monitor.sh" "$BASE_DIR/detector.py"
chmod +x "$BASE_DIR/bee.sh" "$BASE_DIR/monitor.sh"
chmod 644 "$BASE_DIR/detector.py"


# Copy tools
cp -rf tools "$BASE_DIR/"
chown $USER:$GROUP "$BASE_DIR/tools"
chown $USER:$GROUP "$BASE_DIR/tools/"*
chmod 750 "$BASE_DIR/tools"
chmod 750 "$BASE_DIR/tools/"*
chmod +x "$BASE_DIR/tools/"*


# Create the symlink so 'honeybee' works in the terminal and crontab
if [ -L "/usr/local/bin/bee" ]; then
    echo "A Symlink for '$BASE_DIR/bee.sh /usr/local/bin/bee' already exists. Skipping Symlink creation."
else
    echo "$ICON_DIR Creating SymLinks..."
    ln -sf $BASE_DIR/bee.sh /usr/local/bin/bee
    ln -sf $BASE_DIR/monitor.sh /usr/local/bin/monitor 
fi
echo " "


# --- OS Detection ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_FAMILY=$ID
else
    OS_FAMILY=$(uname -s | tr '[:upper:]' '[:lower:]')
fi
echo "$ICON_BEE Sensing Environment: $OS_FAMILY detected."

case "$OS_FAMILY" in
    ubuntu|debian|raspberrypi|kali|raspbian|pop)
        UPDATE_CMD="apt-get update --allow-releaseinfo-change"
        INSTALL_CMD="apt-get install -y --allow-unauthenticated" 
        ;;

    fedora)
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

    *)
        echo -e "\n$ICON_FAIL Unknown OS ($OS_FAMILY). Install dependencies manually: $DEPENDENCIES"
        exit 1 
        ;;
esac

# --- INTERACTIVE INSTALLATION ---


if [[ "$LEGACY_MODE" == "true" ]] && [ -f /etc/python3/EXTERNALLY-MANAGED ]; then
    echo "$ICON_CRITICAL Error: You requested --legacy, but this OS is Externally Managed."
    echo "Forcing Backpack mode to prevent installation failure."
    # Overwrite the flag logic here if you want to be extra safe
    LEGACY_MODE="false"
fi


# --- Verify installation tool ---
echo " "
echo "$ICON_PACKAGE Applying '$UPDATE_CMD; $INSTALL_CMD' for installing packages."
echo " "

read -p "$ICON_QUESTION Continue with installation ? (y/n): " confirm
confirm=${confirm,,} 
if [[ "$confirm" != "y" && "$confirm" != "" ]]; then
    echo -e "\n$ICON_FAIL Installation aborted."
    exit 1
fi


echo -e "\n\n$ICON_CRITICAL Installation in progress.. DO NOT INTERUPT UNTIL ASKED !\n\n"


# --- Surgical Dependency Check ---
echo "$ICON_PACKAGE Checking dependancies..."
check_and_install() {
    local tool=$1
    if ! command -v "$tool" &> /dev/null; then
        echo "$ICON_CRITICAL $tool missing. Fetching..."
        $UPDATE_CMD
        eval "$INSTALL_CMD $tool"
    else
        echo "$ICON_SUCCES $tool is ready."
    fi
}

# --- Tool Dependency Checks ---
for tool in "${DEPENDENCIES[@]}"; do
    check_and_install "$tool"
done


# --- Detect System Python (The Foundation) ---
echo "Detecting System Python3..."
SYSTEM_PYTHON=$(which python3)

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
    PIP_BIN=$(which pip3)
    if [[ -z "$PIP_BIN" ]]; then
        if $SYSTEM_PYTHON -m pip --version &> /dev/null; then
            PIP_BIN="$SYSTEM_PYTHON -m pip"
        else
            echo "$ICON_FAIL Legacy Pip not found. Try: sudo apt install python3-pip"
            exit 1
        fi
    fi

else
    echo "$ICON_HAND Backpack Mode Active: Preparing Virtual Environment."

    # INDEPENDENT REPAIR CHECK
    # We check if the 'venv' module can actually run. 
    # Debian's broken venv often returns a non-zero exit code here.
    if ! "$SYSTEM_PYTHON" -c "import ensurepip" &> /dev/null; then
        echo "$ICON_CRITICAL Python venv/ensurepip is missing. Probing for repair..."
        
        PY_VER=$($SYSTEM_PYTHON -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' | tr -d '[:space:]')
        VENV_PKG="python3.$PY_VER-venv"

        # Run silent
        sudo $UPDATE_CMD -y &> /dev/null
        
        # For debian check alternate package name
        if [[ "$OS_FAMILY" == "ubuntu" || "$OS_FAMILY" == "debian" ]]; then
            # Check if the specific versioned package exists in the repo
            if apt-cache show "$VENV_PKG" &> /dev/null; then
                echo "$ICON_DOWNLOAD Installing $VENV_PKG..."
                sudo -u "$USER" $INSTALL_CMD "$VENV_PKG"
            else
                # Fallback to the generic name if the versioned one isn't found
                echo "$ICON_DOWNLOAD $VENV_PKG not found, trying generic python3-venv..."
                sudo -u "$USER" $INSTALL_CMD python3-venv
            fi
        else
            sudo -u "$USER" $INSTALL_CMD python3-venv
        fi
    fi

    # CONSTRUCTION (Now that we know the module is there)
    if [[ ! -f "$BACKPACK_DIR/bin/python3" ]]; then
        echo "$ICON_PACKAGE Constructing Backpack with System-Link..."
        # We use the SYSTEM python to build the venv
        if ! sudo -u "$USER" $SYSTEM_PYTHON -m venv --system-site-packages "$BACKPACK_DIR"; then
            echo "$ICON_FAIL Venv creation failed even after repair attempt."
            exit 1
        fi
    fi
    
    chown -R $USER:$GROUP "$BACKPACK_DIR"

    # Set the Venv Binaries
    PYTHON_BIN="$BACKPACK_DIR/bin/python3"
    PIP_BIN="$BACKPACK_DIR/bin/pip3"

    # Bootstrap Pip inside the Venv if it's missing
    if [[ ! -f "$PIP_BIN" ]]; then
        echo "$ICON_PACKAGE Backpack pip missing. Bootstrapping..."
        sudo -u "$USER" $PYTHON_BIN -m ensurepip --default-pip &> /dev/null || \
        curl -sS https://bootstrap.pypa.io/get-pip.py | $PYTHON_BIN
    fi
fi

# --- Final Validation ---
if [[ ! -x $(echo $PYTHON_BIN | cut -d' ' -f1) ]]; then
    echo "$ICON_FAIL Final Python binary not executable: $PYTHON_BIN"
    exit 1
fi

echo "$ICON_SUCCES Active Python: $PYTHON_BIN"
echo "$ICON_SUCCES Active Pip: $PIP_BIN"



# --- Install SciKit Backpack ---
echo " "
ENABLE_SCIKIT="false"
read -p "$ICON_QUESTION Install SciKit for heuristic learning ? (y/n): " install_sci
if [[ "$install_sci" =~ ^[Yy]$ ]]; then
    sudo -u "$USER" install/install-scikit.sh "$USER" "$GROUP" "$LLM_MODEL"
    ENABLE_SCIKIT="true"
fi


# --- Store LAN API URL ---
echo " "
read -p "$ICON_QUESTION  Enter your LAN LLM Model API URL incl. port (or Enter to skip): " localai_url
localai_url=${localai_url:-}
sed -i '/SELECTED_MODEL_BASE_URL/d' "$USER_LOCAL_DIR/models/local.conf"
if [[ -n "$localai_url" ]]; then
    echo "SELECTED_MODEL_BASE_URL=\"$localai_url\"" >> "$USER_LOCAL_DIR/models/local.conf"
else
    echo "SELECTED_MODEL_BASE_URL=\"\"" >> "$USER_LOCAL_DIR/models/local.conf"
    echo "You can set this later in $USER_LOCAL_DIR/models/local.conf"
fi


# --- Select the prefered default model ---
LLM_MODEL=""
echo " "
echo -e "\n$ICON_QUESTION Choose the default LLM model:"
echo "1) LOCAL = Use a local or LAN LLM model "
echo "2) GOOGLE GEN = Apply the generative Google API"
echo "3) GOOGLE API (advised) = Apply the Google AI API (requires google-genai)"
read -p "Select [1-3] or Quit: " model_choice
case $model_choice in
    1) LLM_MODEL="local"  ;;
    2) LLM_MODEL="geminiflash"  ;;
    3) LLM_MODEL="googleapi"  ;;
esac
if [[ -z "$LLM_MODEL" ]]; then
    echo -e "\n$ICON_FAIL Thats daft. No model chosen. Exiting\n"
    exit 0
fi


# --- If chosen install google API ---
if [[ "$LLM_MODEL" == "googleapi" ]]; then
    echo " "
    read -p "$ICON_QUESTION Continue to install required google-genai into the Backpack? (y/n): " install_genai
    if [[ "$install_genai" =~ ^[Yy]$ ]]; then
        echo "$ICON_DOWNLOAD Fetching Google Generative AI nectar..."
        if sudo -u "$USER" "$PIP_BIN" install -q -U google-genai; then
            echo "$ICON_SUCCES google-genai integrated into the backpack."
        else
            echo -e "\n$ICON_FAIL Failed to install google-genai.\n"
        fi
    fi
fi


# --- Store Gemini API key ---
echo " "
read -p "$ICON_INPUT Enter your Gemini API key (or Enter to skip): " gemini_key
gemini_key=${gemini_key:-}
sed -i '/GEMINI_API_KEY/d' "$USER_LOCAL_DIR/models/googleapi.conf"
sed -i '/GEMINI_API_KEY/d' "$USER_LOCAL_DIR/models/geminiflash.conf"
echo "GEMINI_API_KEY=\"$gemini_key\"" >> "$USER_LOCAL_DIR/models/googleapi.conf"
echo "GEMINI_API_KEY=\"$gemini_key\"" >> "$USER_LOCAL_DIR/models/geminiflash.conf"


# --- Choose Risk mitigation automation mode ---
MODE_AUTOMATIC=""
echo " "
echo -e "\n$ICON_QUESTION Choose the prefered automation mode:"
echo "1) RESTRICTIVE = Automate on 0 score only"
echo "2) PERMISSIVE (standard) = Automate on <10% threat score"
echo "3) MANUAL = No automation"
read -p "Select [1-3] or Quit: " automation_mode
case $automation_mode in
    1) MODE_AUTOMATIC="RESTRICTIVE"  ;;
    2) MODE_AUTOMATIC="PERMISSIVE"  ;;
    3) MODE_AUTOMATIC="MANUAL"  ;;
esac
if [[ -z "$MODE_AUTOMATIC" ]]; then
    echo -e "\n$ICON_FAIL automation mode chosen. Exiting\n"
    exit 0
fi


# --- Default Text Editor ---
if [[ -n "$EDITOR" ]]; then
    DEFAULT_EDITOR="$EDITOR"
elif [[ -x "/usr/bin/nano" ]]; then
    DEFAULT_EDITOR="/usr/bin/nano"
elif [[ -x "/usr/bin/vim" ]]; then
    DEFAULT_EDITOR="/usr/bin/vim"
elif [[ -x "/usr/bin/vi" ]]; then
    DEFAULT_EDITOR="/usr/bin/vi"
else
    # Fallback to whatever 'vi' is in the PATH
    DEFAULT_EDITOR="vi"
fi

# --- Prefered Text Editor ---
echo " "
read -p "$ICON_INPUT Enter your preferred text editor (Enter for $DEFAULT_EDITOR): " user_editor
user_editor=${user_editor:-/usr/bin/nano}
echo "Selected editor : $user_editor"

# --- Store username in bee.conf ---
echo " "
echo "$ICON_INFO Contributing rulesets to HiveHub requires an API KEY."
echo "Join for free and Register to receive the API KEY."
echo "https://honeybeebash.com/hivehub"
echo " "
read -p "$ICON_INPUT Enter your HiveHub --export username (Enter to skip) : " user_email
user_email=${user_email:-}


# --- Store HiveHub API key ---
echo " "
read -p "$ICON_INPUT Enter your HiveHub API key (Enter to skip) : " user_key
user_key=${user_key:-}


# --- Append new keys to old configs ---
MODEL_DIR="$USER_LOCAL_DIR/models"
DEFAULT_KEY1='SELECTED_MODEL_MAX_CHARACTERS'
DEFAULT_VAR1='SELECTED_MODEL_MAX_CHARACTERS="4000000"'

if [ -d "$MODEL_DIR" ] && ls "$MODEL_DIR"/*.conf &>/dev/null; then
    for MODEL_FILE in "$MODEL_DIR"/*.conf; do
        filename=$(basename "$MODEL_FILE")

        if ! grep -q "^[[:space:]]*$DEFAULT_KEY1=" "$MODEL_FILE" 2>/dev/null; then
            echo "Adding key $DEFAULT_KEY1 to : $filename"
            sed -i -e '$a\' "$MODEL_FILE" 2>/dev/null || echo "" >> "$MODEL_FILE"
            echo "$DEFAULT_VAR1" >> "$MODEL_FILE"
        else
            echo "Skipping $filename: Variable already exists."
        fi
    done
else
    echo "Error: Model directory does not exist or no .conf files were found in $MODEL_DIR"
fi


# --- Notification configuration ---
echo " "
echo "If you wish to configure to enable email configurations continue below."
echo "You can enable this later by completing \$HOME/.config/honeybeebash/notify.conf"

echo " "
read -p "$ICON_QUESTION Configure notifications by mail ? (y/n): " configure_email
if [[ "$configure_email" =~ ^[Yy]$ ]]; then

    read -p "$ICON_INPUT Enter the hostname of your mailserver : " host
    host=${host:-}

    read -p "$ICON_INPUT Enter the port number (Enter for 587) : " port
    port=${port:-}
    if [[ -z "$port" ]]; then
        port="587"
    fi

    read -p "$ICON_INPUT Enter the account username : " username
    username=${username:-}

    read -p "$ICON_INPUT Enter the account password : " password
    password=${password:-}
    
    # --- Writing to notify.conf ---
    cat << EOF >> $USER_CONFIG_DIR/notify.conf

# --- Account Configuration ---

our \$smtp_server = '$host'; 
our \$smtp_port   = $port;                      # Use 587 for standard authenticated submission
our \$smtp_user   = '$username';     # Your mail server username
our \$smtp_pass   = '$password';     # Your mail server password

1; # Crucial success return value
EOF

    echo "✅ Configuration written to notify.conf successfully."

else
    # Write default to config
    cat << EOF >> $USER_CONFIG_DIR/notify.conf

# --- Account Configuration ---

our \$smtp_server = ''; 
our \$smtp_port   = ;       # Use 587 for standard authenticated submission
our \$smtp_user   = '';     # Your mail server username
our \$smtp_pass   = '';     # Your mail server password

1; # Crucial success return value
EOF

fi



# --- Choose sudo mode ---
APPLY_SUDO="false"
echo " "
read -p "$ICON_QUESTION Allow Bee to run as sudo ? (y/n): " sudo_allowed
if [[ "$sudo_allowed" =~ ^[Yy]$ ]]; then
    APPLY_SUDO="true"
fi


# --- Append choices to config ---
echo " "
echo "$ICON_DIR Updating configuration..."

echo "LEGACY_MODE=\"$LEGACY_MODE\"" >> "$USER_CONFIG_DIR/bee.conf"

echo "ENABLE_SCIKIT=\"$ENABLE_SCIKIT\"" >> "$USER_CONFIG_DIR/bee.conf"
    
echo -e "\n# Selected LLM model" >> "$USER_CONFIG_DIR/bee.conf"
echo "LLM_MODEL=\"$LLM_MODEL\"" >> "$USER_CONFIG_DIR/bee.conf"

echo -e "\n# Automatic execution" >> "$USER_CONFIG_DIR/bee.conf"
echo "# RESTRICTIVE = Automate on 0 score only" >> "$USER_CONFIG_DIR/bee.conf"
echo "# PERMISSIVE = Automate on <10% threat score" >> "$USER_CONFIG_DIR/bee.conf"
echo "# MANUAL = No automation" >> "$USER_CONFIG_DIR/bee.conf"
echo "MODE_AUTOMATIC=\"$MODE_AUTOMATIC\"" >> "$USER_CONFIG_DIR/bee.conf"
echo "APPLY_SUDO=\"$APPLY_SUDO\"" >> "$USER_CONFIG_DIR/bee.conf"
echo "" >> "$USER_CONFIG_DIR/bee.conf"

echo "TEXT_EDITOR=\"$user_editor\"" >> "$USER_CONFIG_DIR/bee.conf"

echo "# HiveHub Configuration" >> "$USER_CONFIG_DIR/bee.conf"
echo "HIVEHUB_USER=\"$user_email\"" >> "$USER_CONFIG_DIR/bee.conf"

echo "HIVEHUB_API_KEY=\"$user_key\"" >> "$USER_CONFIG_DIR/bee.conf"
echo "" >> "$USER_CONFIG_DIR/bee.conf"



# --- Installation test ---
echo " "
echo "$ICON_TEST Testing HoneyBee installation..."
VERSION_CHECK=$(bee --version 2>&1)
if [[ $? -eq 0 && "$VERSION_CHECK" == *"HoneyBee Bash version"* ]]; then
    echo -e "\n$ICON_SUCCES HoneyBee Bash $VERSION_CHECK has been installed.\n"
    
    echo "$ICON_LAUNCH The commands 'bee' and 'monitor' are now available."
    echo "Type 'bee --test' for a test run "
    echo "or 'sudo bee' for the default analysis job."
    echo "Type 'bee --help' for more information."
    echo -e "\n$ICON_BEE You can now use bee."
else
    echo -e "\n$ICON_FAIL Error: Installation test failed."
    echo "Version response : $VERSION_CHECK"
    exit 1
fi

# Tip on joining the venv 
if [ "$PYTHON_FROM" != "SYSTEM" ]; then
    if [[ -f "/opt/honeybeebash/backpack/bin/activate" ]]; then
        echo " "
        echo "Enter the Virtual Environment to use Bee." 
        echo "source \"/opt/honeybeebash/backpack/bin/activate\""
        echo " "
    fi
fi


exit 0
