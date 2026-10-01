#!/bin/bash
# chrome-silent: start Chrome without the "started debugging this browser" bar
# usage: chrome-silent <install|uninstall|status>
# install adds a `chrome` alias to ~/.zshrc and a Dock app at ~/Applications/Chrome Silent.app.
# Both start Chrome with --silent-debugger-extension-api. Safe to run more than once.

FLAG="--silent-debugger-extension-api"
ZSHRC="$HOME/.zshrc"
BACKUP="$ZSHRC.chrome-silent.bak"
APP="$HOME/Applications/Chrome Silent.app"
ALIAS_LINE="alias chrome='open -a \"Google Chrome\" --args $FLAG'"
CHROME_MAIN="Google Chrome.app/Contents/MacOS/Google Chrome"

usage() {
  cat <<EOF
chrome-silent: start Chrome with $FLAG (hides the debugging bar)

  install     add the \`chrome\` alias to ~/.zshrc and build the Dock app
  uninstall   remove the alias and the Dock app
  status      show what is installed and whether Chrome runs with the flag

Chrome reads the flag only at startup. If Chrome is already open, quit it with Cmd+Q first.
Undo with: chrome-silent uninstall
EOF
}

has_alias() { [ -f "$ZSHRC" ] && grep -qxF "$ALIAS_LINE" "$ZSHRC"; }

# The command line of the main Chrome process (not its helpers), or nothing.
chrome_cmd() {
  local pid
  pid=$(pgrep -f "$CHROME_MAIN" | head -1)
  if [ -n "$pid" ]; then ps -o command= -p "$pid"; fi
}

chrome_status() {
  local cmd
  cmd=$(chrome_cmd)
  if [ -z "$cmd" ]; then
    echo "chrome: not running"
  elif [[ "$cmd" == *"$FLAG"* ]]; then
    echo "chrome: running with the flag"
  else
    echo "chrome: running WITHOUT the flag (quit with Cmd+Q, then start it with \`chrome\` or the app)"
  fi
}

CMD="${1:-}"

case "$CMD" in
  install)
    if has_alias; then
      echo "alias:  already in $ZSHRC"
    else
      # Start on a new line if the file does not end with one.
      if [ -s "$ZSHRC" ] && [ -n "$(tail -c1 "$ZSHRC")" ]; then echo >> "$ZSHRC"; fi
      echo "$ALIAS_LINE" >> "$ZSHRC" || exit 1
      echo "alias:  added to $ZSHRC (open a new terminal tab to use it)"
    fi
    mkdir -p "$(dirname "$APP")" || exit 1
    rm -rf "$APP"
    # osacompile always prints a codesign note, so show its output only when it fails.
    if ! out=$(osacompile -o "$APP" -e "do shell script \"open -a \\\"Google Chrome\\\" --args $FLAG\"" 2>&1); then
      echo "$out" >&2
      exit 1
    fi
    echo "app:    built $APP (drag it to the Dock)"
    chrome_status
    ;;
  uninstall)
    if has_alias; then
      cp "$ZSHRC" "$BACKUP" || exit 1
      grep -vxF "$ALIAS_LINE" "$BACKUP" > "$ZSHRC"
      echo "alias:  removed from $ZSHRC (backup at $BACKUP; open shells keep it until you close them)"
    else
      echo "alias:  not installed"
    fi
    if [ -d "$APP" ]; then
      rm -rf "$APP"
      echo "app:    removed (also drag its icon off the Dock)"
    else
      echo "app:    not installed"
    fi
    chrome_status
    ;;
  status)
    if has_alias; then echo "alias:  installed in $ZSHRC"; else echo "alias:  not installed"; fi
    if [ -d "$APP" ]; then echo "app:    installed at $APP"; else echo "app:    not installed"; fi
    chrome_status
    ;;
  ""|help|-h|--help)
    usage
    ;;
  *)
    echo "chrome-silent: unknown command: $CMD" >&2
    usage >&2
    exit 1
    ;;
esac
