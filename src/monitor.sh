#!/usr/bin/env bash

# ------------------------------------------------------------------------------
#         '\     /`
#      ___  \___/  ___      HONEYBEEBASH / MONITOR.SH 
#     /   \ (0 0) /   \     _________________________________
#    |  M  |  X  |  M  |    AUTONOMOUS MAINTENANCE
#    |_____/ @@@ \_____|    QUAD-TIERED RISK MIGITATION 
#            @@@@@          SIGNATURE + HEURISTIC + LLM
#             @@@           _________________________________
#              V            SCIKIT PANDA SECURITY RESEARCH
# ------------------------------------------------------------------------------
# PROJECT:   MONITOR.SH (The HoneyBee Bash Bee Monitor)
# PURPOSE:   Monitor and control Bee jobs
# ------------------------------------------------------------------------------
# @version   1.0.5
# @author    M.D.P de Clerck (mike@clerck.nl)
# © 2026     M.D.P de Clerck, the Netherlands
# @license   GNU General Public License version 3
# ------------------------------------------------------------------------------


# --- If sudo active then detect real user for profiles ---
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER="$(whoami)"
fi
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
if [[ -z "$REAL_HOME" ]]; then
    REAL_HOME="$HOME"
fi

# --- Paths ---
BASE_DIR="/opt/honeybeebash"

# --- User specific paths ---
USER_CONFIG_DIR="$REAL_HOME/.config/honeybeebash"
USER_LOCAL_DIR="$REAL_HOME/.local/share/honeybeebash"

# --- Include configuration --- 
source "$USER_CONFIG_DIR/bee.conf"

# --- Defaults ---
TAB_NAME="DASHBOARD"
max_lines=25
max_coloms=80


clear


# --- Detect running job ---
if [ -t 0 ]; then
    # We are in an interactive terminal
    TTY_ID=$(tty | sed 's/\//_/g') 
    JOB_SESSION_FILE="$HOME/.bee_session${TTY_ID}"

    # Overwrite current job for this TTY, else load from TTY
    if [[ -n "$JOB_SESSION_FILE" && -f "$JOB_SESSION_FILE" ]]; then
        SESSION_JOB=$(cat "$JOB_SESSION_FILE")
        JOB_NAME="${SESSION_JOB%%:*}"
        JOB_NAME=${JOB_NAME,,}
        PACKAGE_VERSION="${SESSION_JOB#*:}"
        PACKAGE_VERSION=${PACKAGE_VERSION,,}
    fi
fi


# --- Detect input for job selection ---
JOB_NAME="default"
if [[ $1 != "" ]]; then
    JOB_NAME=${$1,,}
    JOB_NAME=${JOB_NAME,,}
    PACKAGE_VERSION="${$1#*:}"
    PACKAGE_VERSION=${PACKAGE_VERSION,,}
fi
if [[ -z "$PACKAGE_VERSION" ]]; then
    PACKAGE_VERSION="default"
fi

if [[ $2 != "" ]]; then
    PARENT_SHELL="$2"
else
    PARENT_SHELL=""
fi


# --- Workspace paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WSP="$USER_LOCAL_DIR/workspace/$JOB_NAME/$PACKAGE_VERSION"
STATS_FILE="$WSP/bee-stats.json"


if [[ ! -d $WSP ]]; then
    mkdir -p $WSP
fi

# --- [ Hive HUD Config ] ---
if [[ -z "$HIVE_DIR" ]]; then
    HIVE_DIR=""
    MASTER_STATE=""
else
    MASTER_STATE="$HIVE_DIR/hive_master.state"
fi


tput civis # Hide cursor
trap "tput cnorm; clear; exit" SIGINT SIGTERM


print_banner() {
    # Script banner
    echo -e "${GOLD}=============================================${NC}"
    echo -e "${GOLD}"
    echo -e "         '\     /\'        ${WHITE}$BEE_NAME MONITOR ${GOLD}"
    echo -e "      ___  \___/  ___      __________________"
    echo -e "     /   \ (0 0) /   \    | SWITCHING TO ${GOLD}"
    echo -e "    |  M  |  X  |  M  |   |   ${GOLD}"
    echo -e "    |_____/ @@@ \_____|   | $1 ${GOLD}"
    echo -e "           @@@@@           __________________|"
    echo -e "            @@@                                    "
    echo -e "             V                                     "
    echo -e "                                                   "
    echo -e "${GOLD}=============================================${NC}"
    echo -e "${NC}"
}

wrap_print() {
    local text="$1"
    local width="$2"
    local start_row="$3"
    local start_col="$4"
    local max_rows="$5"  # <--- New Limit Argument
    
    local line_count=0
    
    # We use 'fmt' or manual slicing to wrap the text
    echo "$text" | fold -s -w "$width" | while read -r line; do
        if [ "$line_count" -lt "$max_rows" ]; then
            tput cup $((start_row + line_count)) "$start_col"
            echo -ne "${WHITE}${line}${NC}"
            ((line_count++))
        else
            # Optional: Print an ellipsis to show there was more text
            tput cup $((start_row + line_count - 1)) $((start_col + width - 3))
            echo -ne "${GOLD}...${NC}"
            break
        fi
    done
}

# --- [ Helper: Surgical Text Clipping ] ---
# Strips ANSI, clips to width, keeps the UI borders clean
safe_print() {
    local text="$1"
    local width=$2
    local color="$3"
    
    # Strip ANSI and clip
    local clean=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g' | cut -c1-$width)
    
    # Calculate how many spaces we need to fill the rest of the column width
    local padding_count=$(( width - ${#clean} ))
    local padding=""
    if [ $padding_count -gt 0 ]; then
        padding=$(printf '%*s' "$padding_count" "")
    fi

    # Print: Color + Text + Padding (to overwrite ghosts) + Reset
    echo -ne "${color}${clean}${padding}${NC}"
}

# Function to count lines in files safely
count_lines() { 
    [ -f "$1" ] && wc -l < "$1" || echo "0"; 
}



# --- DISK LOGIC ---
get_disk_util() {
    local path=$1
    local label=$2

    # Get the device name (e.g., sdb2 or nvme0n1p2)
    local dev=$(df "$path" | tail -1 | awk '{print $1}')
    # Get the parent disk (e.g., sdb or nvme0n1)
    local disk=$(lsblk -no PKNAME "$dev" 2>/dev/null | tr -d '[:space:]')

    # If no parent (it IS the disk), just use the basename
    [ -z "$disk" ] && disk=$(basename "$dev")

    # If we still have nothing, skip to avoid the lsblk error
    if [ -z "$disk" ]; then
        draw_bar 0 "$label [Empty]"
        return
    fi

    local t1=$(awk -v d="$disk" '$3==d {print $13}' /proc/diskstats)
    sleep 0.4
    local t2=$(awk -v d="$disk" '$3==d {print $13}' /proc/diskstats)

    local util=$(( (t2 - t1) / 4 ))
    draw_bar "$util" "$label"
}

show_disk_util() {
    # 1. Get the percentages
    ROOT_PERC=$(get_disk_usage "/")
    MODELS_PERC=$(get_disk_usage "/mnt/models")

    # 2. Draw the bars
    draw_bar "$ROOT_PERC" "System (/)"
    draw_bar "$MODELS_PERC" "Models(/mnt)"
}

# Function to get clean integer percentage from a path
get_disk_usage() {
    local path=$1
    # df output: "Use%" followed by " 25%" -> tail/tr/sed to get just "25"
    df "$path" | awk 'NR==2 {print $5}' | tr -d '%'
}

get_active_speed() {
    # Grab the last 100 lines to ensure we find a finished task
    # Look for the 'eval rate' line
    local last_speed_line=$(docker logs --tail 100 ollama 2>&1 | grep "eval rate" | tail -n 1)

    # Extract just the number before 'tokens/s'
    # This regex is a bit more 'bash-friendly'
    local tps_val=$(echo "$last_speed_line" | sed -n 's/.*eval rate: \([0-9.]*\) tokens\/s.*/\1/p')

    if [ -z "$tps_val" ]; then
        draw_bar 0 "Speed (Idle)"
    else
        # Convert float to int (e.g. 4.56 -> 4)
        local tps_int=${tps_val%.*}
        # Scale: 30 TPS is a full bar
        local bar_val=$(( tps_int * 3 ))
        draw_bar "$bar_val" "Speed: ${tps_val} t/s"
    fi
}

get_disk_util_old() {
    local mount_path=$1
    local custom_label=$2

    # Identify physical disk from mount point
    local dev_path=$(findmnt -nvo SOURCE "$mount_path")
    local target_disk=$(lsblk -no PKNAME "$dev_path")
    [ -z "$target_disk" ] && target_disk=$(basename "$dev_path")

    # Sample IO time
    local t1=$(awk -v d="$target_disk" '$3==d {print $13}' /proc/diskstats)
    sleep 0.5
    local t2=$(awk -v d="$target_disk" '$3==d {print $13}' /proc/diskstats)

    # Calculate utilization (delta ms / 5 for a 500ms sleep)
    local util=$(( (t2 - t1) / 5 ))

    # REUSE your bar function here
    draw_bar "$util" "$custom_label"
}

get_swap(){
    # --- SWAP ---
    read sw_total sw_used < <(swapon --bytes | tail -n 1 | awk '{print $3, $4}')
    sw_perc=$(( sw_total > 0 ? 100 * sw_used / sw_total : 0 ))
    draw_bar "$sw_perc" "SWAP FILE"
}

get_ollama_stats() {
    local stats=$(docker exec ollama ollama ps 2>&1 | tail -n +2)

    # Check if model exists
    if [[ "$stats" == *"such container"* ]]; then
        echo -e "${RED}Could not find Ollama.${NC}"; return
    elif [ -z "$stats" ]; then
        echo -e "${RED}No model currently loaded.${NC}"; return
    fi

    local model_name=$(echo "$stats" | awk '{print $1}')
    local gpu_perc=0
    local cpu_perc=0

    # THE AGGRESSIVE PARSE
    # Look for the pattern "Number% / Number%" first
    if [[ "$stats" =~ ([0-9]+)%/([0-9]+)% ]]; then
        cpu_perc="${BASH_REMATCH[1]}"
        gpu_perc="${BASH_REMATCH[2]}"
    # If no slash, check if "GPU" is mentioned at all
    elif [[ "$stats" == *"GPU"* ]]; then
        gpu_perc=100
        cpu_perc=0
    # If only "CPU" is mentioned
    elif [[ "$stats" == *"CPU"* ]]; then
        gpu_perc=0
        cpu_perc=100
    fi

    # Final display
    echo -e "\n--- OLLAMA RESOURCE SPLIT ($model_name) ---"
    draw_bar "$gpu_perc" "VRAM Usage"
    draw_bar "$cpu_perc" "RAM Spill"
}


get_cpu_load(){
    # --- CPU LOAD (1m, 5m, 15m) ---
    # Read the first three values from /proc/loadavg
    read load1 load5 load15 < /proc/loadavg

    # Calculate percentages based on core count
    # We use 'bc' or 'awk' for float math since Bash only does integers
    p1=$(awk -v l="$load1" -v c="$cpu_cores" 'BEGIN {printf "%.0f", (l/c)*100}')
    p5=$(awk -v l="$load5" -v c="$cpu_cores" 'BEGIN {printf "%.0f", (l/c)*100}')
    p15=$(awk -v l="$load15" -v c="$cpu_cores" 'BEGIN {printf "%.0f", (l/c)*100}')

    draw_bar "$p1" "LOAD 1m"
    draw_bar "$p5" "LOAD 5m"
    draw_bar "$p15" "LOAD 15m"
}

get_queue_depth() {
    # Count established connections to the Ollama API port
    local connections=$(docker exec ollama netstat -an 2>&1 | grep :11434 | grep ESTABLISHED | wc -l)

    if [[ "$connections" == *"such container"* ]]; then
        echo -e "${RED}\n             Could not find Ollama.${NC}"
        return
    elif [ -z "$connections" ]; then
          echo -e "${RED}\n             No model currently loaded in Ollama.${NC}"
          return
    fi

    # Subtract 1 (the current running task) to see the 'Waitlist'
    local queue=$(( connections - 1 ))

    if [ "$queue" -gt 0 ]; then
        echo -e "${R}QUEUE        $queue tasks waiting${NC}"
    else
        echo -e "${G}QUEUE        Idle/Single${NC}"
    fi
}

get_ram(){
    # --- SYSTEM RAM ---
    # Simplified 'Used' calculation using 'free' columns directly
    # Used = Total - Free - Shared - Buff/Cache (or just grab the 'used' column)
    read r_total r_used < <(free -b | grep "Mem:" | awk '{print $2, $3}')
    r_perc=$(( 100 * r_used / r_total ))
    draw_bar "$r_perc" "SYSTEM RAM"
}

get_vram(){
    # --- VRAM (NVIDIA) ---
    t_used=0
    t_total=0
    # Process each GPU and calculate totals for the pool bar
    while IFS=, read -r idx name used total; do
        u=$(echo $used | xargs)
        t=$(echo $total | xargs)
        t_used=$(( t_used + u ))
        t_total=$(( t_total + t ))

        v_perc=$(( t > 0 ? 100 * u / t : 0 ))
        draw_bar "$v_perc" "VRAM GPU $idx"
    done < <(nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv,noheader,nounits)

    # --- TOTAL VRAM POOL ---
    pool_perc=$(( t_total > 0 ? 100 * t_used / t_total : 0 ))
    echo -e "--------------------------------------------------------------"
    draw_bar "$pool_perc" "TOTAL VRAM"
    echo -e "Used: $(( t_used )) MB / $(( t_total )) MB"
}

draw_bar() {
    local perc=$1
    local label=$2
    local width=50

    # Clamp percentage between 0 and 100 to prevent bar overflow/negative errors
    if [ "$perc" -lt 0 ]; then perc=0; fi
    if [ "$perc" -gt 100 ]; then perc=100; fi

    local filled=$(( (perc * width) / 100 ))
    local empty=$(( width - filled ))

    local color="\033[32m" # Green
    if [ $perc -gt 85 ]; then color="\033[31m"; # Red
    elif [ $perc -gt 60 ]; then color="\033[33m"; fi # Yellow
    local reset="\033[0m"

    printf "%-12s [" "$label"
    printf "${color}"
    for ((i=0; i<filled; i++)); do printf "█"; done
    printf "${reset}"
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "] %3d%%\n" "$perc"
}

refresh_count=0
systemmonitor() {

    HOSTNAME=$(hostname)

    # Colors
    C='\033[0;36m' # Cyan
    W='\033[1;37m' # White
    B='\033[0;34m' # Blue
    R='\033[0m'    # Reset
    G='\033[0;32m' # Green
    RED='\033[0;31m'

    trap "echo -e '\nMonitoring stopped.'; exit" SIGINT SIGTERM
    cpu_cores=$(nproc)

    ((refresh_count++))
    if (( refresh_count > 10 )); then
        clear
        refresh_count=0
    else
        printf "\033[H"
    fi
    
    statusbar
    tput cup 3 0

    show_disk_util
    get_swap
    echo " "
    get_ram
    get_vram
    echo " "
    get_cpu_load
    get_ollama_stats
    get_active_speed
    get_queue_depth
    echo " "
    get_disk_util "/" "System (sda)"
    get_disk_util "/mnt/models" "Models (sdb)"
    echo " "
    #docker logs ollama --tail 2
}

# TOP BAR
systembar() {
    GOAL=$(cat "$WSP/GOAL" 2>/dev/null)
    RAM=$(free -m | awk '/Mem:/ {printf "%d/%dMB", $3, $2}')
    VRAM_ROW=5
    CARD_COUNT=0
    DISK=$(df -h . | awk 'NR==2 {print $4}')
    CHILD_COUNT=$(pgrep -P $TARGET_PID | wc -l)

    # READ TELEMETRY
    if [[ -f "$STATS_FILE" ]]; then
        eval $(jq -r '@sh "V_VER=\(.version) V_GOAL=\(.goal) V_FOCUS=\(.focus) V_STATUS=\(.status) V_MODEL=\(.model) V_TOKENS=\(.tokens) V_TIME=\(.timestamp) V_PROMPTSIZE=\(.promptsize) V_TOKENCOUNT=\(.tokencount) V_REQUESTCOUNT=\(.requestcount)"' "$STATS_FILE")
    fi

    if [[ -z PARENT_SHELL ]]; then
        SHELL_COL=""
    else
        SHELL_COL=""
    fi

    # SENSE THE ENVIRONMENT
    COLS=$(tput cols); 
    RAW_LINES=$(tput lines); 
    LINES=$((RAW_LINES - 1))
    COL1=$((COLS * 60 / 100)); COL2=$((COLS * 20 / 100)); COL3=$((COLS - COL1 - COL2))
    P1=""; P2=""; P3=""
    if [ "$COLS" -lt 100 ]; then
        P1="${GOLD}${ICON_BEE}HB${NC} │ $(date +%T) │ ${SHELL_COL}$(uname -n | cut -d. -f1) ${GOLD}│ ${CYAN}${TAB_NAME}${NC}"
        P2=" JOB ${CYAN}$JOB_NAME${NC}"
        P3=" │ PID ${CYAN}${TARGET_PID}${NC} │ CHLD ${CYAN}${CHILD_COUNT}${NC}"
    elif [ "$COLS" -lt 140 ]; then
        P1="${GOLD} ${ICON_BEE}HONEYBEE ${V_VER:-1.0} ${NC}│ $(date +%T) │ ${SHELL_COL}$(whoami)@$(uname -n)${NC} ${GOLD}│ TAB ${CYAN}$TAB_NAME${NC}"
        P2=" │ JOB ${CYAN}$JOB_NAME${NC} │ ${CYAN}${MODE_AUTOMATIC:-MANUAL}${NC}#${CYAN}${V_MODEL:-N/A}${NC}"
        P3=" │ PID ${CYAN}$TARGET_PID${NC} │ CHLD ${CYAN}$CHILD_COUNT${NC}"
    else
        P1="${GOLD} ${ICON_BEE}HONEYBEE ${V_VER:-1.0} ${NC}│ $(date +%T) │ ${SHELL_COL}$(whoami)@$(uname -n)${NC} | TAB ${CYAN}$TAB_NAME${NC}"
        P2=" │ JOB ${CYAN}$JOB_NAME${NC} │ MODE ${CYAN}${MODE_AUTOMATIC:-MANUAL}${NC} │ MODEL ${CYAN}${V_MODEL:-N/A}${NC}"
        P3=" │ PID ${CYAN}$TARGET_PID${NC} │ CHILDREN ${CYAN}$CHILD_COUNT${NC}"
    fi

    tput cup 0 0; tput el
    echo -ne "${P1}${P2}${P3}"

    # DRAW THE SEPARATOR LINE
    tput cup 1 0; tput el
    printf '━%.0s' $(seq 1 "$COLS")
}

# BOTTOM BAR 1
statusbar() {
    # Gather environment
    COLS=$(tput cols)
    RAW_LINES=$(tput lines)
    LINES=$((RAW_LINES - 1))

    # Position and Clear
    tput cup $((LINES - 1)) 0; tput el
    printf '━%.0s' $(seq 1 "$COLS")
    
    tput cup $((LINES - 1)) 0; tput el

    # Detect Bee Execute manual approval request (The Priority UI)
    if [[ -f "$WSP/PENDINGREQUEST" ]] && [[ ! -f "$WSP/PENDINGUSERRESPONSE" ]]; then
        PENDING=$(cat "$WSP/PENDINGREQUEST")
        # Flash the background to grab attention
        echo -ne "${RED}${STYLE_QUEST} ⚠ EXECUTE? :${NC} ${PENDING:0:50}.. ${GOLD}[Y/O/S/A/N/E/Z]?${NC}"
        return
    fi

    # Gathering Meta-Data
    #CPULOAD=$(uptime | awk -F'load average: ' '{print $2}' | awk -F',' '{print $1}') # Just 1m load
    #CPULOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d',' -f1 | xargs)
    CPULOAD=$(uptime | awk -F'load average: ' '{print $2}')
    C_ALWAYS=$(count_lines "$WSP/config/RUN_ALWAYS")
    C_NEVER=$(count_lines "$WSP/config/RUN_NEVER")
    C_REPLACE=$(count_lines "$WSP/config/RUN_REPLACE")
    C_FACTS=$(count_lines "$WSP/FACTS")
    C_CMD=$(count_lines "$WSP/COMMANDLOG")
    C_DATASET=$(count_lines "$WSP/cache/dataset.csv")
    PKL_SIZE=$(du -sh "$WSP/cache/model.pkl" 2>/dev/null | awk '{print $1}' || echo "0")
    if [[ -f "$WSP/BEEFACE" ]]; then
        FACE=$(sed -n '2p' "$WSP/BEEFACE")
    else
        FACE=""
    fi
    if [[ "$SELECTED_LOG" == "" ]]; then
        FACE="" # Taking up space for now
    fi

    # Process Status
    if [[ "$TARGET_PID" != "0" ]]; then
        if kill -0 "$TARGET_PID" 2>/dev/null; then
            STATUS_DIS="${GREEN}RUNNING"
        elif [[ -f $JOB_DIR/JOBCOMPLETED ]]; then
            STATUS_DIS="${CYAN}DONE"
        else
            STATUS_DIS="${RED}STALLED"
        fi 
    else
        STATUS_DIS="${RED}STOPPED"
    fi

    # Output based on available width
    P1=""; P2=""; P3=""
    if [ "$COLS" -lt 100 ]; then
        P1="$FACE${GOLD} LOAD:${WHITE}$CPULOAD${GOLD}"
        P2=" │ SCIRULES:${WHITE}$C_DATASET${GOLD} │ SIGS:${WHITE}+$C_ALWAYS / -$C_NEVER / ~$C_REPLACE${GOLD}"
        P3=" | PROMPT:${WHITE}$V_TOKENCOUNT${NC} tokens${GOLD} │ STATUS:${WHITE}$STATUS_DIS${GOLD} │ REQUESTS:${WHITE}$V_REQUESTCOUNT${GOLD} " 
    elif [ "$COLS" -lt 150 ]; then
        P1="$FACE${GOLD} LOAD:${WHITE}$CPULOAD${GOLD}"
        P2=" | BRAIN:${WHITE}$PKL_SIZE${GOLD}  │ SCIRULES:${WHITE}$C_DATASET${GOLD} │ SIGS:${WHITE}+$C_ALWAYS / -$C_NEVER / ~$C_REPLACE${GOLD}"
        P3=" | PROMPT:${WHITE}$V_TOKENCOUNT${NC} tokens${GOLD} │ STATUS:${WHITE}$STATUS_DIS${GOLD} │ REQUESTS:${WHITE}$V_REQUESTCOUNT${GOLD} " 
    else
        P1="$FACE${GOLD} LOAD:${WHITE}$CPULOAD${GOLD}"
        P2=" | BRAIN:${WHITE}$PKL_SIZE${GOLD}  │ SCIRULES:${WHITE}$C_DATASET${GOLD} │ SIGS:${WHITE}+$C_ALWAYS / -$C_NEVER / ~$C_REPLACE${GOLD} │ FACTS:${WHITE}$C_FACTS${GOLD} │ HIST:${WHITE}$C_CMD${GOLD}"
        P3=" | PROMPT:${WHITE}$V_TOKENCOUNT${NC} tokens${GOLD} │ STATUS:${WHITE}$STATUS_DIS${GOLD} │ REQUESTS:${WHITE}$V_REQUESTCOUNT${GOLD} " 
    fi

    echo -ne "${P1}${P2}${P3}"
}

# Block with system information
vitals() {
    # CONTENT RIGHT (20%): VITALS + BEEFACE + TASKS
    tput cup 2 $((COL1 + COL2 + 1)); 
    echo -ne "${GOLD}┃ ${CYAN}VITALS${NC}"
    tput cup 3 $((COL1 + COL2 + 2)); 
    echo "CPU: $(uptime | awk -F'load average: ' '{print $2}' | sed 's/,//g')"

    # RAM
    tput cup 4 $((COL1 + COL2 + 2)); echo -ne "RAM: $RAM"
    # Define the start row for VRAM (right under RAM)
    # Query all GPUs: returns "used, total" for each
    # Output example: 1024, 8192
    while IFS=', ' read -r used total; do
        # Only show up to 4 cards to keep the HUD clean
        [[ $CARD_COUNT -ge 4 ]] && break
        # Format the string: "GPU0: 1024/8192MB"
        VRAM_STR="GPU${CARD_COUNT}: ${used}/${total}MB"
        # Position the cursor for this specific card
        tput cup $((VRAM_ROW + CARD_COUNT)) $((COL1 + COL2 + 2))
        # Print and clear the rest of the line so it doesn't bleed
        echo -ne "${VRAM_STR}"
        ((CARD_COUNT++))
    done < <(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null)

    # Update the DISK row so it doesn't get buried by the GPUs
    # We place it 1 row below the last card found
    tput cup $((VRAM_ROW + CARD_COUNT)) $((COL1 + COL2 + 2))
    echo -ne "DISK: $DISK"

    # The Bee Face
    if [[ -f "$WSP/BEEFACE" ]]; then
        frow=0
        offset=0
        while read -r faceline; do
            # Column: Still using your +20 math
            tput cup $((3 + frow)) $((COL1 + COL2 + 21 + offset))
            # Replace 'thinking and waiting'
            if (( RANDOM % 2 )); then
                faceline="${faceline/o O/O o}"
            fi
            # Print the face line in Gold
            echo -ne "${GOLD}${faceline}${NC}"
            ((frow++))
            # Safety: Don't let a weirdly long file overwrite your whole screen
            [[ $frow -ge 3 ]] && break
        done < "$WSP/BEEFACE"
    fi
}

progress_monitor() {
    # CONTENT LEFT (60%): JOB & FOCUS
    
    tput cup 2 1; echo -ne "${GOLD}${ICON_PLAY} JOB${NC}"
    tput cup 3 3; wrap_print "${WHITE}$GOAL${NC}" 80 3 3 3

    # --- [ NEXTACTION SECTION ] ---
    tput cup 5 1; echo -ne "${GOLD}${ICON_PLAY} CURRENT COMMAND            ${NC}"
    if [[ -f "$WSP/NEXTACTION" ]]; then
        f_row=0
        cat "$WSP/NEXTACTION" | while read -r line; do
            tput cup $((6 + f_row)) 3; 
            safe_print "$line" $((COL1 - 8)) "$WHITE"
            tput cup $((6 + f_row)) $COL1; echo -ne "${GOLD}┃${NC}"
            ((f_row++))
        done
    fi

    # --- [ BEELOG SECTION ] ---
    tput cup 10 1; echo -ne "${GOLD}${ICON_PLAY} BEE ACTIONS${NC}"
    if [[ -f "$WSP/BEELOG" ]]; then
        local max_lines=8
        local max_coloms=80
        local c_row=0
        # Process Substitution keeps the loop in the main shell
        while read -r cmd; do
            # Skip empty lines if any
            [[ -z "$cmd" ]] && continue
            tput cup $((11 + c_row)) 3
            padding=$(( max_coloms - ${#cmd} ))
            printf "%s%${padding}s" "$cmd" " "
            
            # Repair the vertical divider
            tput cup $((11 + c_row)) $COL1; echo -ne "${GOLD}┃${NC}"
            
            ((c_row++))
            # Safety cap: don't overwrite the bottom bar
            [[ $c_row -ge $((max_lines)) ]] && break
        done < <(tail -n $((max_lines)) "$WSP/BEELOG")
        for ((i=$((c_row)); i<$((max_lines)); i++)); do
            tput cup $((11 + i)) 1;
            printf "%$((max_coloms))s" " "
        done
    else
        tput cup 11 3; echo -ne "${RED}BEELOG NOT FOUND${NC}"
    fi

    # --- [ COMMANDLOG SECTION ] ---
    tput cup 20 1; echo -ne "${GOLD}${ICON_PLAY} COMMANDLOG${NC}"
    if [[ -f "$WSP/COMMANDLOG" ]]; then
        local max_lines=8
        local max_coloms=80
        local c_row=0
        # Process Substitution keeps the loop in the main shell
        while read -r cmd; do
            # Skip empty lines if any
            [[ -z "$cmd" ]] && continue
            tput cup $((21 + c_row)) 3
            padding=$(( max_coloms - ${#cmd} ))
            printf "%s%${padding}s" "$cmd" " "
            
            # Repair the vertical divider
            tput cup $((21 + c_row)) $COL1; echo -ne "${GOLD}┃${NC}"
            
            ((c_row++))
            # Safety cap: don't overwrite the bottom bar
            [[ $c_row -ge $((max_lines)) ]] && break
        done < <(tail -n $((max_lines)) "$WSP/COMMANDLOG")
        for ((i=$((c_row)); i<$((max_lines)); i++)); do
            tput cup $((21 + i)) 1;
            printf "%$((max_coloms))s" " "
        done
    else
        tput cup 21 3; echo -ne "${RED}COMMANDLOG NOT FOUND${NC}"
    fi


    # CONTENT CENTER (20%): PLAN
    tput cup 2 $((COL1 + 1))
    echo -ne "${GOLD}┃ ${CYAN}PLAN${NC}"
    if [[ -f "$WSP/PLAN" ]]; then
        TEXT=$(cat "$WSP/PLAN")
        WRAP_WIDTH=$((COL2 - 6))
        wrap_print "$TEXT" "$WRAP_WIDTH" 3 $((COL1 + 3)) 20
    fi
    prow=0

    vitals

    tput cup 11 $((COL1 + COL2 + 1)); 
    echo -ne "${GOLD}┃ ${CYAN}LAST COMPLETED${NC}"
    if [[ -f "$WSP/TASKSCOMPLETED" ]]; then
        TEXT=$(tail -n 3 "$WSP/TASKSCOMPLETED")
        WRAP_WIDTH=$((COL2 - 6))
        wrap_print "$TEXT" "$WRAP_WIDTH" 12 $((COL1 + COL2 + 3)) 20
    fi

    # VERTICAL DIVIDERS
    for ((i=2; i<LINES - 1; i++)); do
        tput cup $i $COL1; echo -ne "${GOLD}┃${NC}"
        tput cup $i $((COL1 + COL2)); echo -ne "${GOLD}┃${NC}"
    done
}

edit_file() {
    if [[ -n "$TEXT_EDITOR" ]]; then
        if [[ -f $TEXT_EDITOR ]]; then
            if [[ -n "$SELECTED_LOG" ]]; then
                $TEXT_EDITOR $SELECTED_LOG
            elif [[ -n "$SELECTED_RULE" ]]; then
                $TEXT_EDITOR $SELECTED_RULE
            fi
        fi
    fi
}

process_monitor() {
    # CONTENT LEFT (60%): JOB & FOCUS

    # --- [ BEELOG SECTION ] ---
    tput cup 2 1; echo -ne "${GOLD}${ICON_PLAY} BEE ACTIONS${NC}"
    if [[ -f "$WSP/BEELOG" ]]; then
        local max_lines=8
        local max_coloms=80
        local c_row=0
        # Process Substitution keeps the loop in the main shell
        while read -r cmd; do
            # Skip empty lines if any
            [[ -z "$cmd" ]] && continue
            tput cup $((3 + c_row)) 3
            padding=$(( max_coloms - ${#cmd} ))
            printf "%s%${padding}s" "$cmd" " "
            
            # Repair the vertical divider
            #tput cup $((11 + c_row)) $COL1; echo -ne "${GOLD}┃${NC}"
            
            ((c_row++))
            # Safety cap: don't overwrite the bottom bar
            [[ $c_row -ge $((max_lines)) ]] && break
        done < <(tail -n $((max_lines)) "$WSP/BEELOG")
        for ((i=$((c_row)); i<$((max_lines)); i++)); do
            tput cup $((3 + i)) 1;
            printf "%$((max_coloms))s" " "
        done
    else
        tput cup 3 3; echo -ne "${RED}BEELOG NOT FOUND${NC}"
    fi

    # --- [ COMMANDLOG SECTION ] ---
    tput cup 12 1; echo -ne "${GOLD}${ICON_PLAY} COMMANDLOG${NC}"
    if [[ -f "$WSP/COMMANDLOG" ]]; then
        local max_lines=5
        local max_coloms=80
        local c_row=0
        # Process Substitution keeps the loop in the main shell
        while read -r cmd; do
            # Skip empty lines if any
            [[ -z "$cmd" ]] && continue
            tput cup $((13 + c_row)) 3
            padding=$(( max_coloms - ${#cmd} ))
            printf "%s%${padding}s" "$cmd" " "
            
            # Repair the vertical divider
            #tput cup $((13 + c_row)) $COL1; echo -ne "${GOLD}┃${NC}"
            
            ((c_row++))
            # Safety cap: don't overwrite the bottom bar
            [[ $c_row -ge $((max_lines)) ]] && break
        done < <(tail -n $((max_lines)) "$WSP/COMMANDLOG")
        for ((i=$((c_row)); i<$((max_lines)); i++)); do
            tput cup $((13 + i)) 1;
            printf "%$((max_coloms))s" " "
        done
    else
        tput cup 13 3; echo -ne "${RED}COMMANDLOG NOT FOUND${NC}"
    fi

    # Middle horizontal divider
    tput cup 17 0; echo -e "${GOLD}"; printf '━%.0s' $(seq 1 $COLS); echo -e "${NC}"

    # PS tree
    tput cup 19 0

    if [[ "$TARGET_PID" -gt "0" ]]; then
        pstree -pa $TARGET_PID
    else
        echo "No Target PID detected. Is Bee running ?"
    fi

    # CONTENT CENTER (20%): PLAN
    #tput cup 2 $((COL1 + 1))
    #echo -ne "${GOLD}┃ ${CYAN}PLAN${NC}"
    #if [[ -f "$WSP/PLAN" ]]; then
    #    TEXT=$(cat "$WSP/PLAN")
    #    WRAP_WIDTH=$((COL2 - 4))
    #    wrap_print "$TEXT" "$WRAP_WIDTH" 3 $((COL1 + 3)) 20
    #fi
    prow=0
   
    vitals

    tput cup 11 $((COL1 + COL2 + 1)); 
    echo -ne "${GOLD}┃ ${CYAN}LAST COMPLETED${NC}"
    if [[ -f "$WSP/TASKSCOMPLETED" ]]; then
        TEXT=$(tail -n 1 "$WSP/TASKSCOMPLETED")
        WRAP_WIDTH=$((COL2 - 6))
        wrap_print "$TEXT" "$WRAP_WIDTH" 12 $((COL1 + COL2 + 3)) 20
    fi
    
    # Repair borders for the Right rows
    #for ((i=0; i<CARD_COUNT + 5; i++)); do
    #    tput cup $((2 + i)) $((COLS - 1))
    #    echo -ne "${GOLD}┃${NC}"
    #done

    # VERTICAL DIVIDERS
    for ((i=2; i<LINES-20; i++)); do
        #tput cup $i $COL1; echo -ne "${GOLD}┃${NC}"
        tput cup $i $((COL1 + COL2)); echo -ne "${GOLD}┃${NC}"
    done
}

SELECTED_JOB=""
show_jobs() {
    if [[ -z "$SELECTED_JOB" ]]; then
        DIRS=()
        for d in "$USER_LOCAL_DIR/workspace"/*/; do
            # Check if the glob actually found anything (handles empty dir case)
            [[ -d "$d" ]] || continue
            
            # Strip the trailing slash and add to array
            DIRS+=("${d%/}")
        done

        if [ ${#DIRS[@]} -eq 0 ]; then
            echo "No jobs found."
            exit 1
        fi

        for i in "${!DIRS[@]}"; do
            printf "%3d) %s\n" "$((i + 1))" "$(basename "${DIRS[$i]}")"
        done

        echo "------------------------------------------"
        read -p "Select a job (1-${#DIRS[@]} or Cancel): " SELECTION

        # 1. Validate the array index first
        if [[ "$SELECTION" == "c" ]]; then 
            TASK=""
            clear

        elif [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le "${#DIRS[@]}" ]; then
            
            # 2. Grab the full path from the array
            SELECTED_JOB="${DIRS[$((SELECTION - 1))]}"
            echo -e "\033[0;32mYou selected: $SELECTED_JOB\033[0m"
            
            # 3. Check the path directly (No redundant prefixing!)
            if [[ -d "$SELECTED_JOB" ]]; then
                # Store just the folder name (e.g., 'error') in JOB_NAME
                JOB_NAME=$(basename "$SELECTED_JOB")
                PACKAGE_VERSION="default"
                WSP="$USER_LOCAL_DIR/workspace/$JOB_NAME/$PACKAGE_VERSION"
                STATS_FILE="$WSP/bee-stats.json"
                
                # Clear these as per your logic
                SELECTED_JOB=""
                TASK=""
                clear
            else
                echo -e "\033[0;31mInvalid job directory.\033[0m"
            fi
        else
            echo -e "\033[0;31mInvalid selection.\033[0m"
        fi
    fi
}

select_bee() {
    # Target the precise shell executor matching your script name
    active_pids=$(pgrep -f "/bin/bash .*bee.sh")
    
    # Fallback: Look for the exact word 'bee.sh' or 'bee', ignoring wrapper structures
    if [ -z "$active_pids" ]; then
        # -d ' ' joins the output PIDs cleanly into a space-separated string
        # Using word boundaries ensures pid 1234 running "beer-app" isn't targeted
        active_pids=$(pgrep -d ' ' -f "\<bee\.sh\>|\<bee\>")
    fi
    
    # Security & Automation Clean-Up
    # Strip out the PID of the currently running script ($$) and its parent shell ($PPID) 
    # so the utility never targets its own selection window interface
    if [ -n "$active_pids" ]; then
        CLEAN_PIDS=""
        for pid in $active_pids; do
            if [[ "$pid" != "$$" ]] && [[ "$pid" != "$PPID" ]]; then
                # Filter out system service tasks (like PID 1 - systemd/init)
                if (( pid > 10 )); then
                    CLEAN_PIDS="$CLEAN_PIDS $pid"
                fi
            fi
        done
        active_pids=$(echo "$CLEAN_PIDS" | xargs)
    fi

    # Security & Automation Clean-Up + Dynamic Tree Filtering
    if [ -n "$active_pids" ]; then
        CLEAN_PIDS=""
        for pid in $active_pids; do
            # 1. Skip current execution ($$) and parent menu shell ($PPID)
            if [[ "$pid" == "$$" ]] || [[ "$pid" == "$PPID" ]]; then
                continue
            fi

            # 2. Skip low-level system services
            if (( pid <= 10 )); then
                continue
            fi

            # 3. Get the Command Name and Parent PID (PPID) in one go
            proc_info=$(ps -p "$pid" -o ppid=,comm= 2>/dev/null)
            if [ -z "$proc_info" ]; then
                continue
            fi

            parent_pid=$(echo "$proc_info" | awk '{print $1}')
            proc_comm=$(echo "$proc_info" | awk '{print $2}')

            # 4. Filter out search tools
            if [[ "$proc_comm" == *"pgrep"* ]] || [[ "$proc_comm" == *"grep"* ]]; then
                continue
            fi

            # 5. Filter out the outer 'script' wrapper itself
            if [[ "$proc_comm" == "script" ]]; then
                continue
            fi

            # 6. TREE VERIFICATION: If the parent of this PID is also called "script",
            # then THIS PID is definitively our inner worker job!
            parent_comm=$(ps -p "$parent_pid" -o comm= 2>/dev/null | xargs)
            if [[ "$parent_comm" == "script" ]]; then
                # Found the target process running inside the wrapper session
                CLEAN_PIDS="$CLEAN_PIDS $pid"
                continue
            fi

            # Fallback: If it's a standalone run (no script wrapper parent), 
            # keep it anyway so manual runs still show up in the menu.
            if [ -z "$parent_comm" ] || [[ "$parent_comm" != "script" ]]; then
                CLEAN_PIDS="$CLEAN_PIDS $pid"
            fi
        done
        active_pids=$(echo "$CLEAN_PIDS" | xargs)
    fi

    if [ -z "$active_pids" ]; then
        echo "No active bee.sh worker processes found."
        return 0
    fi


    options=()
    for pid in $active_pids; do
        # 1. Grab the raw TTY name for this specific PID (e.g., "pts/1" or "?")
        raw_tty=$(ps -p "$pid" -o tty= | xargs)

        # 2. Reconstruct the session file path using your naming convention
        session_data=""
        if [ -n "$raw_tty" ] && [ "$raw_tty" != "?" ]; then
            # Convert /dev/pts/1 into _dev_pts_1
            formatted_tty=$(echo "/dev/$raw_tty" | sed 's/\//_/g')
            session_file="$HOME/.bee_session${formatted_tty}"
            
            # If the file exists and isn't empty, read its contents
            if [ -s "$session_file" ]; then
                # Grabs the content (e.g., a status or description string inside the file)
                session_data=" | Info: $(cat "$session_file" | head -n 1)"
            fi
        fi

        # 3. Grab the job name from the session file if it exists
        # (Assuming your session file contains "system-info:default")
        session_job_name=""
        if [ -s "$session_file" ]; then
            session_raw=$(cat "$session_file" | head -n 1)
            # Extract just the part before the colon (e.g., "system-info")
            session_job_name="${session_raw%%:*}"
        fi

        # 4. Try looking up the Job Name using the inner worker PID file
        job_file=$(grep -lw "$pid" $USER_LOCAL_DIR/*/*/PID 2>/dev/null | head -n 1)

        # 3. Try looking up using its Parent PID (wrapper) if worker failed
        if [ -z "$job_file" ]; then
            parent_pid=$(ps -p "$pid" -o ppid= 2>/dev/null | xargs)
            if [ -n "$parent_pid" ]; then
                job_file=$(grep -lw "$parent_pid" $USER_LOCAL_DIR/*/*/PID 2>/dev/null | head -n 1)
            fi
        fi

        # 5. Determine final menu display name
        if [ -n "$job_file" ]; then
            # Found in system tracking directories
            found_job=$(basename "$(dirname "$job_file")")
            options+=("$found_job [PID: $pid]$session_data")
        elif [ -n "$session_job_name" ]; then
            # Fallback 1: Found inside the session file data!
            options+=("$session_job_name [PID: $pid]$session_data")
        else
            # Fallback 2: Absolute last resort
            options+=("Direct_Run [PID: $pid]$session_data")
        fi
    done

    echo "Select an active Bee:"
    echo "--------------------------------"

    select choice in "${options[@]}" "Cancel"; do
        if [[ "$choice" == "Cancel" ]]; then
            TAB_NAME=$LAST_TAB
            TASK=""
            break
        elif [[ -n "$choice" ]]; then
            sel_job="${choice%% *}"
            sel_pid=$(echo "$choice" | grep -oP 'PID: \K[0-9]+')
            echo "Selected Job: $sel_job"
            echo "Selected PID: $sel_pid"
TARGET_PID=$sel_pid
JOB_NAME=$sel_job
PACKAGE_VERSION="default"
WSP="$USER_LOCAL_DIR/workspace/$JOB_NAME/$PACKAGE_VERSION"
STATS_FILE="$WSP/bee-stats.json"
TAB_NAME="PROCESS"
            break
        fi
    done
}

SELECTED_LOG=""
show_logs() {
    if [[ $SELECTED_LOG == "" ]]; then
        mapfile -t FILES < <(find "$WSP" -maxdepth 1 -type f ! -name "*.*" | sort)

        if [ ${#FILES[@]} -eq 0 ]; then
            echo "No job logs found."
            exit 1
        fi

        # Loop and display
        for i in "${!FILES[@]}"; do
            FILE_PATH="${FILES[$i]}"
            FILENAME=$(basename "$FILE_PATH")
            
            # Get human-readable file size (e.g., 1.2M, 4G)
            SIZE=$(du -sh "$FILE_PATH" | cut -f1)
            
            printf "%3d) \033[0;37m[%-6s]\033[0m %s\n" "$((i + 1))" "$SIZE" "$FILENAME"
        done

        echo "------------------------------------------"
        read -p "Select log by number (1-${#FILES[@]} or Cancel): " SELECTION

        # Selection Logic
        if [[ "$SELECTION" == "c" ]]; then 
            TASK=""
            clear
            
        elif [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le "${#FILES[@]}" ]; then
            SELECTED_FILE="${FILES[$((SELECTION - 1))]}"
            
            echo -e "\033[0;32mOpening log: $SELECTED_FILE\033[0m"
            SELECTED_LOG=$SELECTED_FILE
            clear
            TASK="SHOWLOG"
            TAB_NAME=$TASK
            LOGACTION=""
        else
            echo -e "\033[0;31mInvalid selection.\033[0m"
        fi
        
    else
        # Extract the filename to decide how to view it
        local fname=$(basename "$SELECTED_LOG")

        case "$fname" in
            "FOCUS")
                if [[ "$LOGACTION" == "" ]]; then LOGACTION="head"; fi
                echo -e "\033[1;34m--- $SELECTED_LOG $LOGACTION 25 Lines ---\033[0m"
                local c_row=0
                while read -r cmd; do
                    [[ -z "$cmd" ]] && continue
                    padding=$(( max_coloms - ${#cmd} ))
                    tput cup $((3 + c_row)) 0
                    #printf "%s%${padding}s" "$cmd" " "
                    printf "\e[K%s" "$cmd\n"
                    ((c_row++))
                    [[ $c_row -ge $((max_lines)) ]] && break
                done < <($LOGACTION -n $((max_lines)) "$SELECTED_LOG")
                ;;
            "COMMANDLOG"|"BEELOG"|"HISTORY"|"LASTPROMPT")
                if [[ "$LOGACTION" == "" ]]; then LOGACTION="tail"; fi
                echo -e "\033[1;32m--- $SELECTED_LOG $LOGACTION 25 Lines ---\033[0m"
                local c_row=0
                while read -r cmd; do
                    [[ -z "$cmd" ]] && continue
                    padding=$(( max_coloms - ${#cmd} ))
                    tput cup $((3 + c_row)) 0
                    #printf "%s%${padding}s" "$cmd" " "
                    printf "\e[K%s" "$cmd"
                    ((c_row++))
                    [[ $c_row -ge $((max_lines)) ]] && break
                done < <($LOGACTION -n $((max_lines)) "$SELECTED_LOG")
                ;;
            "PLAN")
                if [[ "$LOGACTION" == "" ]]; then LOGACTION="head"; fi
                echo -e "\033[1;35m--- Full Plan $LOGACTION ---\033[0m"
                $LOGACTION -n 25 "$SELECTED_LOG"
                ;;
            "hive.conf")
                if [ ! -f "hive.sh" ]; then
                    banner_hivepro
                else
                    echo "Hive+Swarm configuration:"
                    tail -n 28 $USER_CONFIG_DIR/hive.conf
                    SELECTED_RULE=$USER_CONFIG_DIR/hive.conf
                fi
                ;;
            "BEE_PROFILE"|"BEE_PLANNING"|"BEE_RULES")
                if [[ "$RULETYPE" == "job" ]]; then
                    echo -e "Job $fname:   \n"
                    tail -n 28 $WSP/config/$fname
                    SELECTED_RULE="$WSP/config/$fname"
                else
                    echo -e "Global $fname:\n"
                    tail -n 28 config/$fname
                    SELECTED_RULE="$USER_CONFIG_DIR/$fname"
                    SELECTED_LOG="$USER_CONFIG_DIR/$fname"
                fi
                ;;
             "RUN_FORBIDDEN"|"RUN_ALWAYS"|"RUN_NEVER"|"RUN_REPLACE")
                if [[ "$RULETYPE" == "job" ]]; then
                    echo -e "Job $fname:   \n"
                    tail -n 28 "$WSP/config/$fname"
                    SELECTED_RULE="$WSP/config/$fname"
                else
                    echo -e "Global $fname:\n"
                    tail -n 28 "$USER_CONFIG_DIR/$fname"
                    SELECTED_RULE="$USER_CONFIG_DIR/$fname"
                    SELECTED_LOG="$USER_CONFIG_DIR/$fname"
                fi
                ;;
            "dataset.csv")
                if [[ "$RULETYPE" == "job" ]]; then
                    echo -e "Job SciKit dataset.csv:\n"
                    tail -n 28 "$WSP/cache/dataset.csv"
                    SELECTED_RULE="$WSP/cache/dataset.csv"
                else
                    echo -e "Global SciKit dataset.csv:\n"
                    tail -n 28 "$USER_CONFIG_DIR/default-dataset.csv"
                    SELECTED_RULE="$USER_CONFIG_DIR/default-dataset.csv"
                    SELECTED_LOG="$USER_CONFIG_DIR/default-dataset.csv"
                fi
                ;;         
            *)
                # Default view for any other file
                if [[ "$LOGACTION" == "" ]]; then LOGACTION="tail"; fi
                echo -e "\033[1;37m--- $SELECTED_LOG ($LOGACTION Last 20) ---\033[0m"
                $LOGACTION -n 25 "$SELECTED_LOG"
                ;;
        esac
    fi
}

run_tasks() {
    if [[ $TASK == "SELECTLOG" ]]; then
        SELECTED_LOG=""
        show_logs

    elif [[ $TASK == "SHOWLOG" ]]; then
        show_logs

    elif [[ $TASK == "CHANGEJOB" ]]; then
        SELECTEDJOB=""
        show_jobs

    elif [[ $TASK == "TYPEJOB" ]]; then
        tput cup $((LINES - 1)) 1; 
        tput el
        echo -n "Enter Job name > "
        read -r INPUT_JOB_NAME
        if [[ ! -d "$USER_LOCAL_DIR/workspace/$INPUT_JOB_NAME/default" ]]; then
            echo " Job directory not found. Start job first, then switch monitor."
            sleep 3
        else
            JOB_NAME="$INPUT_JOB_NAME"
            PACKAGE_VERSION="default"
            WSP="$USER_LOCAL_DIR/workspace/$JOB_NAME/$PACKAGE_VERSION"
            STATS_FILE="$WSP/bee-stats.json"
        fi
        TASK=""
        TAB_NAME="PROGRESS"
        clear
    
    elif [[ $TASK == "LAUNCHBEE" ]]; then
        tput cup $((LINES - 1)) 1; tput el
        TASK=""
        echo -n "Launch Bee with > "
        read -r INPUT_LAUNCH_PARAMS
        
        # Parse the input into an array to respect quotes
        eval "parts=($INPUT_LAUNCH_PARAMS)"
        found_prompt=false
        
        for word in "${parts[@]}"; do
            if [[ ! $word == -* ]]; then
                if [ "$found_prompt" = false ]; then
                    # This is the "Prompt" - skip it
                    found_prompt=true
                elif [ "$word" != "" ]; then
                    # This is the "JOB_NAME" - grab it and stop
                    JOB_NAME=${word,,}
                    $PACKAGE_VERSION="default"
                    break
                fi
            fi
        done
            
        WSP="$USER_LOCAL_DIR/workspace/$JOB_NAME/$PACKAGE_VERSION"
        STATS_FILE="$WSP/bee-stats.json"

        # Escape everything for the nested shell call
        SAFE_PARAMS=$(printf "%q " "${parts[@]}")
        # Launch Screen
        #screen -dmS "bee_$JOB_NAME" bash -c "echo \$\$ > /tmp/bee_$JOB_NAME.pid; exec ./bee.sh $SAFE_PARAMS"
        # Force the sub-shell to move into the current dir first
        screen -dmS "bee_$JOB_NAME" bash -c "cd $(pwd); echo \$\$ > /tmp/bee_$JOB_NAME.pid; exec ./bee.sh $SAFE_PARAMS"
        # Get PID
        sleep 0.1
        if [[ -f "/tmp/bee_$JOB_NAME.pid" ]]; then
            TARGET_PID=$(cat "/tmp/bee_$JOB_NAME.pid")
            rm -f "/tmp/bee_$JOB_NAME.pid"
        fi
        TAB_NAME="PROCESS"
        TASK=""; 
        clear
    fi
}

# Display the swarm clusters to select
# cursorX (0-4)
# cursorY (0-N)
HOVER_CLUSTER="ALL CLUSTERS"
SELECTED_CLUSTER=$HOVER_CLUSTER
display_swarm() {
    local config_file="$USER_CONFIG_DIR/hive.conf"
    local clusters=("ALL CLUSTERS")
    local column_width=20
    local count=0
    local cols=5

    # Append the rest from the config
    local raw_clusters=$(sed 's/\r//g' "$config_file" | awk '!/^#/ && NF >= 6 {print $6}' | sort -u)
    for c in $raw_clusters; do
        [[ -n "$c" && "$c" != "CLUSTER" ]] && clusters+=("$c")
    done

    # Reset coordinates
    if [[ "$CURSOR_RESET" == "true" ]]; then
        cursorX=0
        cursorY=0
        CURSOR_RESET="false"
        for i in "${!clusters[@]}"; do
            if [[ "$SELECTED_CLUSTER" == "${clusters[$i]}" ]]; then
                cursorX=$(( i % $cols ))
                cursorY=$(( i / $cols ))
                break
            fi
        done
    fi

    # Calculate the 1D index
    local target_index=$(( (cursorY * $cols) + cursorX ))
    target_index=$(( target_index == ${#clusters[@]} ? ${#clusters[@]}-1 : target_index ))
    target_index=$(( target_index < 0 ? 0 : target_index))

    echo -e "--- 🛰️  HIVE CLUSTER SELECTOR (Use Arrows, Press 4 to Confirm) --- Current = $SELECTED_CLUSTER ---\n"

    for i in "${!clusters[@]}"; do
        local cluster="${clusters[i]}"
        local display_name="${cluster:0:18}"
        local padded_name
        if [[ $i -eq $target_index ]]; then
            printf -v padded_name " > %-17s " "$display_name"
            printf "${BOLD_CYAN}${INVERT}%s${NC} " "$padded_name"
            HOVER_CLUSTER="$cluster"
        else
            printf -v padded_name " %-18s " "$display_name"
            printf "${INVERT}%s${NC} " "$padded_name"
        fi
        ((count++))
        if (( count % $cols == 0 )); then
            echo -e "\n"
        fi
    done
    echo ""
}


# Select a Bee from a cluster
HOVER_BEE=""
SELECTED_BEE=$HOVER_BEE
display_cluster() {
    if [[ ! -f $HIVE_DIR/hive_master.sorted ]]; then
        echo "Waiting for the Hive to process..."
        return
    fi
    local STATE_DATA=$(cat $HIVE_DIR/hive_master.sorted)

    local column_width=38
    local count=0
    local cols=2
    local bees=()
    local search_pattern="." # Default: match everything (ALL CLUSTERS)

    if [[ "$SELECTED_CLUSTER" == "ALL CLUSTERS" ]]; then
        title="All Bee's"
    else
        search_pattern="$SELECTED_CLUSTER"
        title="Bee's in swarm '$SELECTED_CLUSTER'"
    fi

    # Reset coordinates
    if [[ "$CURSOR_RESET" == "true" ]]; then
        cursorX=0
        cursorY=0
        CURSOR_RESET="false"
        # Detect coordinates of selected cluster and set once   
        for i in "${!bees[@]}"; do
            if [[ "$SELECTED_BEE" == "${bees[$i]}" ]]; then
                cursorX=$(( i % $cols ))
                cursorY=$(( i / $cols ))
                break
            fi
        done
    fi

    # Build array
    while IFS='#' read -r cluster identity pid job health age; do
        identity=$(echo "$identity" | xargs) # Trim and Clean
        job=$(echo "$job" | xargs)
        health_clean=$(echo "$health" | sed 's/\x1b\[[0-9;]*[mK]//g' | xargs)
        [[ -z "$identity" || "$identity" == "IDENTITY" ]] && continue  # Skip empty identity
        local bee="${identity}:${job}:${health_clean}"
        bees+=("$bee")
    done < <(echo "$STATE_DATA" | grep "$search_pattern" | grep -v "\---" | tail -n +1)

    # Debug: Check if array is actually full now
    # echo "Found ${#bees[@]} bees."

    # Calculate the 1D index
    local target_index=$(( (cursorY * $cols) + cursorX ))
    target_index=$(( target_index == ${#bees[@]} ? ${#bees[@]}-1 : target_index ))
    target_index=$(( target_index < 0 ? 0 : target_index))
 
    # Display grid
    echo "$title (total ${#bees[@]})"
    echo
    for i in "${!bees[@]}"; do
        local bee="${bees[i]}"
        local display_name="${bee:0:(( column_width - 2))}"
        local padded_name
        if [[ $i -eq $target_index ]]; then
            printf -v padded_name " > %-38s " "$display_name"
            printf "${BG_WHITE}%s${NC} " "$padded_name"
            HOVER_BEE="$bee"
        else
            B_STATE="${bee##*:}"
            case "$B_STATE" in
                "STARTING")  H_COL="${BG_GREEN}" ;;
                "RUNNING") H_COL="${BG_GREEN}" ;;
                "ACTIVE") H_COL="${BG_GREEN}" ;;
                "THINKING") H_COL="${BG_CYAN}" ;;
                "WAITING") H_COL="${BG_GOLD}" ;;
                "STUCK") H_COL="${BG_RED}" ;;
                "DONE") H_COL="${NC}" ;;
                *) H_COL="${BG_RED}" ;;
            esac

            printf -v padded_name " %-40s " "$display_name"
            printf "${H_COL}%s${NC} " "$padded_name"
        fi
        ((count++))
        if (( count % $cols == 0 )); then
            echo -e "\n"
        fi
    done

    echo ""
}

help() {
    statusbar
    tput cup 3 0 
    echo -e "${WHITE} 0 - System monitor"
    echo " 1 - Progress monitor"
    echo " 2 - Process monitor"
    echo " 3 - Hive Monitor"   
    echo " 4 - Swarm Monitor+Select"
    echo " 5 - List local Bees"
    echo " 6 - BEE LOG"
    echo " 7 - COMMAND LOG"
    echo " 8 - REASONING"
    echo " 9 - HISTORY"
    echo ""

    echo " J - Select local Job to review"
    echo " T - Type local Job to review"
    echo " B - Select local running Bee"
    echo " X - End the selected Bee job"
    echo " L - Launch a Bee script --parameter \"prompt\" JOB_NAME "
    echo ""
    echo " Reserved for user response: Yes/Once/Skip/Always/Never/End/Zap (y/o/s/a/n/e/z)"
    echo ""
    echo " Format PROMPT: Quoted string any length."
    echo " Format JOB names: one string, alfanumeric and dash(-) characters"
    echo ""

    echo " Cursor - Select an entry"
    echo " M - Monitor selected Bee"


    # Second colom
    tput cup 3 30; echo " SHIFT+0 - bee.conf"
    tput cup 4 30; echo " SHIFT+1 - Default Input"
    tput cup 5 30; echo " SHIFT+2 - Bee Profile"
    tput cup 6 30; echo " SHIFT+3 - Bee Planning"
    tput cup 7 30; echo " SHIFT+4 - Bee Rules"
    tput cup 8 30; echo " SHIFT+5 - Run Forbidden"
    tput cup 9 30; echo " SHIFT+6 - Run Always"
    tput cup 10 30; echo " SHIFT+7 - Run Never"
    tput cup 11 30; echo " SHIFT+8 - Run Replace"
    tput cup 12 30; echo " SHIFT+9 - Dataset"
    
    # Right colom
    tput cup 3 60; echo " ? - This help window"
    tput cup 4 60; echo " Q - Quit monitor"
 
    tput cup 6 60; echo " V - Select a log to view"
    tput cup 7 60; echo " D - Switch to show head/tail"
    tput cup 8 60; echo " C - Change/Edit selected file"
    tput cup 9 60; echo " G - Switch to Default or JOB dataset"
    tput cup 10 60; echo " G - Switch to GLOBAL or JOB Run rules"
    tput cup 11 60; echo " H - Hive.conf"

    echo -e "${NC}"

    # K for kill

    # hive - watch -n 1 cat /dev/shm/honeybeebash/hive_master.state
    # Logs are covered, replace most by ;
    # Configuration page
    # System info page
    # Hatchery , see all Bee's on this rig (even of other users ?)
}

banner_hivepro() {
    echo -e "${YELLOW}----------------------------------------------------------"
    echo -e "$ICON_BEE HONEYBEE FREE TIER: Bee + Monitor"
    echo -e "$ICON_HAND Get 'Hive Pro' to enable Hive and Swarm management"
    echo -e "$ICON_LINK https://honeybeebash.com/index.php?p=hive"
    echo -e "----------------------------------------------------------${NC}"
}

# Main loop
LOOPCOUNT=0
cursorY=0
cursorX=0
CURSOR_RESET="false"
TAB_NAME="PROGRESS"
LOGACTION=""
RULETYPE="job"
TASK="" 
key=""

while true; do
    # Dynamicly 
    if [[ -z "$TARGET_PID" ]] || [[ "$TARGET_PID" == "0" ]]; then
        if [[ -f "/tmp/bee_$JOB_NAME.pid" ]]; then
            TARGET_PID=$(cat "/tmp/bee_$JOB_NAME.pid")
            rm -f "/tmp/bee_$JOB_NAME.pid"
        fi
    fi

    if [[ -f $WSP/PID ]]; then
        TARGET_PID=$(cat $WSP/PID)
    else
        TARGET_PID="0"
    fi
    SELECTED_RULE=""
    DO_CLEAR="false"

    if [[ "$LAST_TAB" != "$TAB_NAME" ]]; then
        clear
    fi

    # --- [ TAB NAVIGATION ] ---
    if [[ $TASK != "" ]]; then 
        if [[ $TASK == "SELECTLOG" ]] || [[ $TASK == "CHANGEJOB" ]] || [[ $DO_CLEAR == "true" ]]; then
            clear
        fi
        systembar
        run_tasks
        statusbar

    elif [[ $TAB_NAME == "SYSTEM" ]]; then
        systembar
        systemmonitor
        statusbar

    elif [[ $TAB_NAME == "PROGRESS" ]]; then
        systembar
        progress_monitor
        statusbar
    
    elif [[ $TAB_NAME == "PROCESS" ]]; then
        systembar
        process_monitor
        statusbar

    elif [[ $TAB_NAME == "SELECTBEE" ]]; then
        systembar
        tput cup 3 0;
        select_bee
        statusbar

    elif [[ $TAB_NAME == "HIVE" ]]; then
        systembar
        tput cup 3 0;
        if [ ! -f "hive.sh" ]; then
            banner_hivepro
        elif [[ ! -f "$MASTER_STATE" ]]; then
            echo "Waiting for Hive to start up..."
        else
            export GREP_COLORS='ms=30;42'
            #tail -n 28 "$MASTER_STATE" | grep --color=always -E "$TARGET_PID|^"
            if [[ "$SELECTED_CLUSTER" == "ALL CLUSTERS" ]]; then
                # Show everything, highlight the target PID
                tail -n 28 "$MASTER_STATE" | grep --color=always -E "$TARGET_PID|^"
            else
                # ONLY show lines containing the cluster name
                # THEN highlight the PID within those lines
                tail -n 28 "$MASTER_STATE" | \
                    grep "$SELECTED_CLUSTER" | \
                    grep --color=always -E "$TARGET_PID|^"
            fi
        fi
        statusbar

    elif [[ $TAB_NAME == "SWARM" ]]; then
        systembar
        tput cup 3 0;
        if [ ! -f "hive.sh" ]; then
            banner_hivepro
        elif [[ -z "$MASTER_STATE" ]]; then
            echo "ERROR: Hive configuration seems missing."
        elif [[ ! -f $MASTER_STATE ]]; then
            echo "ERROR: QueenBee is not running."
        else
            display_swarm
        fi
        statusbar

    elif [[ $TAB_NAME == "BEE" ]]; then
        systembar
        tput cup 3 0;
        display_cluster
        statusbar


    elif [[ $TAB_NAME == "LOCALBEE" ]]; then
        systembar
        tput cup 3 0;
        ps -aux | grep bee.sh
        statusbar

    elif [[ $TAB_NAME == "HELP" ]]; then
        systembar
        help
        statusbar
    fi

    if [[ "$LAST_TAB" != "$TAB_NAME" ]] && [[ "$TAB_NAME" != "SELECTBEE" ]]; then
        LAST_TAB=$TAB_NAME
    fi

    # Controls
    # -t 0.1 : Only wait 0.1 seconds before continuing
    # -n 1   : Stop waiting as soon as ONE key is pressed
    #read -t 0.1 -n 1 key
    read -t 0.1 -rsn1 key

    # Check for the Escape character (start of an arrow key)
    if [[ $key == $'\e' ]]; then
        # Read the next two characters ([ and A/B/C/D)
        read -rsn2 -t 0.01 rest
        key+="$rest"
    fi


    key="${key,,}"
    case "$key" in
        # --- QUIT MONITOR --- 
        [qQ])
            tput cnorm # Restore the cursor before exiting 
            clear
            echo "Exiting Honey Bee Monitor."
            exit 0 ;;

        # --- REMOTE ANSWSER (Remote answering Bee Execution request) --- 
        [yYoOsSnNaAeEzZ])
            # If Bee has a Execute request
            if [[ -f $WSP/PENDINGREQUEST ]]; then 
                if [[ "$key" == "z" ]]; then
                    rm -f "$WSP/PENDINGREQUEST"
                    rm -f "$WSP/PENDINGUSERRESPONSE" 

                elif [[ "$key" == "e" ]]; then
                    key="q"
                    echo "$key" > "$WSP/PENDINGUSERRESPONSE"

                else
                    echo "$key" > "$WSP/PENDINGUSERRESPONSE"
                fi
            fi
            ;;

        # --- SENT REMOTE Quit --- 
        [xX])
            if [[ ! -f "$WSP/MONITORCOMMAND" ]]; then 
                echo "HALT" > "$WSP/MONITORCOMMAND"
            fi
            ;;

        # --- TAB NAVIGATION (0-9) ---
        0) LOGACTION=""; TASK=""; TAB_NAME="SYSTEM" ;;
        1) LOGACTION=""; TASK=""; TAB_NAME="PROGRESS" ;;
        2) LOGACTION=""; TASK=""; TAB_NAME="PROCESS" ;;
        3) LOGACTION=""; TASK=""; TAB_NAME="HIVE" ;;
        4) 
            CURSOR_CHANGED="true"
            if [[ "$TAB_NAME" == "SWARM" ]]; then
                CURSOR_RESET="true"
                SELECTED_CLUSTER=$HOVER_CLUSTER
                LOGACTION=""; TAB_NAME="BEE"
            else
                CURSOR_RESET="true"
                LOGACTION=""; TAB_NAME="SWARM"
            fi
            ;;
        5) LOGACTION=""; TASK=""; TAB_NAME="LOCALBEE" ;;
        6) LOGACTION=""; SELECTED_LOG="$WSP/BEELOG"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;
        7) LOGACTION=""; SELECTED_LOG="$WSP/COMMANDLOG"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;
        8) LOGACTION=""; SELECTED_LOG="$WSP/REASONING"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;
        9) LOGACTION=""; SELECTED_LOG="$WSP/HISTORY"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;

        ")") LOGACTION=""; SELECTED_LOG="$USER_CONFIG_DIR/bee.conf"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true"  ;;
        "!") LOGACTION=""; SELECTED_LOG="$WSP/config/DEFAULT_INPUT"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;
        "@") LOGACTION=""; SELECTED_LOG="$WSP/config/BEE_PROFILE"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;
        "#") LOGACTION=""; SELECTED_LOG="$WSP/config/BEE_PLANNING"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;
        '$') LOGACTION=""; SELECTED_LOG="$WSP/config/BEE_RULES"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;
        "%") LOGACTION=""; SELECTED_LOG="$WSP/config/RUN_FORBIDDEN"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;
        "^") LOGACTION=""; SELECTED_LOG="$WSP/config/RUN_ALWAYS"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;
        "&") LOGACTION=""; SELECTED_LOG="$WSP/config/RUN_NEVER"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;
        "*") LOGACTION=""; SELECTED_LOG="$WSP/config/RUN_REPLACE"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;
        "(") LOGACTION=""; SELECTED_LOG="$WSP/cache/dataset.csv"; TASK="SHOWLOG"; TAB_NAME=""; DO_CLEAR="true" ;;

        # --- SYSTEM ACTIONS & TOOLS ---
        "?"|"/") 
            LOGACTION=""; TASK=""; TAB_NAME="HELP" 
            ;;
        [vV]) 
            LOGACTION=""; TASK="SELECTLOG" 
            ;;
        [cC]) 
            edit_file 
            ;;

        # --- SWITCHES  ---
        # --- Switches to Head or Tail of a logfile --
        [dD]) 
            if [[ "$LOGACTION" == "head" ]]; then
                LOGACTION="tail"
            else
                LOGACTION="head"
            fi
            ;;
        # --- (Switches to Global or Job rules) --- 
        [gG]) 
            if [[ "$RULETYPE" == "job" ]]; then
                RULETYPE="global"
            else
                RULETYPE="job"
            fi
            clear
            ;;

        # --- HIVE CONTROL (Launch and selection of Bee's) ---  

        # Hive config
        [hH]) LOGACTION=""; SELECTED_LOG="$USER_CONFIG_DIR/config/hive.conf"; TASK="SHOWLOG"; TAB_NAME="" ;;

        # Monitor selected Bee
        [mM]) 
            if [[ -n "$HOVER_BEE" ]]; then
                SELECTED_BEE=$HOVER_BEE
                # Switch to Bee shell
                B_ADDR="${SELECTED_BEE%:*}"
                B_JOB="${SELECTED_BEE#*:}"

                # SELECTED_BEE="192.168.1.66:default:ACTIVE"
                IFS=':' read -r B_ADDR B_JOB B_STATUS <<< "$SELECTED_BEE"
                USER_NAME=$(awk -v ip="$B_ADDR" '$1 == ip {print $2}' config/hive.conf)
                if [[ -n "$USER_NAME" ]]; then
                    # Note the @ symbol and the quoted command
                    #ssh -t "${USER_NAME}@${B_ADDR}" "cd $BASE_DIR && sudo ./bee.sh 2>&1 && sudo ./monitor.sh \"\" \"$B_JOB\""
                    clear
                    print_banner $B_ADDR
                    #ssh -t "${USER_NAME}@${B_ADDR}" "cd $BASE_DIR && sudo ./monitor.sh \"$B_JOB\""
                    ssh -t "${USER_NAME}@${B_ADDR}" "cd $BASE_DIR && ./monitor.sh \"$B_JOB\" \"$(hostname)\""
                    # Returning
                    print_banner $(hostname)
                    sleep 3
                else
                    echo "Error: No user found for IP $B_ADDR in $USER_CONFIG_DIR/config/hive.conf"
                    sleep 3
                fi
                clear
            fi
            ;;

        [jJ]) 
            LOGACTION=""; TASK="CHANGEJOB" 
            ;;
        [tT]) 
            LOGACTION=""; TASK="TYPEJOB" 
            ;;
        [lL]) 
            LOGACTION=""; TASK="LAUNCHBEE" 
            ;;
        [bB]) 
            LOGACTION=""; TASK=""; LAST_TAB=$TAB_NAME; TAB_NAME="SELECTBEE" 
            ;;

        # --- CURSOR CONTROL (Up/Down=Select  Left/Right=NEXTTAB or Select) ---
        $'\e[A') # UP Arrow
            (( cursorY-- ))
            cursorY=$(( cursorY < 0 ? 0 : cursorY ))
            ;;
        $'\e[B') # DOWN Arrow
            # Action for Down
            (( cursorY++ ))
            ;;
        $'\e[C') # RIGHT Arrow
            (( cursorX++ ))
            # Switch TAB?
            ;;
        $'\e[D') # LEFT Arrow
            (( cursorX-- ))
            cursorX=$(( cursorX < 0 ? 0 : cursorX ))
            # Switch TAB?
            ;;
    esac

    sleep $MONITOR_INTERVAL
    
    ((LOOPCOUNT++))

    if (( LOOPCOUNT > 10 )); then
        clear
        LOOPCOUNT=0 
    fi
done

