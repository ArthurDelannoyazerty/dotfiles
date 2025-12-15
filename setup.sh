#!/bin/bash

# Stop on first error
set -e

DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup"

# key = path within the dotfiles repo | value = path in the home directory
declare -A SYMLINK_MAP=(
  ["bash/.bashrc"]=".bashrc"
  ["starship/starship.toml"]=".config/starship.toml"
  ["code/settings.json"]=".config/Code/Users/settings.json"
  ["code/keybindings.json"]=".config/Code/Users/keybindings.json"
  ["code/launch.json"]=".config/Code/Users/launch.json"
)

echo "🚀 Starting dotfiles setup..."

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Error: Dotfiles directory not found at $DOTFILES_DIR."
  echo "Please clone the repository first: git clone <your-repo-url> $DOTFILES_DIR"
  exit 1
fi

echo "Creating backup directory at $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

# Iterate over the map to create symlinks
for src in "${!SYMLINK_MAP[@]}"; do
  dest="${SYMLINK_MAP[$src]}"
  
  SOURCE_FILE="$DOTFILES_DIR/$src"
  DEST_FILE="$HOME/$dest"
  
  # Check if the source file actually exists
  if [ ! -f "$SOURCE_FILE" ]; then
    echo "⚠️  Warning: Source file not found, skipping: $SOURCE_FILE"
    continue
  fi
  
  # If the destination file already exists, back it up
  if [ -e "$DEST_FILE" ] || [ -L "$DEST_FILE" ]; then
    echo "Backing up existing file: $DEST_FILE"
    # Create the destination's parent directory in the backup folder if needed
    mkdir -p "$(dirname "$BACKUP_DIR/$dest")"
    mv "$DEST_FILE" "$BACKUP_DIR/$dest"
  fi
  
  # Create the parent directory for the destination if it doesn't exist
  # (e.g., for ~/.config/hypr/)
  mkdir -p "$(dirname "$DEST_FILE")"
  
  # Create the symlink
  echo "🔗 Linking $SOURCE_FILE -> $DEST_FILE"
  ln -s "$SOURCE_FILE" "$DEST_FILE"
done

echo "✅ Dotfiles setup complete!"
echo "👉 Please restart your shell or run 'source ~/.bashrc' to apply changes."