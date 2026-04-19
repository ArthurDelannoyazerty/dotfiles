# ==============================================================================
#  UNIVERSAL BASHRC
#  Optimized for NixOS, Dev Containers, and Standard Linux
# ==============================================================================

# 1. Exit early if not running interactively
# ------------------------------------------------------------------------------
[[ $- != *i* ]] && return

# 2. Path Setup (Crucial for User-installed binaries)
# ------------------------------------------------------------------------------
# Ensure .local/bin is in PATH for starship and other tools
if [ -d "$HOME/.local/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
fi

# Add .atuin/bin (default install location for atuin)
if [ -d "$HOME/.atuin/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.atuin/bin:"*) ;;
        *) export PATH="$HOME/.atuin/bin:$PATH" ;;
    esac
fi

# 3. History & Shell Options
# ------------------------------------------------------------------------------
# Append to the history file, don't overwrite it
shopt -s histappend

# Save multi-line commands as one command
shopt -s cmdhist

# Huge history size
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups

# Update window size after each command (good for containers)
shopt -s checkwinsize

# 4. Universal Aliases (Only if command exists)
# ------------------------------------------------------------------------------
# Helper to check if a command exists
exists() { command -v "$1" >/dev/null 2>&1; }

# Color support for ls and grep
if ls --color -d . >/dev/null 2>&1; then
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

# Standard aliases
alias ll='ls -alFhv --group-directories-first'
alias l='ls -CF'
alias la='ls -A'

# Tool overrides (safety checks)
exists btop   && alias btop='btop --force-utf'
exists nvitop && alias nvitop='nvitop --colorful --interval 1'
exists bat    && alias cat='bat --style=plain --paging=never' # Use bat as cat if available
exists eza    && alias ls='eza --icons' # Use eza instead of ls if available
exists eza    && alias ll='eza -al --icons --group-directories-first'

# Safety
# alias cp='cp -i'
# alias mv='mv -i'
# alias rm='rm -i'

# 5. Python & Environment
# ------------------------------------------------------------------------------
# Auto-activate Python Virtual Environments (.venv)
if [ -z "$VIRTUAL_ENV" ] && [ -f ".venv/bin/activate" ]; then
    source ".venv/bin/activate"
fi

# Load .env file automatically if present
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs) 2>/dev/null
fi

# 6. Functions
# ------------------------------------------------------------------------------
# Ports function (Robust version)
ports() {
    if ! exists ss || ! exists awk; then
        echo "Error: 'ss' or 'awk' is missing. Cannot list ports."
        return 1
    fi

    local port_data
    # Determine column width dynamically or fallback
    local width=75
    local separator=$(printf "%${width}s" "" | tr ' ' '-')

    # Header
    printf "%-8s %-8s %-20s %-${width}s %s\n" "PORT" "PID" "PROCESS" "EXECUTABLE" "CWD"
    printf "%-8s %-8s %-20s %s %s\n" "----" "---" "-------" "$separator" "---"

    ss -lntp | awk -v width="$width" '
        NR > 1 && match($0, /users:\(\("([^"]+)",pid=([0-9]+)/, m) {
            pid = m[2]; name = m[1];
            split($4, a, ":"); port = a[length(a)];
            
            # Read symlinks (safely ignoring errors)
            cmd_exe = "readlink -f /proc/" pid "/exe 2>/dev/null";
            if ((cmd_exe | getline exe) <= 0) exe = "N/A";
            close(cmd_exe);

            cmd_cwd = "readlink -f /proc/" pid "/cwd 2>/dev/null";
            if ((cmd_cwd | getline cwd) <= 0) cwd = "N/A";
            close(cmd_cwd);

            # Truncate path if too long
            if (length(exe) > width) exe = substr(exe, 1, width-3) "...";

            printf "%-8s %-8s %-20s %-"width"s %s\n", port, pid, name, exe, cwd;
        }
    ' | sort -n
}

# 7. Prompt Configuration (Starship > Default)
# ------------------------------------------------------------------------------
# Check if starship is installed; if not, try to install it locally
if ! exists starship; then
    if exists curl; then
        # Ensure target dir exists
        mkdir -p "$HOME/.local/bin"
        
        # Install without sudo
        # echo "Starship not found. Installing to ~/.local/bin..."
        curl -sS https://starship.rs/install.sh | sh -s -- -b "$HOME/.local/bin" >/dev/null 2>&1
        
        # Refresh hash map so shell finds the new command immediately
        hash -r
    fi
fi

if exists starship; then
    eval "$(starship init bash)"
else
    # Fallback if installation failed (no curl, no internet, etc.)
    export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
fi

# 8. Command Not Found Hook (Optional)
# ------------------------------------------------------------------------------
if [ -f /usr/share/doc/pkgfile/command-not-found.bash ]; then
    source /usr/share/doc/pkgfile/command-not-found.bash
fi

# 9. Atuin History (Smart Loading)
# ------------------------------------------------------------------------------
if exists atuin; then
    # 1. Download bash-preexec if missing
    if [ ! -f "$HOME/.bash-preexec.sh" ]; then
        if exists curl; then
            curl -fsSL https://raw.githubusercontent.com/rcaloras/bash-preexec/master/bash-preexec.sh -o "$HOME/.bash-preexec.sh"
        fi
    fi

    # 2. Source it and Init Atuin
    if [ -f "$HOME/.bash-preexec.sh" ]; then
        source "$HOME/.bash-preexec.sh"
        eval "$(atuin init bash)"
    fi
fi


# ---------------------------------------------------------------------------- #
#                                 HELP FUNCTION                                #
# ---------------------------------------------------------------------------- #

h() {
    local target_domain=$1
    
    # ---------------------------------------------------------
    # DATA DEFINITION
    # Format:  domain:command:Short description of the command
    # ---------------------------------------------------------
    local raw_data="
system:lshw:List detailed hardware configuration
system:hwinfo:Detailed hardware information
system:dmidecode:Read SMBIOS/DMI hardware info
system:ps:Snapshot of current running processes (procps)
system:grep:Search text for patterns (gnugrep)
system:find:Search for files in a directory hierarchy
system:tar:Store or extract files from an archive
system:unzip:Extract zip archives
system:zip:Create zip archives
network:dig:DNS lookup and debugging
network:tcpdump:Network packet analyzer
network:nmap:Network scanner and port checker
network:ethtool:Network interface controller configuration
network:cloudflared:Cloudflare tunnel daemon
network:curl:Transfer data from or to a server
network:wget:Network file downloader
network:netstat:Print network connections and routing tables
storage:iotop:I/O usage monitor (like top for disk)
storage:smartctl:Check HDD/SSD health (smartmontools)
storage:parted:Disk partitioning tool
storage:duf:Modern, user-friendly disk usage utility
monitoring:htop:Interactive process viewer
monitoring:btop:Modern, visually appealing resource monitor
monitoring:nvitop:Interactive NVIDIA GPU monitor
monitoring:lsof:List open files and the processes using them
monitoring:sensors:Check CPU temperatures and fan speeds
monitoring:killall:Kill processes by their name
docker:lazydocker:Terminal UI to manage Docker containers
docker:ctop:Top-like interface for container metrics
hyprland:waybar:Highly customizable Wayland status bar
hyprland:rofi:Application launcher and window switcher
hyprland:kitty:Fast, feature-rich GPU-based terminal
hyprland:hyprlock:Screen locker for Hyprland
hyprland:wl-copy:Copy content to the Wayland clipboard
hyprland:wl-paste:Paste content from the Wayland clipboard
hyprland:grim:Take screenshots (entire screen or region)
hyprland:slurp:Select a specific region for screenshots
hyprland:dunst:Lightweight notification daemon
audio:pavucontrol:GUI volume mixer for PulseAudio/PipeWire
audio:pactl:PulseAudio CLI tools to manage sound
tools:git:Distributed version control system
tools:vim:Highly configurable text editor
tools:bat:A cat clone with syntax highlighting
tools:eza:A modern replacement for the ls command
tools:fzf:Command-line fuzzy finder
tools:tree:Display directories as trees
fonts:fc-list:List all available fonts on the system
fonts:fc-match:Match and display the closest font
shortcuts:Super + Enter:Open Kitty terminal
shortcuts:Super + D:Open Rofi app launcher
shortcuts:Super + Shift + S:Take a screenshot with grim/slurp
"

    # Remove empty lines
    local clean_data=$(echo "$raw_data" | grep -v '^\s*$')
    
    # Extract domains, preserving their first-seen order
    local domains=$(echo "$clean_data" | awk -F':' '{if (!seen[$1]++) print $1}')

    # Helper function to print the table for a specific domain
    print_domain() {
        local d=$1
        echo -e "\n\033[1;34m=== $d ===\033[0m"
        # Changed 'echo' to 'printf' so formatting logic works properly
        printf "\033[1m %s | %-18s | %s\033[0m\n" "OK" "Command" "Description"
        echo "----+--------------------+--------------------------------------------------"
        
        # Awk filters the domain, while the bash loop performs the live `command -v` check
        echo "$clean_data" | awk -F':' -v dom="$d" 'tolower($1) == tolower(dom)' | while IFS=":" read -r dom cmd desc; do
            local icon="❌"
            if [ "$dom" = "shortcuts" ]; then
                icon="⚡" # Neutral icon for shortcuts since they are not binaries
            elif command -v "$cmd" >/dev/null 2>&1; then
                icon="✅"
            fi
            
            # Print the formatted row with the emoji status
            printf " %s | \033[36m%-18s\033[0m | %s\n" "$icon" "$cmd" "$desc"
        done
    }

    if [ -z "$target_domain" ]; then
        # NO ARGUMENT: Print everything
        for d in $domains; do
            print_domain "$d"
        done
        
        # Print list of available domains at the end
        echo -e "\n\033[1;33m>>> Available Domains:\033[0m"
        echo "$domains" | paste -sd, - | sed 's/,/, /g'
        
    else
        # DOMAIN PROVIDED: Check if it exists (case-insensitive)
        local matched_domain=$(echo "$domains" | grep -i "^$target_domain$")
        
        if [ -z "$matched_domain" ]; then
            echo -e "\n\033[31mError: Domain '$target_domain' not found.\033[0m"
            echo -e "\n\033[1;33m>>> Available Domains:\033[0m"
            echo "$domains" | paste -sd, - | sed 's/,/, /g'
        else
            # Print just the requested domain
            print_domain "$matched_domain"
        fi
    fi

    # ALWAYS display the tldr hint at the very bottom
    echo -e "\n\033[1;32m💡 Hint:\033[0m Use \033[1;37mtldr <command>\033"
}