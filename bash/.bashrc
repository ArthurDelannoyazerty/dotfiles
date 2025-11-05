# Available functions 
# - refresh_bashrc      : download the .bashrc from github gist
# - set_ps1_default     : Use a default PS1 (style ubuntu)
# - set_ps1_job         : Use the pureline file "$HOME/.pureline.job.conf"
# - set_ps1_personal    : Use the pureline file "$HOME/.pureline.personal.conf"


# Exit if non interactive shell
case $- in
  *i*) ;;  # continue in interactive shell
  *) return ;;  # exit for non-interactive shells
esac

# Custom alias  ------------------------------------------------------------------------------------------------

alias lps="lps -dF"
alias ls="ls --color"
alias ll="ls -alFhv --group-directories-first"
alias df="df -h"
alias tree='tree -CF --charset=utf-8'
alias btop='btop --force-utf'
alias grep='grep --color=auto'
alias sudo='sudo '
alias nvitop="nvitop --colorful --interval 1"

umask 0002

# ------------------------------------------------------------------------------------------------
function refresh_bashrc {
  curl -fsSL \
       -H "Cache-Control: no-cache, no-store" \
       -H "Pragma: no-cache" \
       -H "Expires: 0" \
       https://gist.githubusercontent.com/ArthurDelannoyazerty/a7ed4eee2781aa05e1f8911e487c8e80/raw/.bashrc \
    > "$HOME/.bashrc" && source "$HOME/.bashrc"
}


# UV  ------------------------------------------------------------------------------------------------
. "$HOME/.cargo/env" 2> /dev/null

if [ -z "$VIRTUAL_ENV" ] && [ -f .venv/bin/activate ]; then
  source .venv/bin/activate >/dev/null 2>&1
fi


# PROJECT  -------------------------------------------------------------------------------------------
# export env variable
if [ -f .env ]; then
  set -a && source .env && set +a
fi




ports() {
  # --- Argument Parsing ---
  local raw_mode=0
  if [[ "$1" == "-r" || "$1" == "--raw" ]]; then
    raw_mode=1
  elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: ports [-r | --raw | -h]"
    echo "  Default: Display a formatted, truncated table of listening ports."
    echo "  -r, --raw: Display raw, tab-separated output for scripting."
    echo "  -h, --help:  Display this help message."
    return 0
  elif [[ -n "$1" ]]; then
    echo "Error: Unknown argument '$1'. Use -h for help." >&2
    return 1
  fi

  # --- Core Data Generation ---
  # This awk script fetches all the necessary data and prints it tab-separated.
  # The result is sorted numerically by port and stored in a variable.
  local port_data
  port_data=$(ss -lntp | awk '
    # Process lines that contain process information
    NR > 1 && match($0, /users:\(\("([^"]+)",pid=([0-9]+)/, m) {
      # Extract PID and process name from regex match
      pid = m[2];
      name = m[1];

      # Extract port number from the 4th column (e.g., ":::8000" -> "8000")
      split($4, addr, ":");
      port = addr[length(addr)];

      # Get the executable path; handle errors if the process disappears
      cmd_exe = "readlink -f /proc/" pid "/exe";
      if ((cmd_exe | getline exe_path) <= 0) { exe_path = "N/A"; }
      close(cmd_exe);

      # Get the working directory; handle errors
      cmd_cwd = "readlink -f /proc/" pid "/cwd";
      if ((cmd_cwd | getline cwd_path) <= 0) { cwd_path = "N/A"; }
      close(cmd_cwd);

      # Print the result as a tab-separated line
      printf "%s\t%s\t%s\t%s\t%s\n", port, pid, name, exe_path, cwd_path;
    }
  ' | sort -n)

  # Exit gracefully if no listening processes were found
  if [[ -z "$port_data" ]]; then
    echo "No processes found listening on TCP ports."
    return 0
  fi

  # --- Display Logic ---

  # RAW MODE: Just print the header and the data.
  if [[ $raw_mode -eq 1 ]]; then
    echo -e "PORT\tPID\tPROCESS\tEXECUTABLE_PATH\tWORKING_DIRECTORY"
    echo "$port_data"
    return 0
  fi

  # TABLE MODE (Default): Format the data into a perfectly aligned table.
  (
    # Define the column width for the path to ensure alignment
    local MAX_PATH_LEN=75
    # Create the printf format string dynamically
    local TBL_FORMAT="%-8s %-10s %-20s %-${MAX_PATH_LEN}s %s\n"
    # Create a separator line of the correct length
    local SEPARATOR
    SEPARATOR=$(printf "%${MAX_PATH_LEN}s" "" | tr ' ' '-')

    # Print the table header and separator
    printf "$TBL_FORMAT" "PORT" "PID" "PROCESS" "EXECUTABLE_PATH" "WORKING_DIRECTORY"
    printf "%-8s %-10s %-20s %s %s\n" "--------" "----------" "--------------------" "$SEPARATOR" "-----------------"

    # Read the data line by line and format it
    echo "$port_data" | while IFS=$'\t' read -r port pid name exe_path cwd_path; do
      local display_path
      # Truncate the executable path if it's too long
      if [ ${#exe_path} -gt $MAX_PATH_LEN ]; then
        display_path="${exe_path:0:$((MAX_PATH_LEN-3))}..."
      else
        display_path="$exe_path"
      fi
      # Print the formatted row
      printf "$TBL_FORMAT" "$port" "$pid" "$name" "$display_path" "$cwd_path"
    done
  )
}


# Terminal appearance  ------------------------------------------------------------------------------------------------

function set_ps1_default {
  echo "default" > "$HOME/.ps1"
  bash
}

function set_ps1_personal {
  echo "personal" > "$HOME/.ps1"
  bash
}

function set_ps1_job {
  echo "job" > "$HOME/.ps1"
  bash
}



# function set_custom_ps1 {
#   # USING STRANGE FONTS
#   # For the logo you need to install the NerdFont : 
#   # For remote VSCode, install the font locally :
#   # 1. Download one of these https://www.nerdfonts.com/font-downloads (I used the Jetbrains Mono nerd Font)
#   # 2. Extract and install the "Regular" one.
#   # 3. Open Settings : "Preferences: Open User Settings (JSON)"
#   # 4. Modify/Add :     "terminal.integrated.fontFamily": "JetBrainsMono Nerd Font"


#   # Set OS_ICON based on detected Linux distro (used by $PS1)
#   if [ -f /etc/os-release ]; then
#     . /etc/os-release
#     case "$ID" in
#       arch)       OS_ICON="" ;;      # Arch Linux
#       artix)      OS_ICON="" ;;      # Artix Linux
#       manjaro)    OS_ICON="" ;;      # Manjaro
#       ubuntu)     OS_ICON="" ;;      # Ubuntu
#       debian)     OS_ICON="" ;;      # Debian
#       kali)       OS_ICON="" ;;      # Kali
#       mint)       OS_ICON="" ;;      # Linux Mint
#       pop)        OS_ICON="" ;;      # Pop!_OS
#       elementary) OS_ICON="" ;;      # Elementary OS
#       zorin)      OS_ICON="" ;;      # Zorin OS
#       fedora)     OS_ICON="" ;;      # Fedora
#       rhel)       OS_ICON="" ;;      # Red Hat Enterprise Linux
#       centos)     OS_ICON="" ;;      # CentOS
#       rocky)      OS_ICON="" ;;      # Rocky Linux
#       opensuse*|suse) OS_ICON="" ;;  # openSUSE
#       void)       OS_ICON="" ;;      # Void Linux
#       gentoo)     OS_ICON="" ;;      # Gentoo
#       nixos)      OS_ICON="" ;;      # NixOS
#       garuda)     OS_ICON="" ;;      # Garuda Linux
#       linuxlite)  OS_ICON="" ;;      # Linux Lite
#       clear-linux-os) OS_ICON="" ;;  # Intel Clear Linux
#       *)          OS_ICON="🐧" ;;      # Default Tux Penguin
#     esac
#   else
#     OS_ICON="💻"
#   fi

#   # Custom bash appearance (powerline like)
#   # ────── Color Variables ──────
#   RESET="\[\033[0m\]"

#   FG_BLACK="\[\033[0;30m\]"
#   FG_WHITE="\[\033[1;37m\]"
#   FG_GRAY="\[\033[0;37m\]"

#   BG_RED="\[\033[41m\]"
#   BG_BLUE="\[\033[44m\]"
#   BG_GREEN="\[\033[42m\]"
#   BG_PURPLE="\[\033[45m\]"

#   SEP_RED="\[\033[0;31m\]"
#   SEP_GREEN="\[\033[0;32m\]"
#   SEP_BLUE="\[\033[0;34m\]"
#   SEP_PURPLE="\[\033[0;35m\]"

#   # ────── Dynamic Segments ──────
#   # Git branch segment (detected dynamically)
#   if git rev-parse --is-inside-work-tree &>/dev/null; then
#     GIT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)
#     GIT_SEGMENT="${SEP_PURPLE}${FG_BLACK}${BG_PURPLE}  ${GIT_BRANCH} ${RESET}${SEP_PURPLE}"
#   else
#     GIT_SEGMENT=""
#   fi

#   # Virtualenv segment
#   if [ -n "$VIRTUAL_ENV_PROMPT" ]; then
#     VENV_SEGMENT="${SEP_GREEN}${FG_BLACK}${BG_GREEN} ${VIRTUAL_ENV_PROMPT} ${RESET}${SEP_GREEN}"
#   else
#     VENV_SEGMENT=""
#   fi

#   # ────── Build PS1 Prompt ──────
#   PS1='\n'
#   PS1+="${SEP_BLUE}╭─${SEP_RED}${FG_GRAY}${BG_RED} ${OS_ICON:-🐧} \u ${RESET}${SEP_RED}${BG_BLUE}"
#   PS1+="${SEP_BLUE}${BG_BLUE}${FG_WHITE} \w ${RESET}${SEP_BLUE}"
#   PS1+="${VENV_SEGMENT}"
#   PS1+="${GIT_SEGMENT}"
#   PS1+='\n'
#   PS1+="${SEP_BLUE}╰ \[\033[1;36m\]\\$ ${RESET}"

# }

# Deactivate venv PS1 modification
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Choose the PS1
function setup_pureline_configs() {
  # Init config choice file
  [ ! -f "$HOME/.ps1" ] && echo "personal" > "$HOME/.ps1"

  # Clone pureline repo
  if [ ! -d "$HOME/pureline" ]; then
    if ! git clone https://github.com/chris-marsh/pureline.git "$HOME/pureline" -q; then
      echo "Error: could not clone pureline." >&2 && return 1
    fi
  fi

  # Create job config from template
  [ ! -f "$HOME/.pureline.job.conf" ] && cp "$HOME/pureline/configs/powerline_full_256col.conf" "$HOME/.pureline.job.conf"

  # Create personal config from template
  [ ! -f "$HOME/.pureline.personal.conf" ] && cp "$HOME/pureline/configs/powerline_full_256col.conf" "$HOME/.pureline.personal.conf"
}

# Run the one-time setup
setup_pureline_configs

# Source the correct pureline config in the top-level scope
# This is critical for ensuring the PL_SEGMENTS array persists
if [ -f "$HOME/pureline/pureline" ]; then
  ps1_config_choice=$(<"$HOME/.ps1") # Use < instead of cat for efficiency

  case "$ps1_config_choice" in
    "personal")
      source "$HOME/pureline/pureline" "$HOME/.pureline.personal.conf"
      ;;
    "job")
      source "$HOME/pureline/pureline" "$HOME/.pureline.job.conf"
      ;;
    *)
      # Fallback to a simple PS1 if config is invalid
      export PS1="[\u@\h \W]\\$ "
      ;;
  esac
fi

# It's good practice to unset temporary variables
unset ps1_config_choice


# Command not found hook  ------------------------------------------------------------------------------------------------
source /usr/share/doc/pkgfile/command-not-found.bash 2> /dev/null


# atuin (last block of file !)------------------------------------------------------------------------------------------------
# With bash-preexec
source ~/.bash-preexec.sh 2> /dev/null
source /usr/share/bash-preexec/bash-preexec.sh 2> /dev/null

# With ble.sh
source -- ~/.local/share/blesh/ble.sh 2> /dev/null

source "$HOME/.atuin/bin/env" 2> /dev/null
eval "$(atuin init bash)" 2> /dev/null