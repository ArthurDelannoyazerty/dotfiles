# ==============================================================================
#  UNIVERSAL BASHRC
#  Optimized for NixOS, Dev Containers, and Standard Linux
# ==============================================================================

# 1. Exit early if not running interactively
# ------------------------------------------------------------------------------
[[ $- != *i* ]] && return

# 2. History & Shell Options
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

# 3. Universal Aliases (Only if command exists)
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
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# 4. Python & Environment
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

# 5. Functions
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

# 6. Prompt Configuration (Priority: Starship > Pureline > Default)
# ------------------------------------------------------------------------------
if exists starship; then
    # -- OPTION A: STARSHIP (Recommended) --
    eval "$(starship init bash)"
else
    # -- OPTION B: PURELINE (Fallback) --
    # Only run this block if Starship is missing
    if [ ! -d "$HOME/pureline" ]; then
        git clone https://github.com/chris-marsh/pureline.git "$HOME/pureline" -q 2>/dev/null
    fi

    if [ -f "$HOME/pureline/pureline" ]; then
        # Default to a simple config if yours is missing
        CONFIG="$HOME/pureline/configs/powerline_full_256col.conf"
        [ -f "$HOME/.pureline.personal.conf" ] && CONFIG="$HOME/.pureline.personal.conf"
        
        source "$HOME/pureline/pureline" "$CONFIG"
    else
        # -- OPTION C: BASIC FALLBACK --
        export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
    fi
fi

# 7. Command Not Found Hook (Optional)
# ------------------------------------------------------------------------------
if [ -f /usr/share/doc/pkgfile/command-not-found.bash ]; then
    source /usr/share/doc/pkgfile/command-not-found.bash
fi

# 8. Atuin History (Smart Loading)
# ------------------------------------------------------------------------------
if exists atuin; then
    # Disable Up-Arrow sync if you prefer traditional history for up-arrow
    # bind -x '"\e[A": __atuin_history --shell-up-key-binding'
    # bind -x '"\eOA": __atuin_history --shell-up-key-binding'

    # 1. Check the Environment Variable from Nix (Most reliable)
    if [ -n "$BASH_PREEXEC_PATH" ] && [ -f "$BASH_PREEXEC_PATH" ]; then
        source "$BASH_PREEXEC_PATH"
    
    # 2. Check standard locations (Fallback)
    elif [ -f "/usr/share/bash-preexec/bash-preexec.sh" ]; then
        source "/usr/share/bash-preexec/bash-preexec.sh"
    elif [ -f "$HOME/.nix-profile/share/bash-preexec/bash-preexec.sh" ]; then
        source "$HOME/.nix-profile/share/bash-preexec/bash-preexec.sh"
    fi

    # Initialize Atuin only if preexec is loaded
    if type preexec >/dev/null 2>&1; then
        eval "$(atuin init bash)"
    else
        echo "Warning: bash-preexec not found. Atuin disabled."
    fi
fi