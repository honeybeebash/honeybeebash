#!/usr/bin/env bash

set -e
set -u
if set -o | grep -q pipefail; then
    set -o pipefail
fi


# ------------------------------------------------------------------------------
#         '\     /`
#      ___  \___/  ___      HONEYBEEBASH / BEE.SH 
#     /   \ (0 0) /   \     _________________________________
#    |  M  |  X  |  M  |    AUTONOMOUS MAINTENANCE
#    |_____/ @@@ \_____|    QUAD-TIERED RISK MIGITATION 
#            @@@@@          SIGNATURE + HEURISTIC + LLM
#             @@@           _________________________________
#              V            SCIKIT PANDA SECURITY RESEARCH
# ------------------------------------------------------------------------------
# PROJECT:   BEE.SH (The Buzzy Bash Agent)
# PURPOSE:   Autonomous System Remediation
# ------------------------------------------------------------------------------
# STRATEGY:  Active trainable maintenance loop for Linux systems
# ARCH:      Quad-Tiered Risk Mitigation (Signature + Heuristic + LLM)
# ENGINE:    Scikit-Learn (RandomForest) + TF-IDF Vectorization
# BACKENDS:  Local (CSV), LAN (Ollama), Cloud (Gemini)
# SOURCE:    Inspired by Open Source Community
# ------------------------------------------------------------------------------
# @version   1.0.0
# @author    M.D.P de Clerck (mike@clerck.nl)
# @license   GNU General Public License version 3
# ------------------------------------------------------------------------------
# Example usage:
# bee                                       - Continue existing job or start (first) default job 
# bee "Skip mail logs."                     - Continue with tip
# bee new "job_name"                        - Start new job with default prompt
# bee new "Custom prompt" "job_name"        - Start new job with custom prompt
# bee "How much RAM do i have ?"            - End with a ? character to ask a system related question
# bee --ask "Where to pinguins live ?"      - Ask a general question report answer and exit
# bee --import=zombie-hunt                  - Import and run the version lamp of the service-check job 
# bee --forget "cmd"                        - Run the unlearn script for a specific command
# bee --merge                               - Merge job rules with global rules



# --- If sudo active then detect real user for profiles ---
if [ -n "${SUDO_USER:-}" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER="$(whoami)"
fi

REAL_GROUP=$(id -gn $REAL_USER)
if [[ -z "$REAL_GROUP" ]]; then
    REAL_GROUP="$REAL_USER"
fi

REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
if [[ -z "$REAL_HOME" ]]; then
    REAL_HOME="$HOME"
fi

# --- Paths ---
BASE_DIR="/opt/honeybeebash"
BACKPACK_DIR="$BASE_DIR/backpack"

# --- User specific paths ---
USER_CONFIG_DIR="$REAL_HOME/.config/honeybeebash"
USER_LOCAL_DIR="$REAL_HOME/.local/share/honeybeebash"


# --- Work vars --- 
BEE_VERSION="1.0.0"
JOB_DIR=""
PACKAGE_VERSION=""
DO_SILENT="false"
VERBOSE_LEVEL="0"
LEGACY_MODE="false"
BEE_DELAY=5

IS_NEW_JOB=false
JOB_NAME="default"
TIMEOUT=0
COMMAND=""
HIVE_CHANGED="true" # Update first
PARAM_PROMPT=""
PARAM_JOB=""
RUNNING_COMMAND=""
CYCLE=1
APPLY_SUDO="false"

QUEEN_IP=""
QUEEN_PORT=""
SECRET_KEY=""

MODEL=""
SELECTED_MODEL_NAME="" 
SELECTED_CONTEXT_SIZE=""
SELECTED_MODEL_BASE_URL=""
GEMINI_API_KEY=""

end_program() {
    local ECODE="${1:-0}"
    local L1="${2:-}"
    local L2="${3:-}"
    local MOOD="${4:-}"
    if [[ -n "$L1" ]]; then 
        if [[ "$ECODE" -gt 0 ]]; then
            echo -e "Error: $L1 $MOOD";
        else
            echo -e "$L1 $MOOD"; 
        fi
    fi
    if [[ -n "$L2" ]]; then echo -e "$L2"; fi
    if [[ -d "$JOB_DIR" ]]; then
        rm -f "$JOB_DIR/PID"
    fi
    exit $ECODE
}

trap "end_program; exit" INT TERM EXIT


show_help() {
    echo "
  '\     /\`
    \___/      HONEYBEEBASH / BEE.SH
   ( 0 0 )     ---------------------------------
      X        AUTONOMOUS MAINTENANCE ENGINE

Usage: ./bee.sh "[PROMPT]" [JOB_NAME]:[VERSION] [OPTIONS]
Default action: Continues last job.

CORE COMMAND OPTIONS:
  --help                  Show this help information
  --version               Show the version number of Bee
  --timeout=n             Override default LLM timeout (seconds). For testing and tuning.
  --delay=n               Set the amount of seconds to wait between LLM requests.
  --verbose=0-2           Show less output (0) or more (2) [CONFLICT] [WARNING] [NOTICE]
  --silent                Show no output  
  --debug=0-3             Set debug level (0 none - 3 full)  
  --update                Obtains the latest version and installs the scripts only for immediate use
  --exit                  Exit after processing parameter commands

HIVEHUB OPERATION OPTIONS:
  --review=JOB            Echo out all files of the global and job ruleset for review.
  --importall=JOB         Import all as job and global default dataset. Usually just run once.
  --import=JOB            Import the bee profile and job ruleset. Regular for new jobs types.
  --importrules=JOB       Import the job ruleset (job specific) only and keep your profile.
  --importglobal=JOB      Import the global bee profile and run rules (distro specific).
  --importglobalrules=JOB Import the global run rules (distro specific) only and keep profile.
  --exportall=JOB         Export all including the bee profile, global and job ruleset.
  --export=JOB            Export only the bee profile and ruleset from that job.
  --exporttext="TEXT"     Provide a text description for your export package.
  --exportusername=email  Set and store your obtained HiveHub username
  --exportapikey=key      Set and store your obtained HiveHub API key
  --merge                 Add the job ruleset to local global default ruleset (appending).
  --mergehive             Promote job ruleset to Hive global set [Requires Hive tool]

DATA & RULE OPTIONS:
  --rebuild               Re-train the SciKit-Learn datamodel
  --forget=\"CMD\"         Remove a command from the job rulesets

LLM MODEL OPTIONS:
  --model=MODEL           Chante active LLM resource (local, geminiflash, googleapi)
  --googleapikey=key      Set and store your obtained Google API key

JOB MANAGEMENT OPTIONS:
  --ask [QUESTION]        Ask a single general question to the LLM
  --new [JOB]             Start new job & clear logs (or use 'new' as 1st arg)
  --jobs                  Lists all local available jobs
  --drop=JOB              Permanently delete a specific job directory
  --clone]JOB             Copy a specific local dataset to a the one specified in --target 
  --target=JOB            The target JOB:VERSION of the cloned dataset
  --clearrules            Clear Run rules (Always/Never/Replace) for current job
  --clean                 Clear current job logs
"
}




if [[ ! -d "$USER_CONFIG_DIR" ]] || [[ ! -d "$USER_LOCAL_DIR" ]]; then
    end_program 1 "No config or workspace could be detected. Is this the right user ? If so then reinstall for this user."
fi



# --- PARAMETER PARSER ---
DEBUG_LEVEL=0
VERBOSE_LEVEL=0
TEST_MODE="false"
EXPORT_SET=""
EXPORT_API_KEY=""
EXPORT_API_USERNAME=""
EXPORT_TEXT=""
IMPORT_SET=""
DROP_JOB=""
DO_BEE_DELAY=""
DO_CAP_RESPONSE="false"
DO_UPDATE="false"
DO_EXPORT="false"
DO_IMPORT="false"
DO_FORGET="false"
DO_MERGE="false"
DO_DROP="false"
DO_MODEL="false"
DO_REVIEW="false"
DO_CLEANUP="false"
DO_CLEARRULES="false"
DO_CLONE="false"
DO_ASKONCE="false"
DO_EXIT="false"
LOOSE_COUNT=0
while [[ $# -gt 0 ]]; do

    case $1 in
        ?|--help)    show_help; end_program ;;
        --version)   echo "HoneyBee Bash version $BEE_VERSION"; end_program 0  ;;
        --test)      TEST_MODE="true";  shift  ;;
        --verbose=*) VERBOSE_LEVEL="${1#*=}";  shift 1 ;;
        --silent)    DO_SILENT="true" shift 1 ;; 
        --debug=*)
            DEBUG_LEVEL="${1#*=}"
            DEBUG_LEVEL="${DEBUG_LEVEL//[!0-9]/}"
            DEBUG_LEVEL="${DEBUG_LEVEL:-0}"
            shift 1
            ;;
        --timeout=*) TIMEOUT="${1#*=}"; shift 1  ;;
        --delay=*) DO_BEE_DELAY="${1#*=}"; shift 1  ;;
        --capresponse=*) 
            DO_CAP_RESPONSE="true"
            DO_MAX_CAP_RESPONSE="${1#*=}"; 
            shift 1  
            ;;

        --update) DO_UPDATE="true"; shift 1 ;;

        --ask) DO_ASKONCE="true"; shift 1  ;;    

        new|--new) IS_NEW_JOB=true; shift 1 ;;
        --forget)
            DO_FORGET="true"
            FORGET_CMD=$2
            shift 2
            ;;
        --drop=*)
            # Delete the job work directory
            DROP_JOB="${1#*=}"
            DO_DROP="true" 
            shift 1
            ;;
        --merge) DO_MERGE="true"; shift 1 ;;
        --clone=*)
            # Delete the job work directory
            CLONE_JOB="${1#*=}"
            DO_CLONE="true" 
            shift 1
            ;;
        --target=*)
            # Set the target for the clone
            TARGET_JOB="${1#*=}"
            shift 1
            ;;
        --jobs)
            DIRS=()
            for d in "$USER_LOCAL_DIR/workspace"/*/; do
                [[ -d "$d" ]] || continue
                DIRS+=("${d%/}")
            done
            if [ ${#DIRS[@]} -eq 0 ]; then
                echo "No jobs found."
            fi
            for i in "${!DIRS[@]}"; do
                printf "%3d) %s\n" "$((i + 1))" "$(basename "${DIRS[$i]}")"
            done
            end_program
            ;;

        --clean)      DO_CLEANUP="true"; shift 1 ;;
        --clearrules) DO_CLEARRULES="true"; shift 1 ;;
        --rebuild)    update_hive "rebuild" 0 0; remove_hive_model; shift 1 ;;

        --model=*)
            # Set the model in the configuration
            DO_MODEL="${1#*=}"
            shift 1
            if [[ -z "$DO_MODEL" ]]; then
                end_program 1 "Missing model name. Syntax: --model=googleapi"
            fi
            if [[ ! -f "$USER_LOCAL_DIR/models/$DO_MODEL".py ]]; then
                end_program 1 "Model not found in $USER_LOCAL_DIR/models"
            fi
            LLM_MODEL="$DO_MODEL"
            sed -i '/LLM_MODEL/d' "$USER_CONFIG_DIR/bee.conf"
            echo "LLM_MODEL=\"$LLM_MODEL\"" >> "$USER_CONFIG_DIR/bee.conf"
            echo "[NOTICE] LLM model changed to $LLM_MODEL"
            ;;    
        --googleapikey=*)
            EXPORT_API_KEY="${1#*=}"
            if [[ -z "$EXPORT_API_KEY" ]]; then
                end_program 1 "Missing API KEY value. Syntax: --googleapikey=key"
            fi
            EXPORT_API_KEY=${EXPORT_API_KEY:-}
            sed -i '/GEMINI_API_KEY/d' "$USER_LOCAL_DIR/models/googleapi.conf"
            sed -i '/GEMINI_API_KEY/d' "$USER_LOCAL_DIR/models/geminiflash.conf"
            echo "GEMINI_API_KEY=\"$EXPORT_API_KEY\"" >> "$USER_LOCAL_DIR/models/googleapi.conf"
            echo "GEMINI_API_KEY=\"$EXPORT_API_KEY\"" >> "$USER_LOCAL_DIR/models/geminiflash.conf"
            echo "[NOTICE] $ICON_BEE Google API Key changed and stored."
            shift
            ;; 

        --review) DO_REVIEW="true"; shift 1 ;;
        
        --exportall=*)
            # Export all including the bee profile, global and job ruleset.
            EXPORT_SET="${1#*=}"
            if [[ -z "$EXPORT_SET" ]]; then
                end_program 1 "Missing jobname. Syntax: --export=jobname"
            else
                DO_EXPORT="all"
            fi
            shift
            ;;
        --export=*)
            # Export only the bee profile and ruleset of that job.
            EXPORT_SET="${1#*=}"
            if [[ -z "$EXPORT_SET" ]]; then
                end_program 1 "Missing jobname. Syntax: --export=jobname"
            else
                DO_EXPORT="job"
            fi
            shift
            ;;
        --exportusername=*)
            EXPORT_API_USERNAME="${1#*=}"
            if [[ -z "$EXPORT_API_USERNAME" ]]; then
                end_program 1 "Missing API KEY value. Syntax: --exportapikey=key"
            fi
            sed -i '/HIVEHUB_USER/d' "$USER_CONFIG_DIR/bee.conf"
            echo "HIVEHUB_USER=\"$EXPORT_API_USERNAME\"" >> "$USER_CONFIG_DIR/bee.conf"
            echo "[NOTICE] HiveHub API Username changed and stored."
            end_program
            ;;
        --exportapikey=*)
            EXPORT_API_KEY="${1#*=}"
            if [[ -z "$EXPORT_API_KEY" ]]; then
                end_program 1 "Missing API KEY value. Syntax: --exportapikey=key"
            fi
            sed -i '/HIVEHUB_API_KEY/d' "$USER_CONFIG_DIR/bee.conf"
            echo "HIVEHUB_API_KEY=\"$EXPORT_API_KEY\"" >> "$USER_CONFIG_DIR/bee.conf"
            echo "[NOTICE] HiveHub API Key changed and stored."
            end_program
            ;;
        --exporttext=*)
            EXPORT_TEXT="${1#*=}"
            shift
            ;;
        --import=*)
            # Import only the bee profile and ruleset from that job.
            IMPORT_SET="${1#*=}"
            if [[ -z "$IMPORT_SET" ]]; then
                end_program 1 "Missing jobname. Syntax: --export=jobname"
            else
                DO_IMPORT="job"
            fi
            shift
            ;;
        --importall=*)
            # Import the global+job profile and ruleset from that job.
            IMPORT_SET="${1#*=}"
            if [[ -z "$IMPORT_SET" ]]; then
                end_program 1 "Missing jobname. Syntax: --export=jobname"
            else
                DO_IMPORT="all"
            fi
            shift
            ;;
        --importrules=*)
            # Import the global+job profile and ruleset from that job.
            IMPORT_SET="${1#*=}"
            if [[ -z "$IMPORT_SET" ]]; then
                end_program 1 "Missing jobname. Syntax: --export=jobname"
            else
                DO_IMPORT="jobrules"
            fi
            shift
            ;;
        --importglobal=*)
            # Import the global+job profile and ruleset from that job.
            IMPORT_SET="${1#*=}"
            if [[ -z "$IMPORT_SET" ]]; then
                end_program 1 "Missing jobname. Syntax: --export=jobname"
            else
                DO_IMPORT="globalrules"
            fi
            shift
            ;;

        --exit)
            # Exit after parameter handling (maintenance task)
            DO_EXIT="true"
            shift 1
            ;;
        -*)
            end_program 1 "Unknown option: $1"
            ;;
        *)
            # LOOSE STRING LOGIC
            if [ $LOOSE_COUNT -eq 0 ]; then
                PARAM_PROMPT="$1"
                LOOSE_COUNT=1
            elif [ $LOOSE_COUNT -eq 1 ]; then
                PARAM_JOB="$1"
                LOOSE_COUNT=2
            fi
            shift 1
            ;;
    esac
done


# Debug essentials
CYAN=""
NC=""
textdebug() {
    local TYPE="${1:-0}"
    local L1="${2:-}"
    if [[ "$DEBUG_LEVEL" -gt "$TYPE" ]]; then 
        echo -e "${CYAN}[DEBUG]:${NC} $L1"; 
    fi
}

# --- Early catch for Bee update
if [[ "$DO_UPDATE" == "true" ]]; then
    textdebug 0 "Updating Bee ..."
    DOWNLOAD="https://honeybeebash.com/downloads/honeybeebash.zip"

    cd $HOME
    if [[ -f "honeybeebash.zip" ]]; then
        rm -f honeybeebash.zip
    fi

    # Download zip
    textdebug 2 "Downloading ZIP ..."
    wget $DOWNLOAD
    if [[ ! -f "honeybeebash.zip" ]]; then
        end_program 1 "$ICON_FAIL Could not download from $DOWNLOAD"
    fi

    # Unpack
    textdebug 2 "Unpacking ..."
    unzip -o honeybeebash.zip
    if [[ ! -f "honeybeebash/src/bee.sh" ]]; then
        end_program 1 "$ICON_FAIL Could not unpack the download to $HOME"
    fi

    # Copy files
    textdebug 2 "Updating Bee scripts ..."
    cd honeybeebash/src
    dos2unix bee.sh monitor.sh detector.py tools/*
    cp -f bee.sh /opt/honeybeebash/bee.sh
    cp -f monitor.sh /opt/honeybeebash/monitor.sh
    cp -f detector.py /opt/honeybeebash/detector.py
    cp -f tools/* /opt/honeybeebash/tools/

    # Compare config and warn to install ?

    VERSION_CHECK=$(bee --version 2>&1)
    if [[ $? -eq 0 && "$VERSION_CHECK" == *"HoneyBee Bash version"* ]]; then
        echo -e "\nHoneyBee Bash scripts have been updated to $VERSION_CHECK.\n"
    fi

    # Exit with "Restart Bee" message
    end_program 0 "Use the new Bee and Monitor now. Or run install/install.sh for a full update."
fi



# --- Detect System Python (The Foundation) ---
textdebug 2 "Detecting System Python3..."
SYSTEM_PYTHON=$(which python3)

if [[ -z "$SYSTEM_PYTHON" ]]; then
    end_program 1 "$ICON_FAIL Python3 not found on system. Install it first." 
fi

# --- Branching Logic (Legacy vs Backpack) ---
if [[ "$LEGACY_MODE" == "true" ]]; then
    textdebug 2 "$ICON_PACKAGE Legacy Mode Active: Using Global Environment."
    PYTHON_BIN="$SYSTEM_PYTHON"
    
    # Locate Global Pip
    PIP_BIN=$(which pip3)
    if [[ -z "$PIP_BIN" ]]; then
        if $SYSTEM_PYTHON -m pip --version &> /dev/null; then
            PIP_BIN="$SYSTEM_PYTHON -m pip"
        else
            end_program 1 "$ICON_FAIL Legacy Pip not found. Try: sudo apt install python3-pip"
        fi
    fi

else
    textdebug 2 "Backpack Mode Active."
    # Set the Venv Binaries
    PYTHON_BIN="$BACKPACK_DIR/bin/python3"
    PIP_BIN="$BACKPACK_DIR/bin/pip3"
fi
# --- Final Validation ---
if [[ ! -x $(echo $PYTHON_BIN | cut -d' ' -f1) ]]; then
    end_program 1 "$ICON_FAIL Final Python binary not executable: $PYTHON_BIN"
fi

textdebug 0 "Active Python: $PYTHON_BIN"
textdebug 0 "Active Pip: $PIP_BIN"


# Path detection (Load BASE_DIR from config or current path)
textdebug 0 "Detect Paths for user $REAL_USER:$REAL_GROUP"
WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$USER_CONFIG_DIR/bee.conf" ]]; then
    CONFIG_DIR="$USER_CONFIG_DIR"
    CONFIG_FILE="$CONFIG_DIR/bee.conf"
    DEFAULT_CONFIG_FILE="$USER_CONFIG_DIR/bee.conf-default"
    source "$CONFIG_FILE"
else
    end_program 1 "Missing config file $USER_CONFIG_DIR/bee.conf"
fi
WORKSPACE_DIR="$USER_LOCAL_DIR/workspace"

# Load config
textdebug 0 "Load config..."
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        if [[ "$VERBOSE_LEVEL" -ge "2" ]]; then
            echo "[ERROR] No bee.conf found. Generating from default settings."
        fi
        cp -f "$DEFAULT_CONFIG_FILE" "$CONFIG_FILE"
        source "$CONFIG_FILE"        
    else
        end_program 1 "No config/bee.conf or $DEFAULT_CONFIG_FILE found. Check your files or reinstall Bee." 
    fi
fi
if [[ "$VERBOSE_LEVEL" -ge "2" ]]; then
    echo "[NOTICE] $ICON_BEE Settings loaded from $CONFIG_FILE"
fi
export BEE_HOME="$BASE_DIR"


# If we have a TTY, we use it to remember the job for this specific window.
# If no TTY (Cron/Background), we use the PID to ensure isolation.
# JOB_NAME=default is configured in bee.conf 
textdebug 0 "Detect TTY for last JOB..."
if [ -t 0 ]; then
    # We are in an interactive terminal
    TTY_ID=$(tty | sed 's/\//_/g') 
    JOB_SESSION_FILE="$HOME/.bee_session${TTY_ID}"

    # Overwrite current job for this TTY, else load from TTY
    if [[ -n "$PARAM_JOB" ]]; then
        JOB_NAME="${PARAM_JOB%%:*}"
        JOB_NAME=${JOB_NAME,,}
        PACKAGE_VERSION="${PARAM_JOB#*:}"
        PACKAGE_VERSION=${PACKAGE_VERSION,,}
        if [[ -z "$PACKAGE_VERSION" ]] || [[ "$PACKAGE_VERSION" == "$JOB_NAME" ]]; then
            PACKAGE_VERSION="default"
        fi
        textdebug 0 "Overrule current job as $JOB_NAME:$PACKAGE_VERSION"
        echo "$JOB_NAME:$PACKAGE_VERSION" > "$JOB_SESSION_FILE"

    elif [[ -n "$JOB_SESSION_FILE" && -f "$JOB_SESSION_FILE" ]]; then
        # Resume: ./bee.sh (reads the TTY-specific session)
        textdebug 0 "Loaded Job from session file as $JOB_NAME"
        SESSION_JOB=$(cat "$JOB_SESSION_FILE")
        JOB_NAME="${SESSION_JOB%%:*}"
        JOB_NAME=${JOB_NAME,,}
        PACKAGE_VERSION="${SESSION_JOB#*:}"
        PACKAGE_VERSION=${PACKAGE_VERSION,,}
        if [[ -z "$PACKAGE_VERSION" ]] || [[ "$PACKAGE_VERSION" == "$JOB_NAME" ]]; then
            PACKAGE_VERSION="default"
        fi
    fi
else
    # We are in Cron or a pipe - No persistence needed/wanted
    # JOB NAME is given as parameter in the call as : cd bee; ./bee.sh "continue" "job_name"
    JOB_SESSION_FILE=""
    textdebug 0 "No session file, Job set to $JOB_NAME"
fi
if [[ -z " $JOB_NAME" ]]; then
    end_program 1 "Could not select Job."
fi



#-------------------------------------------------------------------------------
# @function   beelog
# @description Echos a date with input string to the job BEELOG
# @param      $1  Notice message
# @returns    Nothing
#-------------------------------------------------------------------------------
beelog() {
    local L1="${1:-}"
    if [[ "$L1" == "" ]]; then
        return
    fi
    if [[ -d "$JOB_DIR" ]]; then
        echo -e "$(date +%T): $L1" >> "$JOB_DIR/BEELOG"
    fi
}

#-------------------------------------------------------------------------------
# @function   get_eyes
# @description Maps a semantic mood to ASCII eye characters.
# @param      $1  Mood string.
# @returns    A 3-character eye string (e.g., "0 0").
#-------------------------------------------------------------------------------
get_eyes() {
    local TYPE="${1:-}"
    case "$TYPE" in
        "rolling")  echo "e e" ;; # Annoyed
        "angry")    echo "> <" ;; # High Threat
        "blink")    echo "- -" ;; # Processing
        "dead")     echo "# #" ;; # Forbidden
        "thinking") echo "o O" ;; # Thinking/LLM
        "waiting")  echo "? ?" ;; # Waiting
        "whatever") echo "~ ~" ;; # Routine chores
        "chill")    echo "u u" ;; # Task complete
        "shock")    echo "O O" ;; # Error
        "looking")  echo "¬ ¬" ;; # Looking in detail
        "fly")      echo "^ ^" ;; # Departing / Backgrounding
	    "nectar")   echo "ø ø" ;; # Found "Nectar"
        "rich")     echo "¤ ¤" ;; # Jackpot!
        "happy")    echo "° °" ;; # Simple, wide-eyed joy
        *)          echo "0 0" ;; # Default
    esac
}


#-------------------------------------------------------------------------------
# @function   textbox
# @description Unified Bee HUD. Supports 1 or 2 lines of text.
# @param      $1  Line 1 text (Required)
# @param      $2  Mood string OR Line 2 text
# @param      $3  Mood string (Optional if $2 is used for text)
#-------------------------------------------------------------------------------
textbox() {
    local TYPE="${1:-0}"
    local L1="${2:-}"
    local P3="${3:-}"
    local P4="${4:-}"

    if [[ "$DO_SILENT" == "true" ]]; then
        return
    fi

    # Only draw if verbose is set higher or equal to the message TYPE 0, 1 [ERROR], 2 [WARNING], 3 [NOTICE]
    if [[ "$VERBOSE_LEVEL" -lt "$TYPE" ]]; then
        return
    fi

    # Logic to handle 1 vs 2 lines of text
    if [ -z "$P4" ]; then
        L2=""
        MOOD="$P3"
    else
        L2="$P3"
        MOOD="$P4"
    fi

    local EYES=$(get_eyes "$MOOD")

    # --- Dynamic Mouth Logic ---
    local MOUTH="___" # Default
    case "$MOOD" in
        "angry"|"dead") MOUTH="_^_" ;; # Aggressive mandibles
        "nectar"|"happy") MOUTH="_u_" ;; # Little smile
        "looking"|"blink") MOUTH="_-_" ;; # Concentrating
    esac

    # Draw the Bee
    if [[ "$VERBOSE_LEVEL" -ge 2 ]]; then
        echo -e "${GOLD} '\ ___ /\`${NC} __________________ _____ ____ ___ __ _"
        echo -e "${GOLD}   /${EYES}\\  ${NC}┃ ${WHITE}${L1}${NC}"
        
        if [ -n "$L2" ]; then
            echo -e "${GOLD}   \\${MOUTH}/ ${NC}┃ ${WHITE}${L2}${NC}"
            echo -e "${GOLD}         ${NC}  ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾ ‾‾‾‾‾ ‾‾‾‾ ‾‾‾ ‾‾ ‾"
        else
            #echo -e "${GOLD}   \\${MOUTH}/${NC}   ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾ ‾‾‾‾‾ ‾‾‾‾ ‾‾‾ ‾‾ ‾${NC}"
            echo -e "${GOLD} ‾‾‾‾‾‾‾‾‾${NC} ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾ ‾‾‾‾‾ ‾‾‾‾ ‾‾‾ ‾‾ ‾${NC}"
        fi
        echo -e "${GOLD}          ${NC}"
        textline 0 ""

    elif [[ "$VERBOSE_LEVEL" -ge 1 ]]; then
        echo -e "${GOLD}   /${EYES}\\  ${NC}┃ ${WHITE}${L1}${NC}"
        if [ -n "$L2" ]; then
            echo -e "${GOLD}   \\${MOUTH}/ ${NC}┃ ${WHITE}${L2}${NC}"
        fi
        textline 0 ""

    else
        echo -e "${L1}"
        if [ -n "$L2" ]; then
            echo -e "${L2}"
        fi
    fi

    beelog "$L1"
    beelog "$L2"

    # Write the face for the monitor
    if [[ -d "$JOB_DIR" ]]; then
        echo -e "${GOLD}  '\___/\` ${NC}" > $JOB_DIR/BEEFACE
        echo -e "${GOLD}   /${EYES}\\  ${NC}" >> $JOB_DIR/BEEFACE
        echo -e "${GOLD}   \\${MOUTH}/" >> $JOB_DIR/BEEFACE
    fi
}
textline(){
    local TYPE="${1:-0}"
    local L1="${2:-}"
    local L2="${3:-}"

    if [[ "$DO_SILENT" == "true" ]]; then
        return
    fi
    
    if [[ -z "$L1" ]]; then
        echo " "
        return 0
    fi

    # Only draw if verbose is set higher or equal to the message TYPE 0, 1 [ERROR], 2 [WARNING], 3 [NOTICE]
    if [[ "$VERBOSE_LEVEL" -lt "$TYPE" ]]; then
        return
    fi

    TAG=""
    if [[ "$TYPE" == 1 ]]; then
        TAG="${ORANGE}[WARNING]${NC}"
    elif [[ "$TYPE" == 2 ]]; then
        TAG="${WHITE}[NOTICE]${NC}"
    fi

    echo -e "$TAG $L1"
    if [ -n "$L2" ]; then
        echo -e "${L2}"
    fi
}
texterror() {
    local L1="${1:-}"
    local L2="${2:-}"
    TAG="${RED}[ERROR]${NC}"

    echo -e "$TAG $L1"
    if [ -n "$L2" ]; then
        echo -e "${L2}"
    fi
}


# Internal variables

textdebug 0 "Initializing..."
textline 2 "Initializing Honeybee Bash agent... ${ORANGE}($(get_eyes "fly"))${NC}"

LINEAGE=$(grep -iP '^(ID_LIKE|ID)=' /etc/os-release | cut -d= -f2 | tr -d '"' | head -n 1)  # Linux Family
HOSTNAME=$(hostname)
SYSTEM=$(uname -a)
OS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
OS=${OS// /_}
CURRENT_USER=$(whoami)
PATH_ENV=$PATH
SHELL_TYPE=$SHELL
IS_SUDO=$(sudo -n true 2>/dev/null && echo "YES" || echo "NO")
WAN_IP=$(curl -s ifconfig.me)
LAN_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+')
if [[ -z "$LAN_IP" ]]; then
    LAN_IP=$(hostname -I | awk '{print $1}')
fi

# Search for primary lineage keywords first
OS_FAMILY=$(grep -Ei "debian|fedora|arch|suse" /etc/os-release | head -n 1 | grep -Eoi "debian|fedora|arch|suse" | tr '[:upper:]' '[:lower:]')

# 2. Refined Fallback / Branch Identification
if grep -qiE "rhel|centos|alma|rocky" /etc/os-release; then
    # Even if "fedora" is mentioned as a platform ID, 
    # if it's an Enterprise clone, we label it REDHAT for the extra EPEL steps.
    OS_FAMILY="redhat"
elif [[ -z "$OS_FAMILY" ]]; then
    # Catch-all for generic linux or unknown OS
    OS_FAMILY="unknown"
fi

# Final check: If still empty, the distro is unsupported by HiveHub
if [[ -z "$OS_FAMILY" ]]; then
    echo "$ICON_CRITICAL Unsupported Distro. Local mode only."
    OS_FAMILY=""
fi

textdebug 0 "Detected distro $OS_FAMILY"


# Define your sudo prefix based on your toggle
if [[ "$APPLY_SUDO" == "true" ]]; then
    SUDO_CMD="sudo bash -c"
    SUDO="sudo"
else
    SUDO_CMD="bash -c"
    SUDO=""
fi

textdebug 0 "Integrity checks..."

# Config Directory check
if [[ ! -d "$USER_CONFIG_DIR" ]]; then
    end_program 1 "The config directory with rule config is missing." "Reinstall or correct manually as $USER_CONFIG_DIR" "${RED}($(get_eyes "angry"))${NC}"
fi
# No carriage returns allowed in global rule files
remove_carriage_return() {
    if grep -q $'\r' "$1"; then
        $BASE_DIR/tools/crlf.sh "$1"
        if grep -q $'\r' "$1"; then
            end_program 1 "$ICON_CRITICAL Carriage returns (DOS/Windows format) detected in $1"
        fi
    fi
}

# Strip carriage return chars from files
remove_carriage_return "$USER_CONFIG_DIR/RUN_FORBIDDEN"
remove_carriage_return "$USER_CONFIG_DIR/RUN_ALWAYS"
remove_carriage_return "$USER_CONFIG_DIR/RUN_NEVER"
remove_carriage_return "$USER_CONFIG_DIR/RUN_REPLACE"

# Workspace Directory check
if [[ ! -d "$USER_LOCAL_DIR/workspace" ]]; then
    textline 2 "Creating workspace directory" "${ORANGE}($(get_eyes "rolling"))${NC}"
    mkdir -p "$USER_LOCAL_DIR/workspace"
fi

if [[ "$ENABLE_SCIKIT" == "true" ]]; then
    textdebug 0 "SciKit integrity..."
    # We run the command directly in the IF. Redirecting to /dev/null keeps the console clean.
    ML_GUARD="${CYAN}ACTIVE${NC}"
    textdebug 0 'SciKit integrity : $PYTHON_BIN -c "import pandas; import sklearn"'
    set +e
    PY_CHECK=$($PYTHON_BIN -c "import pandas; import sklearn" 2>&1)
    set -e
    textdebug 0 "SciKit integrity : Result of import check=$PY_CHECK"
    if [ $? -eq 0 ]; then
        if [[ "$PY_CHECK" == *"No module named"* ]]; then
            end_program 1 "SciKit integrity : Missing Panda or SKLearn."
        fi

        textdebug 0 "SciKit integrity : Pandas and SKLearn detected"
        USE_ML_GUARD=true
        ML_GUARD="${CYAN}ACTIVE${NC}"
        if [[ ! -f "$BASE_DIR/detector.py" ]]; then
            textdebug 0 "SciKit integrity : Missing detector.py"
            end_program 1 "The detector.py detection script is missing"
        fi

    else
        textdebug 0 "SciKit integrity : Missing Pandas or SKLearn"
        texterror "Brain (Scikit/Pandas) not found. Switching to Legacy Mode."
        USE_ML_GUARD=false
        ML_GUARD="${RED}DOWN${NC}"
    fi
else
    textdebug 0 "SciKit is disabled in config"
    ENABLE_SCIKIT="false"
fi
 


# Script banner
textdebug 0 "Script banner..."
if [[ "$DO_ASKONCE" == "true" ]]; then
    EARLY_ASK="true"

elif [[ "$DO_SILENT" == "false" ]]; then 
    echo -e "${GOLD}=============================================${NC}"
    echo -e "${GOLD}"
    echo -e "         '\     /'         ${WHITE}$BEE_NAME v$BEE_VERSION ${GOLD}"
    echo -e "      ___  \___/  ___      __________________"
    echo -e "     /   \ (0 0) /   \    | ${WHITE}GUARD: $ML_GUARD${GOLD} "
    echo -e "    |  M  |  X  |  M  |   | ${WHITE}MODEL: $LLM_MODEL${GOLD}   "
    echo -e "    |_____/ @@@ \_____|   | ${WHITE}MODE: $MODE_AUTOMATIC${GOLD}"
    echo -e "           @@@@@          |__________________|"
    echo -e "            @@@           | ${WHITE}SYSTEM // NETWORK${GOLD}|"
    echo -e "             V            | ${WHITE}SCANS + ++ACTION ${GOLD}|"
    echo -e "                          | ${WHITE}SCIKIT # HEURISTICS${NC}${GOLD}|"
    echo -e "${GOLD}=============================================${NC}"
    echo -e "${NC}"
fi


JOB_NAME=${JOB_NAME,,}
PACKAGE_VERSION=${PACKAGE_VERSION,,}
if [[ -z "$PACKAGE_VERSION" ]]; then
    PACKAGE_VERSION="default"
fi

textdebug 0 "Checking JOB configuration for $JOB_NAME:$PACKAGE_VERSION..."

JOB_DIR="$USER_LOCAL_DIR/workspace/$JOB_NAME/$PACKAGE_VERSION"

if [[ "$DO_ASKONCE" == "false" ]]; then
    if [[ "$PARAM_PROMPT" != "" ]]; then
        textbox 0 "${CYAN}» Launching as : bee.sh \"$PARAM_PROMPT\" \"$PARAM_JOB\"" "rolling"
    else
        textbox 0 "${CYAN}» Launching bee.sh" "rolling"
    fi
fi

# Create required workspace
prepare_job_workspace() {
    textdebug 2 "Preparing workspace $JOB_DIR ${CYAN}($(get_eyes "whatever"))${NC}"

    # Job Directory check
    if [[ ! -d "$JOB_DIR" ]]; then
        textline 2 "Creating job dir ${CYAN}($(get_eyes "whatever"))${NC}"
        mkdir -p "$JOB_DIR"
    fi
    # Job Config Directory check
    if [[ ! -d "$JOB_DIR/config" ]]; then
        textline 2 "(Re)Creating $JOB_DIR/config ${CYAN}($(get_eyes "whatever"))${NC}"
        mkdir -p "$JOB_DIR/config"
    fi
    # Job Cache Directory check
    if [[ ! -d "$JOB_DIR/cache" ]]; then
        textline 2 "(Re)Creating $JOB_DIR/cache ${CYAN}($(get_eyes "whatever"))${NC}"
        mkdir -p "$JOB_DIR/cache"
    fi
    # Job Memory Directory check
    if [[ ! -d "$JOB_DIR/memory" ]]; then
        textline 2 "(Re)Creating $JOB_DIR/memory ${CYAN}($(get_eyes "whatever"))${NC}"
        mkdir -p "$JOB_DIR/memory"
    fi
    # Job Archive Directory check
    if [[ ! -d "$JOB_DIR/archive" ]]; then
        textline 2 "(Re)Creating $JOB_DIR/archive ${CYAN}($(get_eyes "whatever"))${NC}"
        mkdir -p "$JOB_DIR/archive"
    fi
    # Job Tmp Directory check
    if [[ ! -d "$JOB_DIR/tmp" ]]; then
        textline 2 "(Re)Creating $JOB_DIR/tmp ${CYAN}($(get_eyes "whatever"))${NC}"
        mkdir -p "$JOB_DIR/tmp"
    fi

    # Copy the default input (customizable)
    textdebug 2 "Copying default input ${CYAN}($(get_eyes "whatever"))${NC}"
    if [[ ! -f "$JOB_DIR/config/DEFAULT_INPUT" ]]; then
        if [[ ! -f "$USER_CONFIG_DIR/DEFAULT_INPUT" ]]; then
            end_program 1 "Could not find the DEFAULT_INPUT." "Reinstall or correct manually as $USER_LOCAL_DIR/DEFAULT_INPUT ${RED}($(get_eyes "angry"))${NC}"
        else
            textline 2 "(Re)Creating $JOB_DIR/config/DEFAULT_INPUT ${CYAN}($(get_eyes "whatever"))${NC}"
            cp "$USER_CONFIG_DIR/DEFAULT_INPUT" "$JOB_DIR/config/DEFAULT_INPUT"
        fi
    fi

    # Default Job profile + rules check
    textdebug 2 "Copying profile and rules ${CYAN}($(get_eyes "whatever"))${NC}"
    if [[ ! -f "$JOB_DIR/config/BEE_PROFILE" ]]; then
        if [[ ! -f "$USER_CONFIG_DIR/BEE_PROFILE" ]]; then
            end_program 1 "Could not find the main BEE_PROFILE." "Reinstall or correct manually as $USER_LOCAL_DIR/BEE_PROFILE ${RED}($(get_eyes "angry"))${NC}"
        else
            textline 2 "Replicating profile for $JOB_NAME ${CYAN}($(get_eyes "whatever"))${NC}"
            beelog "${CYAN}» Replicating rules for $JOB_NAME:$PACKAGE_VERSION${NC}"
            cp "$USER_CONFIG_DIR/BEE_PROFILE" "$JOB_DIR/config/BEE_PROFILE"
            cp "$USER_CONFIG_DIR/BEE_RULES" "$JOB_DIR/config/BEE_RULES"
            cp "$USER_CONFIG_DIR/BEE_PLANNING" "$JOB_DIR/config/BEE_PLANNING"
        fi
    fi

    # Job run rules
    if [[ ! -f "$JOB_DIR/config/RUN_FORBIDDEN" ]]; then
        touch "$JOB_DIR/config/RUN_FORBIDDEN"
    fi
    if [[ ! -f "$JOB_DIR/config/RUN_ALWAYS" ]]; then
        touch "$JOB_DIR/config/RUN_ALWAYS"
    fi
    if [[ ! -f "$JOB_DIR/config/RUN_NEVER" ]]; then
        touch "$JOB_DIR/config/RUN_NEVER"
    fi
    if [[ ! -f "$JOB_DIR/config/RUN_REPLACE" ]]; then
        touch  "$JOB_DIR/config/RUN_REPLACE"
    fi

    # Create default training dataset if needed
    textdebug 2 "Prepare training dataset ${CYAN}($(get_eyes "whatever"))${NC}"
    if [[ ! -f "$JOB_DIR/cache/dataset.csv" ]]; then
        FILE="$USER_CONFIG_DIR/default-dataset.csv"
        if [[ ! -f "$FILE" ]]; then
            end_progran "The SciKit training set default-dataset.csv is missing." "Export or place it in $USER_CONFIG_DIR" "angry" 
        fi
        # Verify and correct integrity of the default dataset
        set +e
        count=$(grep -c "command,label,weight" "$FILE")
        set -e
        if [[ $count != 1 ]]; then
            head -n 1 "$FILE" > "$FILE".tmp
            tail -n +2 "$FILE" | sort | uniq >> "$FILE".tmp
            mv "$FILE".tmp "$FILE"
            textline 2 "Filtered global dataset duplicates in " "$FILE." "whatever" 
        fi
        textline 1 "Creating the default SciKit trainingset in" "$JOB_DIR/cache/dataset.csv. Review it to verify." "whatever" 
        cp "$USER_CONFIG_DIR/default-dataset.csv" $JOB_DIR/cache/dataset.csv
        chmod 660 $JOB_DIR/cache/dataset.csv
        if [[ -f "$JOB_DIR/cache/model.pkl" ]]; then
            rm $JOB_DIR/cache/*.pkl
        fi
    fi

    # Verify and correct integrity of the created dataset
    textdebug 2 "Verify training dataset ${CYAN}($(get_eyes "whatever"))${NC}"
    FILE="$JOB_DIR/cache/dataset.csv"
    set +e
    count=$(grep -c "command,label,weight" "$FILE")
    set -e
    if [[ $count != 1 ]]; then
        head -n 1 "$FILE" > "$FILE".tmp
        tail -n +2 "$FILE" | sort | uniq >> "$FILE".tmp
        mv "$FILE".tmp "$FILE"
        textline 2 "Filtered dataset duplicates" "$JOB_DIR/cache/dataset.csv." "whatever" 
    fi
    DATASET=$(cat $JOB_DIR/cache/dataset.csv)
    length=${#DATASET}
    if [ "$length" -lt "500" ]; then
        textbox 1 "The SciKit training dataset at $length characters seems small (incomplete)." "$JOB_DIR/cache/dataset.csv" "annoyed" 
    fi

    #if [[ "$IS_SUDO" == "YES" ]]; then
    $SUDO chown -R $REAL_USER:$REAL_GROUP "$JOB_DIR"
    $SUDO chown -R $REAL_USER:$REAL_GROUP "$USER_CONFIG_DIR"
    $SUDO chown -R $REAL_USER:$REAL_GROUP "$USER_LOCAL_DIR"
    #fi
}


# Deleted the build data model for rebuild using dataset.csv
remove_hive_model() {
    rm -f $JOB_DIR/cache/*.pkl
}

#-------------------------------------------------------------------------------
# @function   rotate_journal
# @description Manages log hygiene and storage constraints for the Hive.
#              Prevents JOURNAL bloat by implementing a "Rotate-and-Cap" 
#              strategy when the file exceeds a defined threshold.Resuming last
#
# @global      WORKSPACE_DIR       Location of the JOURNAL file.
# @constant    MAX_LOG_SIZE_KB     Size threshold (e.g., 5000 for 5MB).
# @constant    MAX_BACKUPS         Number of historical logs to retain.
#
# @returns     0 if journal is within limits; 1 if rotation was performed.
#-------------------------------------------------------------------------------
rotate_journal() {
    local jpath="${1:-$JOB_DIR/JOURNAL}"
    [[ -f "$jpath" ]] || return 0
    local dir base n=0 suffix f
    dir=$(dirname -- "$jpath")
    base=$(basename -- "$jpath")
    shopt -s nullglob
    for f in "$dir/$base".*; do
        [[ -f "$f" ]] || continue
        suffix="${f##*.}"
        [[ "$suffix" =~ ^[0-9]+$ ]] || continue
        (( 10#$suffix > n )) && n=$((10#$suffix))
    done
    shopt -u nullglob
    (( ++n ))
    mv -- "$jpath" "$dir/$base.$n"
}

# Reusable cleanup function
clear_workspace_file() {
    if [[ -z "$1" ]]; then
        return
    fi
    if [[ ! -f "$1" ]]; then sudo -u "$REAL_USER" touch "$1"; else truncate -s 0 "$1"; fi
}
cleanup_workspace(){
    clear_workspace_file "$JOB_DIR/ADDITIONAL"
    clear_workspace_file "$JOB_DIR/BEELOG"
    clear_workspace_file "$JOB_DIR/COMMANDLOG"
    clear_workspace_file "$JOB_DIR/EXPLANATION"
    clear_workspace_file "$JOB_DIR/FACTS"
    clear_workspace_file "$JOB_DIR/FOCUS"
    clear_workspace_file "$JOB_DIR/GOAL"
    clear_workspace_file "$JOB_DIR/HISTORY"
    clear_workspace_file "$JOB_DIR/JOBCOMPLETED"
    clear_workspace_file "$JOB_DIR/LASTPROMPT"
    clear_workspace_file "$JOB_DIR/LOG"
    clear_workspace_file "$JOB_DIR/NEXTACTION"
    clear_workspace_file "$JOB_DIR/PROMPTLOG"
    clear_workspace_file "$JOB_DIR/REASONING"
    clear_workspace_file "$JOB_DIR/TASKSCOMPLETED"
    clear_workspace_file "$JOB_DIR/CYCLE"
    
    rm -f $JOB_DIR/PENDINGREQUEST
    rm -f $JOB_DIR/PENDINGUSERRESPONSE
    rm -f $JOB_DIR/RUNNINGCOMMAND
    rm -f $JOB_DIR/MONITORCOMMAND
    rm -f $JOB_DIR/PLAN
    rm -f $JOB_DIR/bee-stats.json
    rm -rf $JOB_DIR/archive/*
    rm -rf $JOB_DIR/memory/*
    rm -rf $JOB_DIR/tmp/*
    rotate_journal
    > "$JOB_DIR/JOURNAL"
    beelog "${CYAN}» Bee Logs purged ${NC}"
    remove_hive_model
}

# Command got interupted or crashed the script
if [[ ! -f "$JOB_DIR/RUNNINGCOMMAND" ]]; then
    textdebug 0 "Recover from interupted command..."
    RUNNING_COMMAND=(cat $JOB_DIR/RUNNINGCOMMAND)
    rm -f $JOB_DIR/RUNNINGCOMMAND
fi



# Run commands from --parameter usage
textdebug 0 "Process parameters..."
if [[ "$DO_FORGET" == "true" ]]; then
    if [[ -n "$FORGET_CMD" && "$FORGET_CMD" != -* ]]; then
        $BASE_DIR/tools/forget.sh "$JOB_NAME:$PACKAGE_VERSION" "$FORGET_CMD" 
        beelog "${CYAN}» Bee Forgot '$2'${NC}"
        textline 0 "${WHITE}Bee forgot '$2' ${CYAN}($(get_eyes "chill"))${NC}"
    else
        end_program 1 "Error: --forget= requires a command string."
    fi
    end_program
fi

# ./merge.sh {defaultconfig dir} {configdir} {workspace dir} {jobname}"
if [[ "$DO_MERGE" == "true" ]]; then
    $BASE_DIR/tools/merge.sh "$USER_CONFIG_DIR" "$USER_LOCAL_DIR" "$JOB_NAME:$PACKAGE_VERSION"
    TOOLRESULT=$?
    if [ $TOOLRESULT -eq 0 ]; then
        beelog "${CYAN}» Bee collected '$JOB_NAME'${NC}"
        textline 0 "${WHITE}Bee collected rules and training for $JOB_NAME ${CYAN}($(get_eyes "chill"))${NC}"
    else
        beelog "${RED}» Bee failed to collect for '$JOB_NAME'${NC}"
        texterror "${RED}Failed to collect rules and training for $JOB_NAME ${RED}($(get_eyes "angry"))${NC}"
    fi
    end_program
fi

if [[ "$DO_DROP" == "true" ]]; then
    textdebug 2 "${WHITE}Bee processing --drop=$DROP_JOB ${CYAN}($(get_eyes "chill"))${NC}"     
    if [[ -n "$DROP_JOB" ]]; then
        textdebug 2 "${WHITE}Bee attempting to drop job '$DROP_JOB' ${CYAN}($(get_eyes "chill"))${NC}"
        TMP_JOB_NAME="${DROP_JOB%%:*}"
        TMP_JOB_NAME=${TMP_JOB_NAME,,}
        TMP_JOB_VERSION="${DROP_JOB#*:}"
        TMP_JOB_VERSION=${TMP_JOB_VERSION,,}
        if [[ -z "$TMP_JOB_VERSION" ]] || [[ "$TMP_JOB_VERSION" == "$TMP_JOB_NAME" ]]; then
            TMP_JOB_VERSION="default"
        fi
        if [ -d "$USER_LOCAL_DIR/workspace/$TMP_JOB_NAME/$TMP_JOB_VERSION" ]; then
            rm -rf "$USER_LOCAL_DIR/workspace/$TMP_JOB_NAME/$TMP_JOB_VERSION" 
            beelog "${CYAN}» Bee dropped job '$USER_LOCAL_DIR/workspace/$TMP_JOB_NAME:$TMP_JOB_VERSION'${NC}"
            textline 0 "${WHITE}Bee dropped job $USER_LOCAL_DIR/workspace/$TMP_JOB_NAME/$TMP_JOB_VERSION ${CYAN}($(get_eyes "chill"))${NC}"
        else
            texterror "${RED}Could not find job directory $TMP_JOB_NAME:$TMP_JOB_VERSION ${RED}($(get_eyes "angry"))${NC}"
        fi
    fi
    end_program
fi

if [[ "$DO_CLEANUP" == "true" ]]; then
    cleanup_workspace
    beelog "${CYAN}» Bee Logs purged${NC}"
    textline 2 "${WHITE}Bee's brain got purged ${CYAN}($(get_eyes "chill"))${NC}"
fi

if [[ "$DO_CLEARRULES" == "true" ]]; then
    if [[ "$WORKSPACE_DIR" == "" ]]; then
        end_program 1 "${WHITE}Cannot comply. Lost the workspace dir. ${CYAN}($(get_eyes "angry"))${NC}"
    elif [ -d $WORKSPACE_DIR/$JOB_NAME/$PACKAGE_VERSION/config ]; then
        > "$WORKSPACE_DIR/$JOB_NAME/$PACKAGE_VERSION/config/RUN_FORBIDDEN"
        > "$WORKSPACE_DIR/$JOB_NAME/$PACKAGE_VERSION/config/RUN_ALWAYS"
        > "$WORKSPACE_DIR/$JOB_NAME/$PACKAGE_VERSION/config/RUN_NEVER"
        > "$WORKSPACE_DIR/$JOB_NAME/$PACKAGE_VERSION/config/RUN_REPLACE"
        beelog "${CYAN}» Bee job Run rules purged ${NC}"
        textline 0 "${WHITE}Bee's job Run rules got purged. ${CYAN}($(get_eyes "chill"))${NC}"
    else
        end_program 1 "${WHITE}Cannot comply. Lost the job config dir. ${CYAN}($(get_eyes "angry"))${NC}"
    fi
fi

if [[ "$DO_CLONE" == "true" ]]; then
    if [[ -z "$TARGET_JOB" ]]; then
        end_program 1 "${WHITE}Enter the --target={job:version} destination package. Version is optional.${CYAN}($(get_eyes "angry"))${NC}"
    else
        JOB_NAME="${CLONE_JOB%%:*}"
        JOB_NAME=${JOB_NAME,,}
        if [[ -z "$JOB_NAME" ]]; then
            end_program 1 "${WHITE}Enter the --cloneversion={job:version} source package. Version is optional.${CYAN}($(get_eyes "angry"))${NC}"
        fi
        PACKAGE_VERSION="${CLONE_JOB#*:}"
        PACKAGE_VERSION=${PACKAGE_VERSION,,}
        if [[ -z "$PACKAGE_VERSION" ]] || [[ "$PACKAGE_VERSION" == "$JOB_NAME" ]]; then
            PACKAGE_VERSION="default"
        fi

        TARGET_JOB_NAME="${TARGET_JOB%%:*}"
        TARGET_JOB_NAME=${TARGET_JOB_NAME,,}
        TARGET_JOB_VERSION="${TARGET_JOB#*:}"
        TARGET_JOB_VERSION=${TARGET_JOB_VERSION,,}
        if [[ -z "$TARGET_JOB_VERSION" ]] || [[ "$TARGET_JOB_VERSION" == "$TARGET_JOB_NAME" ]]; then
            TARGET_JOB_VERSION="default"
        fi
        if [[ -z "$TARGET_JOB_NAME" ]] || [[ -z "$TARGET_JOB_VERSION" ]]; then
            end_program 1 "${WHITE}Enter the --target={job:version} destination package. Version is optional.${CYAN}($(get_eyes "angry"))${NC}"
        fi

        # Create target directory
        if [ ! -d "$WORKSPACE_DIR/$TARGET_JOB_NAME/$TARGET_JOB_VERSION" ]; then
            mkdir -p "$WORKSPACE_DIR/$TARGET_JOB_NAME/$TARGET_JOB_VERSION"
            chmod 770 "$WORKSPACE_DIR/$TARGET_JOB_NAME"
            chmod 770 "$WORKSPACE_DIR/$TARGET_JOB_NAME/$TARGET_JOB_VERSION"
        fi
        cp -rf "$WORKSPACE_DIR/$JOB_NAME/$PACKAGE_VERSION"/* "$WORKSPACE_DIR/$TARGET_JOB_NAME/$TARGET_JOB_VERSION/"
        JOB_NAME="$TARGET_JOB_NAME"
        PACKAGE_VERSION="$TARGET_JOB_VERSION"
        beelog "${CYAN}» Bee job $CLONE_JOB cloned to $TARGET_JOB ${NC}"
        textline 0 "${WHITE}Bee job $CLONE_JOB cloned to $TARGET_JOB. ${CYAN}($(get_eyes "chill"))${NC}"
    fi 
    end_program
fi


# Export Job+Global or Job only
export_dataset() {
    
    if [[ -z "$HIVEHUB_USER" ]]; then
        textline 0 "${WHITE}Missing HIVEHUB_USER in bee.conf. ${CYAN}($(get_eyes "angry"))${NC}"
        echo "Register for free to receive an HiveHub API KEY "
        echo "https://honeybeebash.com/hivehub"
        end_program 1 "$ICON_FAIL Aborting export" 
    fi
    if [[ -z "$HIVEHUB_API_KEY" ]]; then
        textline 0 "${WHITE}Missing HIVEHUB_USER in bee.conf. ${CYAN}($(get_eyes "angry"))${NC}"
        echo "Register for free to receive an HiveHub API KEY "
        echo "https://honeybeebash.com/hivehub"
        end_program 1 "$ICON_FAIL Aborting export"
    fi

    TMP_JOB_NAME="${EXPORT_SET%%:*}"
    TMP_JOB_NAME=${TMP_JOB_NAME,,}
    TMP_JOB_VERSION="${EXPORT_SET#*:}"
    TMP_JOB_VERSION=${TMP_JOB_VERSION,,}
    if [[ -z "$TMP_JOB_VERSION" ]] || [[ "$TMP_JOB_VERSION" == "$TMP_JOB_NAME" ]]; then
        TMP_JOB_VERSION="default"
    fi
    TMP_JOB_DIR="$WORKSPACE_DIR/$TMP_JOB_NAME/$TMP_JOB_VERSION"
    if [[ -d "$TMP_JOB_DIR" ]]; then   
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        ZIP_FILE="/tmp/${TIMESTAMP}_${TMP_JOB_NAME}_${TMP_JOB_VERSION}.zip"
        textline 0 "$ICON_DOWNLOAD Compressing $EXPORT_SET..."

        # Prepare to zip the submission files
        TMP_STAGE="/tmp/tmp_export_$(date +%s)"
        if [[ "$1" == "all" ]]; then
            mkdir -p "$TMP_STAGE/globalrules"
        fi

        # Seperate job files from global files
        mkdir -p "$TMP_STAGE/jobrules"
        cp "$TMP_JOB_DIR/config/"BEE_* "$TMP_STAGE/jobrules/" 2>/dev/null
        cp "$TMP_JOB_DIR/config/"RUN_* "$TMP_STAGE/jobrules/" 2>/dev/null
        cp "$TMP_JOB_DIR/config/DEFAULT_INPUT" "$TMP_STAGE/jobrules/" 2>/dev/null
        cp "$TMP_JOB_DIR/cache/dataset.csv" "$TMP_STAGE/jobrules/dataset.csv" 2>/dev/null

        # Add global rules
        if [[ "$1" == "all" ]]; then
            cp "$USER_LOCAL_DIR/"RUN_* "$TMP_STAGE/globalrules/" 2>/dev/null
            cp "$USER_LOCAL_DIR/default-dataset.csv" "$TMP_STAGE/globalrules/default-dataset.csv" 2>/dev/null
        fi

        # Perform the Zip action
        (cd "$TMP_STAGE" && zip -rq "$ZIP_FILE" .)
        rm -rf "$TMP_STAGE"
        if [[ -f "$ZIP_FILE" ]]; then
            textline 0 "$ICON_LAUNCH Uploading to HiveHub..."

            textdebug 2 "ZIP: $ZIP_FILE"
            textdebug 2 "API: $HIVEHUB_API_URL?a=export&u=$HIVEHUB_USER&k=$HIVEHUB_API_KEY&distro=$OS_FAMILY&os=$OS&job=$EXPORT_SET&text=$EXPORT_TEXT"

            EXPORT_TEXT="${EXPORT_TEXT// /+}"
            textdebug 2 "CMD: curl -s -F \"file=@$ZIP_FILE\" \"$HIVEHUB_API_URL?a=export&u=$HIVEHUB_USER&k=$HIVEHUB_API_KEY&distro=$OS_FAMILY&os=$OS&job=$EXPORT_SET&text=$EXPORT_TEXT\""

            set +e
            RESULT=$(curl -s -F "file=@$ZIP_FILE" "$HIVEHUB_API_URL?a=export&u=$HIVEHUB_USER&k=$HIVEHUB_API_KEY&distro=$OS_FAMILY&os=$OS&job=$EXPORT_SET&text=$EXPORT_TEXT")
            set -e

            textdebug 0 "$RESULT"

            if [[ "$RESULT" == *"DONE"* ]]; then
                textline 0 "$ICON_SUCCES $EXPORT_SET has been exported to HiveHub."
                # Clean up after successful upload
                rm -f "$ZIP_FILE"
            else
                end_program 1 "$ICON_FAIL $EXPORT_SET could not be exported to HiveHub. Result: $RESULT" 
            fi
        else
            end_program 1 "$ICON_FAIL Failed to create zip archive."
        fi
    else
        end_program 1 "$ICON_FAIL Job '$EXPORT_SET not found in workspace directory."
    fi
}
if [[ "$DO_EXPORT" == "all" ]]; then
    export_dataset "all"
    DO_EXIT="true"
elif [[ "$DO_EXPORT" == "job" ]]; then
    export_dataset "job"
    DO_EXIT="true"
fi


# Import Job+Global or Job only
import_dataset() {
    IMPORT_TYPE=${1:-}
    if [[ -z "$IMPORT_TYPE" ]]; then
        end_program 1 "$ICON_FAIL No import type found. Try again."
    fi
    if [[ -z "$IMPORT_SET" ]]; then
        end_program 1 "$ICON_FAIL No import job found. Try again."
    fi

    textdebug 0 "Import started for $IMPORT_SET"

    # Prepare job workspace
    JOB_NAME="${IMPORT_SET%%:*}"
    JOB_NAME="${JOB_NAME,,}" # Convert to lowercase
    PACKAGE_VERSION="${IMPORT_SET#*:}"
    PACKAGE_VERSION=${PACKAGE_VERSION,,}
    if [[ -z "$PACKAGE_VERSION" ]] || [[ "$PACKAGE_VERSION" == "$JOB_NAME" ]]; then
        PACKAGE_VERSION="default"
    fi

    if [[ -z "$JOB_NAME" ]]; then
        end_program 1 "$ICON_FAIL Job name (version $PACKAGE_VERSION) missing in import parameter."
    fi

    JOB_DIR="$USER_LOCAL_DIR/workspace/$JOB_NAME/$PACKAGE_VERSION"

    if [[ -d "$JOB_DIR" ]]; then
        read -p "Overwrite existing job directory $JOB_NAME/$PACKAGE_VERSION ? (Yes/No/Quit): " CONFIRM
        case "${CONFIRM,,}" in
            q|quit) end_program ;;
            y|yes) echo "Action: Overwriting $JOB_DIR ..." ;;
            n|no) 
                read -p "Enter alternative version directory name: " PACKAGE_VERSION
                PACKAGE_VERSION=${PACKAGE_VERSION,,}
                if [[ -n "$PACKAGE_VERSION" ]]; then
                    JOB_DIR="$USER_LOCAL_DIR/workspace/$JOB_NAME/$PACKAGE_VERSION"
                    if [[ -d "$JOB_DIR" ]]; then
                        read -p "Overwrite custom existing version directory? (y/n): " CONFIRM
                        case "${CONFIRM,,}" in
                            y|yes) echo "Action: Overwriting $JOB_DIR..." ;;
                            *) echo "Retry the import and choose an empty version directory."; end_program ;;
                        esac
                    fi
                else
                    end_program 1 "No name provided. Import stopped."
                fi
                ;;
            *) end_program 1 "No choice made. Import stopped." ;;
        esac
    fi

    # Prepare job directory structure
    textdebug 0 "Prepare Job directory"
    if [[ -n "$JOB_DIR" ]]; then
        
        # Clear workspace, truncate log files, clear archive, memory, tmp
        prepare_job_workspace

        # Clear workspace and trained datamodel (keeps dataset.csv)
        cleanup_workspace

        # Retrieve the package
        textdebug 0 "Requesting u=$HIVEHUB_USER&distro=$OS_FAMILY&os=$OS&job=$IMPORT_SET"
        textline 0 "$ICON_DOWNLOAD Downloading $IMPORT_SET..."

        IMPORT_DIR="$JOB_DIR/tmp"
        ZIP_FILE="$IMPORT_DIR/dataset.zip"
        
        if [[ -f "$ZIP_FILE" ]]; then
            rm -f "$ZIP_FILE"
        fi
        if [[ -d "$IMPORT_DIR/$PACKAGE_VERSION" ]]; then
            rm -rf "$IMPORT_DIR/$PACKAGE_VERSION"
        fi

        mkdir -p "$IMPORT_DIR" 
        wget -q -O "$ZIP_FILE" "$HIVEHUB_API_URL?a=import&u=$HIVEHUB_USER&distro=$OS_FAMILY&os=$OS&job=$IMPORT_SET"
        
        if grep -q "^ERROR:" "$ZIP_FILE"; then
            ERR_MSG=$(cat "$ZIP_FILE")
            rm -rf "$ZIP_FILE"
            end_program 1 "$ERR_MSG"
        fi

        # On success unpack the archive
        if [[ -f "$ZIP_FILE" ]]; then
            textdebug 0 "Unpacking $ZIP_FILE"
            textdebug 0 "Distro: $OS_FAMILY\nJob: $JOB_NAME:$PACKAGE_VERSION"
            textline 2 "Distro: $OS_FAMILY\nJob: $JOB_NAME:$PACKAGE_VERSION" > "$JOB_DIR/config/PACKAGE_VERSION"
            textline 2 "$ICON_DOWNLOAD Unpacking $IMPORT_SET..."

            # Unzip -o overwrites without prompting, -d specifies destination (Unpacks to a job directory)
            set +e
            unzip -q -o "$ZIP_FILE" -d "$IMPORT_DIR/"
            set -e

            # Verify the core file exists in the unpacked path *unpacks to new $PACKAGE_VERSION directory)
            textdebug 0 "Checking $IMPORT_DIR/$PACKAGE_VERSION/jobrules/RUN_ALWAYS"
            if [[ -f "$IMPORT_DIR/$PACKAGE_VERSION/jobrules/RUN_ALWAYS" ]]; then
                textdebug 0 "Installing $ZIP_FILE"
                textline 0 "$ICON_DOWNLOAD Installing $IMPORT_SET..."

                # Install job Bee profile
                if [[ "$IMPORT_TYPE" == "all" ]] || [[ "$IMPORT_TYPE" == "job" ]]; then
                    if [[ -f "$IMPORT_DIR/$PACKAGE_VERSION/jobrules/BEE_PROFILE" ]]; then
                        cp -f "$IMPORT_DIR/$PACKAGE_VERSION/jobrules/"BEE_* "$JOB_DIR/config/"
                    fi
                    if [[ -f "$IMPORT_DIR/$PACKAGE_VERSION/jobrules/DEFAULT_INPUT" ]]; then
                        cp -f "$IMPORT_DIR/$PACKAGE_VERSION/jobrules/DEFAULT_INPUT" "$JOB_DIR/config/DEFAULT_INPUT"
                    fi
                fi
                
                # Install Job ruleset
                if [[ "$IMPORT_TYPE == "all" ]] || [[ "$IMPORT_TYPE == "job" ]] || [[ "$IMPORT_TYPE == "jobrules" ]]; then
                    cp -f "$IMPORT_DIR/$PACKAGE_VERSION/jobrules/"RUN_* "$JOB_DIR/config/"
                    # Copy dataset even if it already exists in cache
                    [[ -f "$IMPORT_DIR/$PACKAGE_VERSION/jobrules/dataset.csv" ]] && cp -f "$IMPORT_DIR/$PACKAGE_VERSION/jobrules/dataset.csv" "$JOB_DIR/cache/"
                fi

                
                # Install job Bee profiles to the global/default config
                if [[ "$IMPORT_TYPE == "all" ]] || [[ "$IMPORT_TYPE == "global" ]] || [[ "$IMPORT_TYPE == "globalrules" ]]; then
                    textdebug 0 "Installing Global rules"
                    textline 0 "$ICON_DOWNLOAD Applying global ruleset..."
                    
                    if [[ -f "$IMPORT_DIR/$PACKAGE_VERSION/jobrules/BEE_PROFILE" ]]; then
                        cp -f "$IMPORT_DIR/$PACKAGE_VERSION/jobrules/"BEE_* "$USER_CONFIG_DIR/"
                    fi
                    
                    # Install global rulesets to central config
                    cp -f "$IMPORT_DIR/$PACKAGE_VERSION/globalrules/"RUN_* "$USER_CONFIG_DIR/"
                    [[ -f "$IMPORT_DIR/$PACKAGE_VERSION/globalrules/default-dataset.csv" ]] && cp -f "$IMPORT_DIR/$PACKAGE_VERSION/globalrules/default-dataset.csv" "$USER_CONFIG_DIR/"
                fi

                # Cleanup the mess
                rm -rf "$IMPORT_DIR/$PACKAGE_VERSION"
                rm -rf "$IMPORT_DIR/dataset.zip"
                
                textline 0 "$ICON_SUCCES Job install for $IMPORT_SET completed."
            else
                end_program 1 "$ICON_FAIL $IMPORT_SET dataset is incomplete."
            fi
        else
            end_program 1 "$ICON_FAIL $IMPORT_SET could not be downloaded from HiveHub." 
        fi
    fi
}
if [[ "$DO_IMPORT" != "false" ]]; then
    import_dataset "$DO_IMPORT"
fi


# Model selection
if [[ ! -f "$USER_LOCAL_DIR/models/$LLM_MODEL".conf ]] || [[ ! -f "$USER_LOCAL_DIR/models/$LLM_MODEL".py ]]; then 
    end_program 1 "The model $LLM_MODEL is missing from $USER_LOCAL_DIR/models/." "Add a .conf and .py file to apply this model." "angry" 
fi



# Compile system info

ENV="Hostname: $HOSTNAME
SYSTEM=$SYSTEM
FAMILY=$OS_FAMILY
OS=$OS
CURRENT_USER=$CURRENT_USER
PATH_ENV=$PATH_ENV
SHELL_TYPE=$SHELL_TYPE
IS_SUDO=$IS_SUDO
BASE_DIR=$BASE_DIR
JOB TAG=$JOB_NAME
JOB DIR=$JOB_DIR/
MEMORY DIR=$JOB_DIR/memory/
TEMPORARY DIR=$JOB_DIR/tmp/"

textdebug 3 "ENVIRONMENT:\n$ENV\nMODEL=$LLM_MODEL"


# Exit by command
if [[ "$DO_EXIT" == "true" ]]; then
    textline 0 "${WHITE}Bee's maintenance completed. ${CYAN}($(get_eyes "chill"))${NC}"
    if [[ -d $JOB_DIR ]]; then
        echo "maintenance done" > $JOB_DIR/JOBCOMPLETED
    fi
    exit 0
fi


# On first run Import default task from HiveHub
if [[ ! -d "$WORKSPACE_DIR/default" ]]; then
    echo "$ICON_DOWNLOAD Importing default rulesset from HiveHub"
    IMPORT_SET="default"
    DO_IMPORT="all"
    import_dataset "$DO_IMPORT"
fi


# Assure all required files are available, if not then take from

textdebug 0 "Prepare JOB..."

# Flag job as running
rm -f $JOB_DIR/JOBCOMPLETED

# Cleanup asyn request+response
rm -f $JOB_DIR/PENDINGREQUEST
rm -f $JOB_DIR/PENDINGUSERRESPONSE
rm -f $JOB_DIR/MONITORCOMMAND

prepare_job_workspace


# echo review and exit
if [[ "$DO_REVIEW" == "true" ]]; then
    echo -e "\n### HoneyBeeBash $BEE_VERSION Job review for $JOB_NAME:$PACKAGE_VERSION\n\n"

    echo -e "\n\n### BEE_PROFILE \n\n"
    cat "$JOB_DIR/config/BEE_PROFILE"
    echo -e "\n\n### BEE_PLANNING \n\n"
    cat "$JOB_DIR/config/BEE_PLANNING"
    echo -e "\n\n### BEE_RULES \n\n"
    cat "$JOB_DIR/config/BEE_RULES"
    echo -e "\n\n### DEFAULT_INPUT \n\n"
    cat "$JOB_DIR/config/DEFAULT_INPUT"

    echo -e "\n\n### GLOBAL RUN_FORBIDDEN \n\n"
    cat "$USER_CONFIG_DIR/RUN_FORBIDDEN"
    echo -e "\n\n### GLOBAL RUN_ALWAYS \n\n"
    cat "$USER_CONFIG_DIR/RUN_ALWAYS"
    echo -e "\n\n### GLOBAL RUN_NEVER \n\n"
    cat "$USER_CONFIG_DIR/RUN_NEVER"
    echo -e "\n\n### GLOBAL RUN_REPLACE \n\n"
    cat "$USER_CONFIG_DIR/RUN_REPLACE"

    echo -e "\n\n### JOB RUN_FORBIDDEN \n\n"
    cat "$JOB_DIR/config/RUN_FORBIDDEN"
    echo -e "\n\n### JOB RUN_ALWAYS \n\n"
    cat "$JOB_DIR/config/RUN_ALWAYS"
    echo -e "\n\n### JOB RUN_NEVER \n\n"
    cat "$JOB_DIR/config/RUN_NEVER"
    echo -e "\n\n### JOB RUN_REPLACE \n\n"
    cat "$JOB_DIR/config/RUN_REPLACE"
    
    echo -e "\n\n### DATASET \n\n"
    cat "$JOB_DIR/cache/dataset.csv"

    end_program 0 ""
fi


function googlegenerator() {
    # Gemini Flash Payload
    JSON_PAYLOAD=$(jq -n \
    --arg prompt "$PROMPT" \
    '{
        contents: [{ parts: [{ text: $prompt }] }],
        generationConfig: { response_mime_type: "application/json" }
    }')
    RESPONSE=$(curl -s -S --connect-timeout "$TIMEOUT" --max-time "$MAX_TIMEOUT" \
        "$MODEL_BASE_URL" \
        -H "Content-Type: application/json" \
        -H "x-goog-api-key: $GEMINI_API_KEY" \
        -d "$JSON_PAYLOAD")
}

function googleapiai() {
    AI_RESPONSE=$($PYTHON_BIN -c '
    from google import genai
    import os

    client = genai.Client()
    response = client.models.generate_content(
        model="gemini-3-flash-preview", 
        contents="$PROMPT"
    )
    print(response.text)
    ')
}

#-------------------------------------------------------------------------------
# @function   googleai
# @description Sovereign Cloud-Based Analysis via Google Gemini API.
#              The "Supreme Court" of the Hive; invoked for high-stakes 
#              ambiguity or complex script decoding.
#
# @param      $1  Command string to analyze.
# @param      $2  Context (optional: e.g., error logs or system state).
#
# @returns    High-fidelity risk assessment and mitigation advice.
# @security   Note: Sends command strings to external API. Ensure PII/Secrets 
#             are scrubbed before invocation.
#-------------------------------------------------------------------------------
remote_googleai(){

    START_TIME=$(date +%s.%N)
    local rate_retries=0

    while true; do
        set +e
        RESPONSE=$(printf '%s' "$PROMPT" | $PYTHON_BIN "$USER_LOCAL_DIR/models/$LLM_MODEL".py 2>&1)
        set -e

        textdebug 0 "REMOTE RESPONSE: $RESPONSE"

        # In case of an error
        if [[ "$RESPONSE" == *"SDK Error: 503 UNAVAILABLE"* ]] || [[ "$RESPONSE" == *"GenerateRequestsPerDayPerProjectPerModel"* ]] ; then
            RESPONSE=$(echo "$RESPONSE" | tr "'" '"')
        fi

        if [[ "$RESPONSE" == *"ModuleNotFoundError: No module named"* ]]; then
            end_program 1 "Missing modules. Did you forget to install or enter the venv ?" 
        fi
        
        # Grab the JSON
        prefix="${RESPONSE%%\{*}"
        start_index=${#prefix} 

        # Now grab everything from that index forward
        CLEAN_EXTRACT="${RESPONSE:$start_index}"

        # Trim everything after the last }
        CLEAN_EXTRACT="${CLEAN_EXTRACT%\}*}"
        CLEAN_EXTRACT="${CLEAN_EXTRACT}}"

        if [[ -n "$CLEAN_EXTRACT" ]]; then
            FINAL_JSON="${CLEAN_EXTRACT%\}*}} "
            
            # Clean up any trailing whitespace/newlines
            FINAL_JSON=$(echo "$FINAL_JSON" | tr -d '\n\r')

            # 4. Now validate the result
            if echo "$FINAL_JSON" | jq -e . >/dev/null 2>&1; then
                if echo "$FINAL_JSON" | jq -e 'has("error") == false' >/dev/null 2>&1; then
                    RESPONSE="$FINAL_JSON"
                    textdebug 0 "Success: Found JSON via position search."
                    break
                fi
            fi
        fi

        # GLOBAL OVERRIDES (Keep these after the checks)
        if [[ "$DO_ASKONCE" == "true" ]] || [[ "$TEST_MODE" == "true" ]]; then
            break
        fi

        # VALIDATION & BRANCHING
        if echo "$FINAL_JSON" | jq -e 'has("error") == false' >/dev/null 2>&1; then
            # --- SUCCESS PATH ---
            RESPONSE="$FINAL_JSON"
            textdebug 0 "Success: Nectar acquired."
            break # EXITS THE WHILE LOOP IMMEDIATELY
        else
            # --- API ERROR PATH (JSON) ---
            ERR_MSG=$(echo "$FINAL_JSON" | jq -r '.error.message // "Unknown API Error"')
        fi

        # 4. ERROR ANALYSIS (Only reached if success 'break' didn't happen)
        textdebug 0 "ERR_MSG: $ERR_MSG"

        # CASE: 503 Spike
        if [[ "$RESPONSE" == *"503"* ]] || [[ "$ERR_MSG" == *"high demand"* ]]; then
            textline 1 "${GOLD}[!] Server Busy (503). Retrying...${NC}"
            sleep "$SELECTED_MODEL_RETRY_TIMEOUT"
            continue 
        fi

        # CASE: Hard Quota
        if [[ "$RESPONSE" == *"GenerateRequestsPerDayPerProjectPerModel"* ]]; then
            end-program "${WHITE}Daily project quota exhausted. Loop terminated.${NC}"
        fi
        
        # CASE: Rate Limit
        if [[ "$ERR_MSG" =~ retry\ in\ ([0-9.]+)s ]] || [[ "$RESPONSE" == *"RESOURCE_EXHAUSTED"* ]]; then
            (( rate_retries++ )) || true
            if [ "$rate_retries" -gt "$MAX_RATE_LIMIT_RETRIES" ]; then
                end_program 1 "Rate limit retries exhausted."
            fi
            WAIT_S="${BASH_REMATCH[1]:-10}"
            SLEEP_S=$(echo "$WAIT_S + 5" | bc)
            sleep "$SLEEP_S"
            continue
        fi

        # CASE: Unknown Fatal Error
        end_program 1 "${WHITE}Gemini API Fatal Error:${NC} $ERR_MSG"
    done
    
    textdebug 0 "Processing response"

    # --- Processing the successful response ---
    if [[ "$DO_ASKONCE" != "true" ]] && [[ "$TEST_MODE" != "true" ]]; then

        # Support dual response 
        NESTED_JSON=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty')
        if [[ "$NESTED_JSON" == \{* ]]; then
            SOURCE="$NESTED_JSON"
        else
            SOURCE="$RESPONSE"
        fi
        # Extract values
        if [[ -n "$SOURCE" ]]; then
            COMMAND=$(echo "$SOURCE" | jq -r '.command // empty')
            EXPLANATION=$(echo "$SOURCE" | jq -r '.explanation // empty')
            NEW_FACT=$(echo "$SOURCE" | jq -r '.new_fact // empty')
            TASK_COMPLETED=$(echo "$SOURCE" | jq -r '.task_completed // empty')
            GOAL_COMPLETED=$(echo "$SOURCE" | jq -r '.goal_completed // empty')     
        fi
           
        # Timing Stats
        END_TIME=$(date +%s.%N)
        TOTAL_TIME=$(echo "$END_TIME - $START_TIME" | bc)
    fi
}


#-------------------------------------------------------------------------------
# @function   ollama
# @description Heavy-duty heuristic reasoning via Ollama (Local LLM).
#              Used for deep contextual analysis when Scikit-Learn is ambiguous.
#
# @param      $1  Command string to analyze.
# @param      $2  Model name (defaults to llama3).
#
# @returns    Textual explanation of command intent and risk factor.
#-------------------------------------------------------------------------------
local_ollama(){
 
    if [[ -z "$SELECTED_MODEL_BASE_URL" ]]; then
        end_program 1 "${WHITE}API Error:${NC} Missing Model API URL. Verify models/$LLM_MODEL.py"
    fi

    length=${#PROMPT}
    textdebug 0 "Calling $PYTHON_BIN with $USER_LOCAL_DIR/models/$LLM_MODEL.py with prompt of size $length bytes"

    set +e    
    RESPONSE=$(printf '%s' "$PROMPT" | $PYTHON_BIN "$USER_LOCAL_DIR/models/$LLM_MODEL".py)
    set -e

    textdebug 0 "LOCALAI RESPONSE: $RESPONSE"

    # Check if empty OR if the JSON contains a top-level error key
    if [ -z "$RESPONSE" ] || [ "$(echo "$RESPONSE" | jq 'has("error")')" == "true" ]; then
        end_program 1 "${WHITE}Ollama API Error:${NC} $(echo "$RESPONSE" | jq -r '.error // "Unknown Error"')"
    fi

    if [[ "$DO_ASKONCE" != "true" ]]; then

        CONTENT=$(echo "$RESPONSE" | jq -r '.response')
        if [[ -n "$CONTENT" ]]; then
            COMMAND=$(echo "$CONTENT" | jq -r '.command // empty')
            EXPLANATION=$(echo "$CONTENT" | jq -r '.explanation // empty')
            NEW_FACT=$(echo "$CONTENT" | jq -r '.new_fact // empty')
            TASK_COMPLETED=$(echo "$CONTENT" | jq -r '.task_completed // empty')
            GOAL_COMPLETED=$(echo "$CONTENT" | jq -r '.goal_completed // empty')
            CONTEXT=$(echo "$RESPONSE" | jq -r '.content // empty')
        fi
        
        # Fix the Stats Math (using bc for decimals)
        TOTAL_NS=$(echo "$RESPONSE" | jq -r '.total_duration')
        SECONDS=$(echo "$TOTAL_NS / 1000000000" | bc)
    fi
}

#-------------------------------------------------------------------------------
# @function   get_token_count
# @description Approximates token count for LLM context management.
# @param      $1  The string to analyze.
# @returns    Integer token count.
#-------------------------------------------------------------------------------
get_token_count() {
    local text="$1"
    
    if [[ -z "$text" ]]; then
        echo 0
        return
    fi

    # Method 1: Character-based heuristic (Total chars / 4)
    # This is often safer for code-heavy strings.
    local char_count=$(echo -n "$text" | wc -m)
    local char_tokens=$(( char_count / 4 ))

    # Method 2: Word-based count
    local word_tokens=$(echo -n "$text" | wc -w)

    # Return the higher of the two to be safe (conservative estimation)
    if [ "$char_tokens" -gt "$word_tokens" ]; then
        echo "$char_tokens"
    else
        echo "$word_tokens"
    fi
}


#-------------------------------------------------------------------------------
# @function   analyze_prompt
# @description Orchestrates multi-layered analysis for ambiguous commands.
#              Primary: Local Scikit-Learn Heuristics (Low Latency).
#              Secondary: Remote LLM Contextual Analysis (High Reasoning).
#
# @param      $1  Prompt to analyze.
# @param      $2  Target ("local" | "remote") - Defaults to local.
#
# @returns    JSON-formatted string containing threat_score and reasoning.
#-------------------------------------------------------------------------------
analyze_prompt() {
    
    TOKENS=$(get_token_count "$PROMPT")

    CONTENT=""
    COMMAND=""
    EXPLANATION=""
    NEW_FACT=""
    TASK_COMPLETED=""
    GOAL_COMPLETED="" 
    
    # Call model
    echo -e "\n\n$PROMPT" >> $JOB_DIR/LOG
    if [ $LLM_MODEL == "local" ]; then
        if [[ -f "$USER_LOCAL_DIR/models/$LLM_MODEL".py ]]; then
            source "$USER_LOCAL_DIR/models/$LLM_MODEL".conf
            export GEMINI_API_KEY="$GEMINI_API_KEY"
            export MODEL_BASE_URL="$SELECTED_MODEL_BASE_URL"
            export SELECTED_CONTEXT_SIZE="$SELECTED_CONTEXT_SIZE"
            export MAX_TIMEOUT="$MAX_TIMEOUT"
            if [[ "$DO_ASKONCE" == "false" ]]; then
                textline 0 ""
                textbox 0 "${CYAN}» Polling the hive @ $SELECTED_MODEL_NAME [ctx $TOKENS]${NC} " "thinking"
            fi
            local_ollama
        fi
    else
       if [[ -f "$USER_LOCAL_DIR/models/$LLM_MODEL".py ]]; then
            source "$USER_LOCAL_DIR/models/$LLM_MODEL".conf
            export SELECTED_MODEL_NAME="$SELECTED_MODEL_NAME"
            export GEMINI_API_KEY="$GEMINI_API_KEY"
            export MAX_TIMEOUT="$MAX_TIMEOUT"
            if [[ "$DO_ASKONCE" == "false" ]]; then
                textline 0 ""
                textbox 0 "${CYAN}» Polling the hive @ $SELECTED_MODEL_NAME [ctx $TOKENS]${NC} " "thinking"
            fi
            remote_googleai
        fi
    fi
    echo -e "\n\n$RESPONSE" >> $JOB_DIR/LOG

    if [ -n "$NEW_FACT" ]; then
        textline 2 "${CYAN}» Storing new fact : $NEW_FACT${NC}"
        echo $NEW_FACT >> $JOB_DIR/FACTS
        sort -u -o "$JOB_DIR/FACTS" "$JOB_DIR/FACTS"
        echo "NEW FACT: $NEW_FACT" >> $JOB_DIR/JOURNAL
    fi

    if [ -n "$TASK_COMPLETED" ]; then
        textline 2 "${CYAN}» Completed task : $TASK_COMPLETED${NC}"
        echo "$TASK_COMPLETED" >> $JOB_DIR/TASKSCOMPLETED
    fi

    if [[ "$DO_ASKONCE" == "false" ]] && [[ "$DO_SILENT" == "false" ]]; then
        if [[ "$VERBOSE_LEVEL" -ge "1" ]]; then
            echo -e "\n${GREEN}─── GOAL ──────────────────────────────────────────────${NC}"
            echo -e "${WHITE}$GOAL${NC}"
            echo -e "${GREEN}─── COMMAND ───────────────────────────────────────────${NC}"
            echo -e "${WHITE}$COMMAND${NC}"
            echo -e "${GREEN}─── EXPLANATION ──────────────────────────────────────${NC}"
            echo -e "$EXPLANATION"
            echo -e "${GREEN}──────────────────────────────────────────────────────${NC}\n"
        else
            echo -e "$EXPLANATION"
        fi
    fi

    #echo -e "\n${CYAN}» STATS:${NC} Processed in ${WHITE}${SECONDS}s${NC}"
    textline 2 "» STATS: Processed in ${SECONDS}s" >> $JOB_DIR/JOURNAL
}



#-------------------------------------------------------------------------------
# @function   update_hive
# @description Synchronizes command intelligence across all security tiers.
#              - Updates RUN_NEVER or allowlist.txt for exact matching.
#              - Updates dataset.csv with label/weight for heuristic training.
#              - Purges stale .pkl models to force re-learning.
#
# @param      $1  Command string
# @param      $2  Label (0 for Safe, 1 for Malicious)
# @param      $3  Weight (Importance/Frequency 1-100)
#-------------------------------------------------------------------------------
update_hive() {
    local cmd=$1
    local label=$2
    local weight=$3

    export BEE_CMD_TO_SAVE="$cmd"   
    $PYTHON_BIN <<EOF
import pandas as pd
import os
import sys

file = '$JOB_DIR/cache/dataset.csv'
cmd_text = os.getenv('BEE_CMD_TO_SAVE', '')
# Use strings for label/weight initially to catch empty inputs
raw_label = "$label"
raw_weight = "$weight"

# --- 1. VALIDATION GATE ---
# Reject if command is empty or if label/weight are not valid numbers
try:
    if not cmd_text.strip():
        raise ValueError("Empty command")
    
    label_val = float(raw_label)
    weight_val = float(raw_weight)
    
    # Optional: Reject "example.com" hallucinations
    if "example.com" in cmd_text.lower():
        print("Discarding hallucinated placeholder URL.")
        sys.exit(0)

except (ValueError, TypeError):
    print(f"Skipping invalid hive update: CMD='{cmd_text}', L='{raw_label}', W='{raw_weight}'")
    sys.exit(0)

# --- 2. DATA PROCESSING ---
df = pd.read_csv(file) if os.path.exists(file) else pd.DataFrame(columns=['command','label','weight'])

# Ensure we don't have NaNs in existing data while we are at it
df = df.dropna(subset=['command', 'label'])

# Remove old entry to keep it lean
df = df[df['command'] != cmd_text]

# Add the new entry
new_row = pd.DataFrame({'command': [cmd_text], 'label': [label_val], 'weight': [weight_val]})
df = pd.concat([df, new_row], ignore_index=True)

df.to_csv(file, index=False)
EOF

    unset BEE_CMD_TO_SAVE
    HIVE_CHANGED="true"
    beelog "${CYAN}» Bee Retrained (Validated)${NC}"
}


#-------------------------------------------------------------------------------
# @function   update_hud_json
# @description Serializes hive telemetry into a unified JSON data-bus.
#              - Synchronizes UI variables (Goal, Focus, Tokens) for the HUD.
#              - Ensures type-safety and character escaping via jq.
#              - Provides a single source of truth for real-time monitoring.
#
# @globals     $GOAL, $FOCUS_SUMMARY, $TOKEN_COUNT, $BEE_STATUS, $SELECTED_MODEL_NAME
# @output      $WORKSPACE_DIR/stats.json
#-------------------------------------------------------------------------------
update_hud_json() {
    
    # Sanitize and fetch values (handling empty vars with defaults)
    local goal="${GOAL:-No goal set}"
    local focus="${FOCUS_SUMMARY:-Idle}"
    local tokens="${TOKEN_COUNT:-0}"
    local status="${BEE_STATUS:-Sensing}"
    local model="${SELECTED_MODEL_NAME:-Unknown}"
    local promptsize=${#PROMPT}
    local tokencount=$(get_token_count "$PROMPT")
    local requestcount=${CYCLE:0}

    # Use jq to build a valid JSON object safely
    # Linux 'mv' is an atomic operation.
    jq -n \
        --arg ver "$BEE_VERSION" \
        --arg goal "$goal" \
        --arg focus "$focus" \
        --arg status "$status" \
        --arg model "$model" \
        --arg tokens "$tokens" \
        --arg promptsize "$promptsize" \
        --arg tokencount "$tokencount" \
        --arg requestcount "$requestcount" \
        '{
            version: $ver,
            goal: $goal,
            focus: $focus,
            status: $status,
            model: $model,
            tokens: ($tokens | tonumber),
            timestamp: (now | strflocaltime("%H:%M:%S")),
            promptsize: ($promptsize | tonumber),
            tokencount: ($tokencount | tonumber),
            requestcount: ($requestcount | tonumber)
        }' > "$JOB_DIR/bee-stats.json.tmp"

    mv -f "$JOB_DIR/bee-stats.json.tmp" "$JOB_DIR/bee-stats.json"
}


replace_commands() {
     # Read the file line by line
    NEW_COMMAND=""
    while IFS=":" read -r pattern replacement; do
        # Skip empty lines or malformed entries
        [[ -z "$pattern" || -z "$replacement" ]] && continue

        # Strip quotes from the pattern and replacement
        pattern=$(echo "$pattern" | sed 's/^"//;s/"$//')
        replacement=$(echo "$replacement" | sed 's/^"//;s/"$//')

        # ---  VALIDATION STEP ---
        # We check if the command IS exactly the pattern 
        # OR if it starts with the pattern followed by a space
        if [[ "$COMMAND" == "$pattern" ]] || [[ "$COMMAND" == "$pattern "* ]]; then
            
            # Perform the substitution (global replace)
            NEW_COMMAND="${COMMAND//$pattern/$replacement}"
            
            # Only notify if a change actually happened
            if [[ "$COMMAND" != "$NEW_COMMAND" ]]; then
                textbox 1 "$ICON_BEE ADAPTED: Replacing '$pattern'" "for '$replacement'" "whatever"
                COMMAND="$NEW_COMMAND"
                break 
            fi
        fi
    done < "$1"
    return 0
}

normalize_command() {
    local s="$1"

    # Remove backslash-newline continuations
    s=$(printf '%s' "$s" | sed ':a;N;$!ba;s/\\\n//g')

    # Collapse repeated whitespace
    s=$(printf '%s' "$s" | tr '\t\r\n' '   ')
    s=$(printf '%s' "$s" | sed 's/[[:space:]]\+/ /g')

    # Remove simple quote splitting:
    # 'su''do'  -> sudo
    # "su""do" -> sudo
    s=$(printf '%s' "$s" | sed \
        -e "s/'[[:space:]]*'//g" \
        -e 's/"[[:space:]]*"//g')

    printf '%s\n' "$s"
}
contains_forbidden_token() {
    local cmd="$1"
    local token="$2"

    [[ "$cmd" =~ (^|[;&|()[:space:]])"$token"($|[;&|()[:space:]]) ]]
}
#-------------------------------------------------------------------------------
# @function   securitycheck
# @description Multilayered Heuristic & Signature-Based Security Analysis.
#              Orchestrates three tiers of command verification:
#              1. Blacklist (Hard Deny) - Exact string match from RUN_NEVER.
#              2. Allowlist (Hard Pass) - Exact string match from allowlist.txt.
#              3. Heuristic (Sensing) - SciKit-Learn ML inference for risk.
#
# @global      COMMAND             The command string to be evaluated.
# @global      MODE_AUTOMATIC      Defines thresholding (PERMISSIVE vs RESTRICTIVE).
# @global      AUTO_FIX_ENABLED    OUTPUT: Boolean flag flipped to "true" if 
#                                  command passes Tier 2 or Tier 3 criteria.
#
# @returns     0 on successful evaluation; exits with 1 on Blacklist match.
#-------------------------------------------------------------------------------
securitycheck() {

    DISALLOWED_BY=""
    DISALLOWED_COMMAND=""

    if [[ "$COMMAND" =~ [[:cntrl:]] ]]; then
        beelog "${RED}$ICON_CRITICAL CRITICAL: Control characters detected. Possible Smuggling Attempt.${NC}"
        DISALLOWED_BY="Default"
        DISALLOWED_COMMAND=$COMMAND
        return 0
    fi

    CLEAN_CMD=$(echo -n "$COMMAND" | tr -d '[:cntrl:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    textdebug 0 "DETECTOR: CLEAN_CMD=$CLEAN_CMD"

    NORMALIZED=$(normalize_command "$COMMAND")
    textdebug 2 "DETECTOR: NORMALIZED=$NORMALIZED"

    textdebug 0 "DETECTOR: Run GLOBAL rules"
    # --- GLOBAL FORBIDDEN STRING RULES ---
    textdebug 2 "DETECTOR: Run GLOBAL rules RUN_FORBIDDEN"
    if [[ -f "$USER_CONFIG_DIR/RUN_FORBIDDEN" ]]; then
        # Read the file line by line
        while IFS= read -r FORBIDDEN_STR || [[ -n "$FORBIDDEN_STR" ]]; do
            [[ -z "$FORBIDDEN_STR" ]] && continue

            # Check if the command line contains tokens that match the forbidden strings
            if contains_forbidden_token "$NORMALIZED" "$FORBIDDEN_STR"; then
                textline 1 "Access Denied: Found forbidden string '$FORBIDDEN_STR'"
                beelog "${RED}$ICON_CRITICAL CRITICAL: Forbidden string detected '$FORBIDDEN_STR'.${NC}"
                DISALLOWED_BY="ForbiddenList"
                DISALLOWED_COMMAND=$COMMAND
                return 0
            fi
        done < "$USER_CONFIG_DIR/RUN_FORBIDDEN"
    fi

    # --- GLOBAL WHITELIST LAYER ---
    textdebug 2 "DETECTOR: Run GLOBAL rules RUN_ALWAYS"
    if [[ -f "$USER_CONFIG_DIR/RUN_ALWAYS" ]]; then
        if sed 's/[[:space:]]*$//' "$USER_CONFIG_DIR/RUN_ALWAYS" | grep -xFq "$CLEAN_CMD"; then
            textbox 2 "${GREEN}$ICON_SUCCES SIGNATURE MATCH: Trusted global command detected.${NC}" "happy"
            AUTO_FIX_ENABLED="true"
            return 0
        fi
    fi
    # --- GLOBAL BLACKLIST LAYER ---
    textdebug 2 "DETECTOR: Run GLOBAL rules RUN_NEVER"
    if [[ -f "$USER_CONFIG_DIR/RUN_NEVER" ]]; then
        if sed 's/[[:space:]]*$//' "$USER_CONFIG_DIR/RUN_NEVER" | grep -xFq "$CLEAN_CMD"; then
            textbox 1 "${RED}$ICON_BLOCKED BLOCKLIST ALERT: This command is forbidden by global policy.${NC}" "dead"
            DISALLOWED_BY="Run rules"
            DISALLOWED_COMMAND=$COMMAND
            COMMAND=""
            return 0
        fi
    fi
    # --- GLOBAL REPLACEMENT LAYER (Normalization) ---
    textdebug 2 "DETECTOR: Run GLOBAL rules RUN_REPLACE"
    if [[ -f "$USER_CONFIG_DIR/RUN_REPLACE" ]]; then
        replace_commands "$USER_CONFIG_DIR/RUN_REPLACE"
    fi

    textdebug 0 "DETECTOR: Run JOB rules"
    # --- JOB FORBIDDEN STRING RULES ---
    if [[ -f "$JOB_DIR/config/RUN_FORBIDDEN" ]]; then
        # Read the file line by line
        while IFS= read -r FORBIDDEN_STR || [[ -n "$FORBIDDEN_STR" ]]; do
            if [[ -z "$FORBIDDEN_STR" ]]; then continue; fi

            # Check if the command line contains tokens that match the forbidden strings
            if contains_forbidden_token "$NORMALIZED" "$FORBIDDEN_STR"; then
                textline 1 "Access Denied: Found forbidden string '$FORBIDDEN_STR'"
                beelog "${RED}$ICON_CRITICAL CRITICAL: Forbidden string detected '$FORBIDDEN_STR'.${NC}"
                DISALLOWED_BY="ForbiddenList"
                DISALLOWED_COMMAND=$COMMAND
                return 0
            fi
        done < "$JOB_DIR/config/RUN_FORBIDDEN"
    fi
    # --- JOB WHITELIST LAYER ---
    if [[ -f "$JOB_DIR/config/RUN_ALWAYS" ]]; then
        if sed 's/[[:space:]]*$//' "$JOB_DIR/config/RUN_ALWAYS" | grep -xFq "$CLEAN_CMD"; then
            textbox 2 "${GREEN}$ICON_SUCCES SIGNATURE MATCH: Trusted job command detected.${NC}" "happy"
            AUTO_FIX_ENABLED="true"
            return 0
        fi
    fi
    # --- JOB BLACKLIST LAYER ---
    if [[ -f "$JOB_DIR/config/RUN_NEVER" ]]; then
        if sed 's/[[:space:]]*$//' "$JOB_DIR/config/RUN_NEVER" | grep -xFq "$CLEAN_CMD"; then
            textbox 1 "${RED}$ICON_BLOCKED BLOCKLIST ALERT: This command is forbidden by job policy.${NC}" "dead"
            DISALLOWED_BY="Run rules"
            DISALLOWED_COMMAND=$COMMAND
            COMMAND=""
            return 0
        fi
    fi
    # --- JOB REPLACEMENT LAYER (Normalization) ---
    if [[ -f "$JOB_DIR/config/RUN_REPLACE" ]]; then
        replace_commands "$JOB_DIR/config/RUN_REPLACE"
    fi

    # Without a detector only apply RUN rules
    textdebug 0 "DETECTOR: Probe SciKit"
    if [[ "$ENABLE_SCIKIT" == "false" ]] || [[ "$USE_ML_GUARD" == "false" ]]; then
        if [ $MODE_AUTOMATIC == "PERMISSIVE" ]; then
            textbox 1 "${RED}$ICON_SUCCES WARNING: Permissive mode. No rule found for command${NC}" "angry"
            return 0
        elif [ $MODE_AUTOMATIC == "RESTRICTIVE" ]; then
            textbox 1 "${RED}$ICON_SUCCES ALERT: Restrictive mode. No whitelist found for command${NC}" "angry"
            DISALLOWED_BY="Default"
            DISALLOWED_COMMAND=$COMMAND
            return 0
        fi
        textbox 1 "${RED}$ICON_SUCCES ALERT ALERT: Manual mode.${NC}" "angry"
        return 0
    fi

    if [[ $HIVE_CHANGED == "true" ]]; then
        textdebug 0 "DETECTOR: Clear data model"
        remove_hive_model
        HIVE_CHANGED="false"
    fi

    textdebug 0 "DETECTOR: $PYTHON_BIN $BASE_DIR/detector.py \"$JOB_DIR\" \"$COMMAND\" \"$VERBOSE_LEVEL\""
    echo "$PYTHON_BIN $BASE_DIR/detector.py \"$JOB_DIR\" \"$COMMAND\" \"$VERBOSE_LEVEL\"" >> $JOB_DIR/JOURNAL

    set +e
    $PYTHON_BIN $BASE_DIR/detector.py "$JOB_DIR" "$COMMAND" "$VERBOSE_LEVEL"
    PYRESULT=$?
    set -e
    
    textdebug 0 "DETECTOR: RESULT=$PYRESULT MODE:$MODE_AUTOMATIC"
    
    if [ $PYRESULT -eq 100 ]; then
        end_program 1 "${RED}$ICON_SUCCES SCIKIT SECURITY FAILURE: Missing parameter(s)${NC}"
    elif [ $PYRESULT -eq 101 ]; then
        end_program 1 "${RED}$ICON_SUCCES SCIKIT SECURITY FAILURE: Empty parameter detected ${NC}"
    elif [ $PYRESULT -eq 102 ]; then
        end_program 1 "${RED}$ICON_SUCCES SCIKIT SECURITY FAILURE: Job dir error${NC}"
    fi

    # Automatic signalling of allowed status
    textdebug 0 "DETECTOR: Signal status"
    if [ $MODE_AUTOMATIC == "PERMISSIVE" ]; then
        # 9 = Vantage (Low threat), 10 = Clear Water (Zero threat)
        if [ $PYRESULT -eq 9 ] || [ $PYRESULT -eq 10 ]; then
            textbox 2 "${GREEN}$ICON_SUCCES SCIKIT SECURITY NOTICE: Honeybee is flying by instinct ${NC}" "chill"
            AUTO_FIX_ENABLED="true"
        fi
    elif [ $MODE_AUTOMATIC == "RESTRICTIVE" ]; then
        if [ $PYRESULT -eq 10 ]; then
            textbox 2 "${GREEN}$ICON_SUCCES SCIKIT SECURITY NOTICE: Honeybee is flying by rule ${NC}" "chill"
            AUTO_FIX_ENABLED="true"
        fi
    fi

    # Skip further checks if on auto fix
    textdebug 0 "DETECTOR: Display results"
    if [ "$AUTO_FIX_ENABLED" == "false" ]; then

        # Only flag if result is NOT 0 (Manual), 9 (Vantage), or 10 (Clear Water)
        if [ "$PYRESULT" -ne 0 ] && [ "$PYRESULT" -ne 9 ] && [ "$PYRESULT" -ne 10 ]; then
            DISALLOWED_BY="SciKit"
            DISALLOWED_COMMAND=$COMMAND
        fi

        if [ -n "$DISALLOWED_COMMAND" ]; then
            textline 1 "${RED}$ICON_FAIL SCIKIT SECURITY ALERT:${NC} ${WHITE}Execution flagged by SciKit security check!${NC} ${ORANGE}($(get_eyes "angry"))${NC}"
            if [ "$DISALLOWED_BY" == "ForbiddenList" ]; then
                textline 1 "${RED}$ICON_FAIL${NC} ${WHITE}The AI tried to run a command with a forbidden string: $word${NC} ${RED}($(get_eyes "dead"))${NC}"
            else
                textline 1 "${RED}$ICON_FAIL${NC} ${WHITE}The AI tried to run the high risk command: $COMMAND${NC} ${RED}($(get_eyes "dead"))${NC}"
            fi
        else
            textline 2 "${GREEN}$ICON_SUCCES SCIKIT SECURITY NOTICE:${NC} ${WHITE}Command verified: $PYRESULT ${NC} ${GOLD}($(get_eyes "happy"))${NC}"
        fi
    fi
}



bee_signal() {
    local job="${1:-}"
    local state="${2:-}"
    local cmd="${3:-}"

    if [[ -z $QUEEN_IP ]] || [[ -z $QUEEN_PORT ]] || [[ -z $SECRET_KEY ]]; then
        return
    fi
    if is_lan_address "$QUEEN_IP"; then
        REPORT_IP="$LAN_IP"
    else
        REPORT_IP="$WAN_IP"
    fi
    #MY_ID="$(whoami)@$(hostname)"
    MY_ID="$REPORT_IP"
    #MY_ID="$(whoami)@$REPORT_IP"
    MY_PID="$$"

    # Inner Data uses |
    PAYLOAD="${MY_ID}#${MY_PID}#${JOB_NAME}#$state#$(date +%s)#$cmd"

    # Generate Signature (The -n is CRITICAL here)
    SIG=$(printf %s "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET_KEY" | sed 's/^.* //')

    # Fire Packet (NO -n on the final echo, we want the newline for the Queen's 'read')
    echo "$PAYLOAD:::$SIG" > "/dev/udp/$QUEEN_IP/$QUEEN_PORT"
}

is_lan_address() {
    local ip="${1:-}"
    # Check for:
    # 127.x.x.x (Loopback)
    # 10.x.x.x (Private)
    # 172.16.0.0 – 172.31.255.255 (Private)
    # 192.168.x.x (Private)
    # localhost
    if [[ "$ip" =~ ^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.) ]] || [[ "$ip" == "localhost" ]]; then
        return 0 # It's LAN
    else
        return 1 # It's WAN
    fi
}


# Start with existing or new custom prompt or followup input

bee_signal "$JOB_NAME" "STARTING"


# If asking a question then finish when answered
DO_ASK="false"
if [[ "$DO_ASKONCE" == "false" ]] && [[ "$PARAM_PROMPT" == *"?"* ]]; then
    DO_ASK="true"
    textdebug 2 "Starting Ask mode."
    INPUT="Answer this question by executing bash commands. Answer in the json EXPLANATION field. Mark GOAL_COMPLETED as "true" in the json field once the question is answered. $PARAM_PROMPT"
else
    INPUT="$PARAM_PROMPT"
fi
GOAL="$INPUT"

if [[ -f "$JOB_DIR/config/DEFAULT_INPUT" ]]; then
    DEFAULT_INPUT=$(cat $JOB_DIR/config/DEFAULT_INPUT)
else
    end_program 1 "Missing default input in $JOB_DIR/config/DEFAULT_INPUT ${RED}($(get_eyes "angry"))${NC}"
fi

if [[ "$DO_ASKONCE" == "true" ]]; then
    if [[ "$INPUT" == "" ]]; then
        textbox 0 "${CYAN}» Enter a question${NC}" "whatever"
        end_program    
    fi

elif [[ "$DO_ASK" == "true" ]]; then
    textbox 0 "${CYAN}» Answering question ${NC}" "fly"

elif [[ "$IS_NEW_JOB" == "true" ]]; then
    # Start New Job 
    if [[ "$INPUT" == "" ]] || [[ "$INPUT" == "Continue" ]]; then
        if [[ "$JOB_NAME" == "default" ]]; then
            textbox 0 "${CYAN}» Departing hive for new default flight path${NC}" "fly"
        else
            textbox 0 "${CYAN}» Departing hive for new flight path for '$JOB_NAME'${NC}" "fly"
        fi
        INPUT=$DEFAULT_INPUT
        GOAL=$INPUT

    else
        textbox 0 "${CYAN}» Departing hive for new custom flight '$JOB_NAME'${NC}" "$INPUT" "fly"]
    fi
    cleanup_workspace
    echo $GOAL > $JOB_DIR/GOAL
    echo -e "$INPUT\n"
    IS_NEW_JOB=false # Continue as 'running' in next loop
    
else
    # Continue job
    if [[ -f "$JOB_DIR/GOAL" ]]; then
        GOAL=$(cat $JOB_DIR/GOAL)
    else
        GOAL=$DEFAULT_INPUT
        echo $GOAL > $JOB_DIR/GOAL
    fi
    if   [[ "$INPUT" == "" ]]; then
        textbox 0 "${CYAN}» Resuming last flight '$JOB_NAME:$PACKAGE_VERSION' ${NC}" "fly"
    else
        textbox 0 "${CYAN}» Resuming last flight '$JOB_NAME:$PACKAGE_VERSION' with hint${NC}" "$INPUT" "fly"
    fi
    # or head + tail history better ?
    if [[ -f "$JOB_DIR/JOURNAL" ]]; then
        HISTORY=$(cat "$JOB_DIR/JOURNAL")  
    else
        HISTORY=""
    fi    
    if [[ "$INPUT" == "" ]]; then
        INPUT="$DEFAULT_INPUT"
    fi
    textline 2 "GOAL: $GOAL"
fi





############################################################
# MAIN LOOP
############################################################


# Initialization
DISALLOWED_COMMAND=""
DISALLOWED_BY=""
GOAL_COMPLETED="false"
JOB_COMPLETED="false"
RESULT=""

# Prepare as current default job
if [[ -n "$JOB_SESSION_FILE" ]]; then   
    echo "$JOB_NAME:$PACKAGE_VERSION" > "$JOB_SESSION_FILE"
fi

while [[ "$JOB_COMPLETED" == "false" ]]; do
    textdebug 0 "\n\nMain Loop cycle : $CYCLE"; 
    echo "$$" > "$JOB_DIR/PID"
    (( CYCLE++ )) || true
    echo $CYCLE > "$JOB_DIR/CYCLE"
    
    # Check runtime monitor Quit command
    if [[ -f "$JOB_DIR/MONITORCOMMAND" ]]; then
        MONITORREPLY=$(cat $JOB_DIR/MONITORCOMMAND)
        if [[ "$MONITORREPLY" == "HALT" ]]; then
            end_program 0 "Halting Bee by Monitor command"
        fi
    fi

    # -t 0.1 : Only wait 0.1 seconds before continuing
    # -n 1   : Stop waiting as soon as ONE key is pressed
    read -t 0.1 -n 1 key_pressed || true
    if [[ "${key_pressed:-}" == "f" ]]; then
        textbox 0 "${CYAN}» Manual follow-up${NC}" "$DISALLOWED_COMMAND" "waiting"
        echo -n "Enter your follow-up instructions: "
        read -r FOLLOW_UP
        echo "FOLLOWUP $FOLLOW_UP" >> $JOB_DIR/REASONING
    elif [[ "${key_pressed:-}" == "q" ]]; then
        textbox 0 "${CYAN}» Exitting by user request.${NC}" "happy"
        bee_signal "$JOB_NAME" "DONE"
        end_program
    fi
    
    # Get fresh input
    textdebug 0 "Obtain fresh scope"
    if [[ -f "$JOB_DIR/config/BEE_PROFILE" ]]; then
        PROFILE=$(cat $JOB_DIR/config/BEE_PROFILE)
    else
        end_program 1 "${RED} MISSING:${NC} The BEE_PROFILE file is missing." "Add one describing the agent profile in $JOB_DIR/config/BEE_PROFILE." "shock" 
    fi
    
    if [[ -f "$JOB_DIR/config/BEE_RULES" ]]; then
        RULES=$(cat $JOB_DIR/config/BEE_RULES)
        # Support dynamic $JOB_DIR replacement in BEE_RULES
        RULES="${RULES//\$JOB_DIR/$JOB_DIR}"
    else
        end_program 1 "${RED} MISSING:${NC} The BEE_RULES file is missing." "Add one describing the rules to follow in $JOB_DIR/config/BEE_RULES." "shock" 
    fi 
    
    CURRENT_DIR=$(pwd)
    COMMANDLOG=""
    ADDITIONAL=""
    TASKS_COMPLETED=""
    DATASET=""
    if [[ -f "$JOB_DIR/COMMANDLOG" ]]; then
        COMMANDLOG=$(cat "$JOB_DIR/COMMANDLOG" 2>/dev/null)
    fi
    if [[ -f "$JOB_DIR/ADDITIONAL" ]]; then
        ADDITIONAL=$(cat "$JOB_DIR/ADDITIONAL" 2>/dev/null)
    fi
    if [[ -f "$JOB_DIR/TASKSCOMPLETED" ]]; then
        TASKS_COMPLETED=$(cat "$JOB_DIR/TASKSCOMPLETED" 2>/dev/null)
    fi
    if [[ -f "$JOB_DIR/cache/dataset.csv" ]]; then
        DATASET=$(cat "$JOB_DIR/cache/dataset.csv" 2>/dev/null)
    fi
    LAST_COMMAND="$COMMAND"
    
    # Assure that input ends with a dot
    TRIMMED="${INPUT%"${INPUT##*[![:space:]]}"}"
    if [[ "$TRIMMED" != *. ]]; then
        INPUT="$INPUT."
    fi
    
    textdebug 0 "Action $CYCLE"; 

    # If just asking then ask, answer and exit
    if [[ "$DO_ASKONCE" == "true" ]] || [[ "$TEST_MODE" == "true" ]]; then

        # Entering test mode
        if [[ "$TEST_MODE" == "true" ]]; then
            PROMPT="Report if you are available in plain text."
        else
            PROMPT="Answer the following question and respond with all your response as plain text: $INPUT"
        fi
        
        textdebug 2 "INPUT=$PROMPT"

        analyze_prompt

        if [[ -z "$RESPONSE" ]]; then
            echo -e "\nThe LLM has no answer. Rephrase the question to try again."
        else
            echo -e "\n$RESPONSE"
        fi

        if [[ "$TEST_MODE" == "true" ]]; then
            textbox 0 "${CYAN}» Test run succesfully completed.${NC}" "fly"
            end_program
        fi

        #EXPLANATION=$(echo "$RESPONSE" | jq -r '.explanation // empty')
        #if [[ -n "$EXPLANATION" ]]; then
        #    echo $EXPLANATION;
        #fi

        end_program

    # If the PLAN is generated then start or continue work on it
    elif [[ -f "$JOB_DIR/PLAN" ]]; then
        textbox 2 "${CYAN}» Buzzing with a plan${NC}" "fly"

        PLAN=""
        FACTS=""
        if [[ -f "$JOB_DIR/PLAN" ]]; then
            PLAN=$(cat "$JOB_DIR/PLAN" 2>/dev/null)
        fi
        if [[ -f "$JOB_DIR/FACTS" ]]; then
            FACTS=$(cat "$JOB_DIR/FACTS" 2>/dev/null)
        fi

        HISTORY=""
        if [[ -f "$JOB_DIR/HISTORY" ]]; then
            TMP=$(tail -n $HISTORY_DEPTH $JOB_DIR/HISTORY 2>/dev/null)
            if [ -z "$TMP" ]; then
                HISTORY="We have just started so this will be the first command."
            else
                HISTORY="The history of commands and results so far is: $TMP"
            fi
        fi

        NOTES=""
        if [[ "$RUNNING_COMMAND" != "" ]]; then
            NOTES="\nLast command got interupted: $RUNNING_COMMAND"
            RUNNING_COMMAND=""
        fi

        PROMPT="### SYSTEM INSTRUCTIONS
$PROFILE
$RULES
$ADDITIONAL

### ENVIRONMENT
$ENV

### Initial GOAL and PLAN
$GOAL
$PLAN

### TASKS COMPLETED SO FAR
$TASKS_COMPLETED

### TASK / FOLLOWUP
$INPUT$NOTES

### COMMANDS EXECUTED SO FAR
$COMMANDLOG

### FOUND FACTS
$FACTS

### LAST COMMAND
$COMMAND

### RESULT OF LAST COMMAND
$RESULT"

# removed context as its pure chronolical causing state differences garbling the vector prediction path
### LAST CONTEXT
#$CONTEXT

# ### WORK HISTORY SO FAR
# $HISTORY"


        # Limit context length if needed (larger )
        length=${#PROMPT}
        limit=${SELECTED_CONTEXT_SIZE:-4096} # Default to 4096 if CONTEXT_SIZE is missing

        if [[ "$length" -gt "$limit" ]]; then
            RESULT="(to large to include)"
        fi

        PROMPT="### SYSTEM INSTRUCTIONS
$PROFILE
$RULES
$ADDITIONAL

### ENVIRONMENT
$ENV

### Initial GOAL and PLAN
$GOAL
$PLAN

### TASK / FOLLOWUP
$INPUT$NOTES

### COMMANDS EXECUTED SO FAR
$COMMANDLOG

### LAST COMMAND
$COMMAND

### RESULT OF LAST COMMAND
$RESULT"


        echo "$PROMPT" >> $JOB_DIR/PROMPTLOG
        echo "$PROMPT" > $JOB_DIR/LASTPROMPT

        textdebug 2 "INPUT=$INPUT"

        bee_signal "$JOB_NAME" "THINKING"

        analyze_prompt

        # Check if the goal-completed exists in the response (after last command )
        if [[ "$GOAL_COMPLETED" == "true" ]]; then
            textbox 
            textbox 0 "${CYAN}» Job complete. 100% nectar collected. Hive-bound.${NC}" "happy"

            echo "JOB COMPLETED" >> $JOB_DIR/HISTORY
            echo "REASON: $EXPLANATION" >> $JOB_DIR/HISTORY
            echo " " >> $JOB_DIR/HISTORY

            echo "INPUT: $INPUT" >> $JOB_DIR/JOURNAL
            echo "PROMPT: $PROMPT" >> $JOB_DIR/JOURNAL
            echo "RESPONSE: $RESPONSE" >> $JOB_DIR/JOURNAL
            echo "EXPLANATION: $EXPLANATION" >> $JOB_DIR/JOURNAL
            echo "JOB COMPLETED" >> $JOB_DIR/JOURNAL
            echo " " >> $JOB_DIR/JOURNAL

            echo -e "\nGOAL: $GOAL" > $JOB_DIR/FOCUS
            echo -e "EXPLANATION: $EXPLANATION" >> $JOB_DIR/FOCUS
            echo -e "GOAL COMPLETED: true" >> $JOB_DIR/FOCUS

            echo "$EXPLANATION" > $JOB_DIR/EXPLANATION
            
            JOB_COMPLETED="true"
            bee_signal "$JOB_NAME" "DONE"
            echo "done" > $JOB_DIR/JOBCOMPLETED
            
            end_program
        
        elif [ -z "$COMMAND" ]; then
            COMMAND="Continue"

        else
            
            textbox 2 "${CYAN}» Sensing for hostile signature [$LLM_MODEL,$MODE_AUTOMATIC]${NC}" "> $COMMAND" "looking" 

            # Sanitize
            COMMAND=$(echo "$COMMAND" | sed 's/ -it / /g' | sed 's/ -t / /g')

            AUTO_FIX_ENABLED="false"
            
            securitycheck

            if [ -z "$COMMAND" ] && [[ "$DISALLOWED_BY" != "" ]]; then
                texterror "${RED}» Command rejected${NC}" "$LAST_COMMAND" "dead"
                AUTO_FIX_ENABLED="false"
                COMMAND=""
            fi

            if [[ "$COMMAND" != "" ]]; then
                echo "NEXT COMMAND: $COMMAND" > $JOB_DIR/NEXTACTION
                echo "EXPLANATION: $EXPLANATION" >> $JOB_DIR/NEXTACTION

                echo -e "\nCOMMAND: $COMMAND" >> $JOB_DIR/REASONING
                echo "EXPLANATION: $EXPLANATION" >> $JOB_DIR/REASONING

                # Allow execution check but skip allowed autofix commands
                FOLLOW_UP=""
                if [ "$AUTO_FIX_ENABLED" == "true" ]; then
                    textbox 2 "${CYAN}» Known nectar, engaging Auto mode${NC}" "nectar" 
                    DISALLOWED_COMMAND=""
                    DISALLOWED_BY=""
                    #update_hive "$COMMAND" 0 1
                    rm -f $JOB_DIR/PENDINGREQUEST
                    rm -f $JOB_DIR/PENDINGUSERRESPONSE

                elif [[ "$DISALLOWED_COMMAND" != "" ]] && [[ "$MODE_AUTOMATIC" == "RESTRICTIVE" ]]; then
                    textbox 1 "${CYAN}» Skipping due to rule by $DISALLOWED_BY${NC}" "$DISALLOWED_COMMAND" "whatever" 
                    echo "SKIPPING by rule of $DISALLOWED_BY" >> $JOB_DIR/REASONING
                    INPUT="The following commandline was not allowed: $DISALLOWED_COMMAND"
                    COMMAND=""
                    DISALLOWED_BY=""
                    DISALLOWED_COMMAND=""
                    rm -f $JOB_DIR/PENDINGREQUEST
                    rm -f $JOB_DIR/PENDINGUSERRESPONSE

                else
                    count=101
                    REPLY=""
                    while [[ "$JOB_COMPLETED" == "false" ]]; do
                        
                        echo "$COMMAND" > $JOB_DIR/PENDINGREQUEST
                        textline 0 ""                    
                        textbox 0 "${STYLE_QUEST}  EXECUTE ? ${NC} [Yes/Once/Skip/Always/Never/Replace/Followup/Quit]:" "> $COMMAND" "waiting" 
                        
                        while [[ -z "$REPLY" ]]; do
                            # signal alive every 20 seconds second
                            ((count++)) || true
                            if (( count > 100 )); then
                                count=0
                                bee_signal "$JOB_NAME" "WAITING"
                            fi

                            # Check for the response file from monitor.sh
                            if [[ -f "$JOB_DIR/PENDINGUSERRESPONSE" ]]; then
                                REPLY=$(cat $JOB_DIR/PENDINGUSERRESPONSE)
                                if [[ "$REPLY" == "y" ]] || [[ "$REPLY" == "o" ]]|| [[ "$REPLY" == "s" ]] || [[ "$REPLY" == "a" ]] || [[ "$REPLY" == "n" ]] || [[ "$REPLY" == "q" ]]; then
                                    rm -f $JOB_DIR/PENDINGREQUEST
                                    rm -f $JOB_DIR/PENDINGUSERRESPONSE
                                else
                                    REPLY=""
                                    rm -f $JOB_DIR/PENDINGUSERRESPONSE
                                fi
                                break
                            fi
                            # Short check for a keypress (timeout of 0.1s)
                            if [[ -z "$REPLY" ]]; then
                                read -t 0.1 -n 1 -r key_pressed || true
                                if [[ -n "${key_pressed:-}" ]]; then
                                    REPLY="$key_pressed"
                                    break
                                fi
                            fi
                            sleep 0.1
                        done

                        textline 0 ""

                        # ${REPLY,,} converts the input to lowercase automatically
                        case "${REPLY,,}" in
                            o) # ONCE no training
                                textbox 0 "${CYAN}» Manually allowed once${NC}" "$DISALLOWED_COMMAND" "happy" 
                                break ;;
                            y) # YES
                                textbox 0 "${CYAN}» Manually approved${NC}" "$DISALLOWED_COMMAND" "happy" 
                                W=1; L=0; update_hive "$COMMAND" $L $W; 
                                break ;;
                            a) # Always (Weight 10)
                                textbox 0 "${CYAN}» Manually approved for always${NC}" "$DISALLOWED_COMMAND" "rich" 
                                W=100; L=0; update_hive "$COMMAND" $L $W; 
                                echo "$COMMAND" >> $JOB_DIR/config/RUN_ALWAYS 
                                sort -u -o "$JOB_DIR/config/RUN_ALWAYS" "$JOB_DIR/config/RUN_ALWAYS"
                                break ;;
                            s) # SKIP
                                textbox 0 "${CYAN}» Manually skipped${NC}" "$DISALLOWED_COMMAND" "annoyed" 
                                echo "SKIPPED the command" >> $JOB_DIR/REASONING
                                W=1; L=1; update_hive "$COMMAND" $L $W; 
                                FOLLOW_UP="Last command '$COMMAND' was skipped. Try an alternative or move on."
                                COMMAND=""
                                break ;;
                            n) # NEVER (Weight 10 + Label 1)
                                textbox 0 "${CYAN}» Manually rejected for always${NC}" "$DISALLOWED_COMMAND" "annoyed" 
                                echo "REJECTED for always" >> $JOB_DIR/REASONING
                                W=100; L=1; update_hive "$COMMAND" $L $W; 
                                echo "$COMMAND" >> $JOB_DIR/config/RUN_NEVER
                                sort -u -o "$JOB_DIR/config/RUN_NEVER" "$JOB_DIR/config/RUN_NEVER"
                                FOLLOW_UP="Last command '$COMMAND' was rejected for ever. Do not use this again."
                                COMMAND=""
                                break ;;
                            r) # REPLACE
                                textbox 0 "${CYAN}» Manually replacing${NC}" "$DISALLOWED_COMMAND" "waiting"
                                echo -n "Enter the replacement command: "
                                read -r COMMAND_REPLACEMENT
                                echo "REPLACED by $COMMAND_REPLACEMENT" >> $JOB_DIR/REASONING
                                echo "\"$COMMAND\":\"$COMMAND_REPLACEMENT\"" >> $JOB_DIR/config/RUN_REPLACE
                                sort -u -o "$JOB_DIR/config/RUN_REPLACE" "$JOB_DIR/config/RUN_REPLACE"
                                COMMAND="$COMMAND_REPLACEMENT"
                                break ;;
                            f) # FOLLOW
                                textbox 0 "${CYAN}» Manual follow-up${NC}" "$DISALLOWED_COMMAND" "waiting"
                                echo -n "Enter your follow-up instructions: "
                                read -r FOLLOW_UP
                                echo "FOLLOWUP: $FOLLOW_UP" >> $JOB_DIR/REASONING
                                break ;;

                            q) # QUIT
                                textbox 0 "${CYAN}» Exitting by user request.${NC}" "happy"
                                bee_signal "$JOB_NAME" "DONE"
                                end_program
                                ;;
                            *)
                                # Handles Enter, Space, or any other key
                                echo -e "${GOLD}⚠ Please press either of Yes/Once/Skip/Always/Never/Replace/Followup or 'q' to quit.${NC}"
                                ;;
                        esac
                    done
                    bee_signal "$JOB_NAME" "RUNNING"
                fi
            fi

            textdebug 0 "Execute command"
            rm -f $JOB_DIR/PENDINGREQUEST
            rm -f $JOB_DIR/PENDINGUSERRESPONSE

            # Respond to Monitor Halt comment
            if [[ -f "$JOB_DIR/MONITORCOMMAND" ]]; then
                MONITORREPLY=$(cat $JOB_DIR/MONITORCOMMAND)
                if [[ "$MONITORREPLY" == "HALT" ]]; then
                    end_program 0 "Halting Bee by Monitor command."
                fi
            fi
            rm -f $JOB_DIR/MONITORCOMMAND
            
            if [ -n "$COMMAND" ];then
                if [ -z "$FOLLOW_UP" ];then
                    textbox 0 "${GOLD}» Executing on target:${NC}" "$COMMAND" "blink"

                    echo "$COMMAND" >> $JOB_DIR/COMMANDLOG

                    if [[ "$COMMAND" =~ ^cd\ (.*) ]]; then
                        NEW_DIR="${BASH_REMATCH[1]}"
                        # Use 'eval' to handle ~ or variables in the path, then update CURRENT_DIR
                        CURRENT_DIR=$(pwd)
                        TEMP_DIR=$(eval "cd $CURRENT_DIR && cd $NEW_DIR && pwd")
                        if [ $? -eq 0 ]; then
                            CURRENT_DIR="$TEMP_DIR"
                            cd $CURRENT_DIR
                            RESULT="Directory changed to: $CURRENT_DIR"
                            echo $RESULT
                            echo -e "${CYAN}» Directory changed to:${NC} $COMMAND"
                        else
                            RESULT="Error: Directory does not exist: $COMMAND"
                            echo $RESULT
                        fi
                    else
                        echo "$(date +%s) | $COMMAND" > $JOB_DIR/RUNNINGCOMMAND

                        # Send UDP Heartbeat to QueenBee
                        bee_signal "$JOB_NAME" "RUNNING" 
                        # RESULT=$($SUDO_CMD "$COMMAND" 2>&1)
set +e
RESULT=$($SUDO_CMD "$COMMAND" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    textdebug 0 "Execution failed with code $EXIT_CODE"
    textdebug 0 "RESULT=$RESULT"
    # Continue running, report to LLM
    # end_program $EXIT_CODE "Execution failed with code $EXIT_CODE"
else
    textdebug 0 "RESULT=$RESULT"
fi

                        bee_signal "$JOB_NAME" "ACTIVE"
                        rm -f $JOB_DIR/RUNNINGCOMMAND

                        textline 0 "${CYAN}» Executed on target:\n${NC}> $COMMAND\n"
                        # Spinner attempt
                        #eval "$COMMAND" > "RESULT" 2>&1 &
                        #PID=$!
                        #spinner $PID
                        #RESULT=$(cat $WORKSPACE_DIR/RESULT)
                    fi

                    echo "\$ $COMMAND" >> $JOB_DIR/HISTORY
                    echo "$RESULT" >> $JOB_DIR/HISTORY
                    echo " " >> $JOB_DIR/HISTORY

                    echo "INPUT: $INPUT" >> $JOB_DIR/JOURNAL
                    echo "PROMPT: $PROMPT" >> $JOB_DIR/JOURNAL
                    echo "RESPONSE: $RESPONSE" >> $JOB_DIR/JOURNAL
                    echo "NEXT COMMAND: $COMMAND" >> $JOB_DIR/JOURNAL
                    echo "EXPLANATION: $EXPLANATION" >> $JOB_DIR/JOURNAL
                    echo "COMMAND RESULT: $RESULT" >> $JOB_DIR/JOURNAL
                    echo " " >> $JOB_DIR/JOURNAL

                    if [ -z "$RESULT" ]; then
                        INPUT="There was no output."
                        textline 0 "${CYAN}» No output found.${NC}"
                    fi

                    length=${#RESULT} 
                    if [ "$length" -gt "$FILTER_TRIGGER" ]; then
                        if [[ "$COMMAND" =~ "logs" ]]; then
                            textline 1 "${CYAN}» Log result is to long. Filtering.${NC}\n"
                            echo "$RESULT" > $JOB_DIR/RESULT
                            echo "This result is shortened by removing all numbers and duplicate lines;" > $JOB_DIR/RESULT2
                            tr -d '0-9' < $JOB_DIR/RESULT | sort -u >> $JOB_DIR/RESULT2
                            RESULT=$(cat $JOB_DIR/RESULT2)

                            # 3. Shorten to the first 1000 characters
                            #PROMPT="${PROMPT:0:1000}"
                        else
                            textline 1 "${CYAN}» Result is to long ($length chars). Truncating.${NC}\n"
                            RESULTTMP=$(echo "$RESULT" | tail -n $HISTORY_DEPTH)
                            RESULT="$RESULTTMP\nResult was to long and has been truncated."
                        fi
                    fi

                    # Limit context size
                    CLEAN_RESULT=$(echo "$RESULT" | tail -n $HISTORY_DEPTH)
                    INPUT="The result of '$COMMAND' is '$CLEAN_RESULT'"

                    echo -e "\nGOAL: $GOAL" > $JOB_DIR/FOCUS
                    echo -e "\nPLANNING:\n$PLAN" >> $JOB_DIR/FOCUS 
                    echo -e "\nINPUT: $INPUT" >> $JOB_DIR/FOCUS
                    echo -e "\nINPUT: $INPUT" >> $JOB_DIR/FOCUS
                    echo -e "\nRESULT: $CLEAN_RESULT" >> $JOB_DIR/FOCUS
                    echo -e "\nNEXT: $COMMAND" >> $JOB_DIR/FOCUS
                    echo -e "\nEXPLANATION: $EXPLANATION" >> $JOB_DIR/FOCUS

                    # Limit response size as desired
                    if [[ "$DO_CAP_RESPONSE" == "true" ]]; then
                        TMP_CLEAN_RESULT="${CLEAN_RESULT:0:$DO_MAX_CAP_RESPONSE}"
                        textline 0 "$TMP_CLEAN_RESULT\n"
                    else
                        textline 0 "$CLEAN_RESULT\n"
                    fi

                    update_hud_json
                else
                    # Process FollowUp
                    echo "\$ $COMMAND" >> $JOB_DIR/HISTORY
                    echo "COMMAND CANCELED BY USER" >> $JOB_DIR/HISTORY
                    echo "REASON: $FOLLOW_UP" >> $JOB_DIR/HISTORY
                    echo " " >> $JOB_DIR/HISTORY

                    echo "INPUT: $INPUT" >> $JOB_DIR/JOURNAL
                    echo "PROMPT: $PROMPT" >> $JOB_DIR/JOURNAL
                    echo "RESPONSE: $RESPONSE" >> $JOB_DIR/JOURNAL
                    echo "NEXT COMMAND: $COMMAND" >> $JOB_DIR/JOURNAL
                    echo "EXPLANATION: $EXPLANATION" >> $JOB_DIR/JOURNAL
                    echo "COMMAND CANCELED BY USER" >> $JOB_DIR/JOURNAL
                    echo "REASON: $FOLLOW_UP" >> $JOB_DIR/JOURNAL
                    echo " " >> $JOB_DIR/JOURNAL

                    echo $FOLLOW_UP >> $JOB_DIR/ADDITIONAL

                    echo -e "\nGOAL: $GOAL" > $JOB_DIR/FOCUS
                    echo -e "\nPLANNING:\n$PLAN" >> $JOB_DIR/FOCUS
                    echo -e "\nINPUT: $INPUT" >> $JOB_DIR/FOCUS
                    echo -e "\nFOLLOW UP: $FOLLOW_UP" >> $JOB_DIR/FOCUS
                    echo -e "EXPLANATION: $EXPLANATION" >> $JOB_DIR/FOCUS

                    echo "$EXPLANATION" > $JOB_DIR/EXPLANATION

                    INPUT="$FOLLOW_UP"
                    echo -e "$INPUT\n"

                    update_hud_json
                fi
            fi

            echo "" > $JOB_DIR/NEXTACTION
        fi


    else
        # Write a plan first
        #echo "${CYAN}» Generating task plan${NC}"
        textbox 2 "${CYAN}» Homing in on target${NC}" "thinking"

        PLANNING_RULES=$(cat $JOB_DIR/config/BEE_PLANNING)
        INPUT_TMP=$INPUT
        TASK="Write a plan with the tasks to complete this job:\n$INPUT\n\nPlace the plan as one ascii text string in the explanation field of a JSON structure."
        INPUT="$PLANNING_RULES\n$TASK\nRULES ARE:\n$PROFILE\n$RULES\n$ENV"
        PROMPT=$INPUT

        echo -e "$TASK\n"
        echo "$PROMPT" >> $JOB_DIR/PROMPTLOG
        echo "$PROMPT" > $JOB_DIR/LASTPROMPT

        textdebug 2 "INPUT+=$PLANNING_RULES"

        analyze_prompt

        if [[ $EXPLANATION != "" ]]; then
            echo "$EXPLANATION" > $JOB_DIR/PLAN
            INPUT="$INPUT_TMP"
            INPUT_TMP=""

            echo -e "\nGOAL: $GOAL" > $JOB_DIR/FOCUS
            echo -e "\nPLANNING:\n$EXPLANATION" >> $JOB_DIR/FOCUS
            echo -e "\nINPUT: $INPUT" >> $JOB_DIR/FOCUS
            echo -e "\nNEXT: $INPUT\n" >> $JOB_DIR/FOCUS
            
            update_hud_json
        else
            textbox 1 "${CYAN}» No PLAN received. Trying again.${NC}" "annoyed"
        fi
    fi

    if [[ -n "$DO_BEE_DELAY" ]]; then
        sleep $DO_BEE_DELAY
    else 
        sleep $BEE_DELAY
    fi
done

