#!/bin/zsh

# Log errors
LOG_FILE="$HOME/nvim_opener_direct.log"
echo "=== Direct NvimOpener $(date) ===" >> "$LOG_FILE"
echo "Args: $@" >> "$LOG_FILE"

# Run direct command
/usr/bin/open -a "iTerm.app" /opt/homebrew/bin/nvim "$@" 2>> "$LOG_FILE"
