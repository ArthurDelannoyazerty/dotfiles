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
# Add Cargo/Rust to path if it exists
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

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