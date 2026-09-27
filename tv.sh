#!/bin/bash
# tv — adb shortcuts for the TCL Google TV
# usage: tv [command] [args]   (no command opens a menu)
# override the address with: TV_IP=192.168.1.50 tv connect

TV_IP="${TV_IP:-192.168.1.128}"
TV_PORT="${TV_PORT:-5555}"
TV="$TV_IP:$TV_PORT"
LOG="$HOME/Projects/scripts/tv-removed.log"

tv_adb() { adb -s "$TV" "$@"; }

need_pkg() {
  if [ -z "$1" ]; then
    echo "usage: tv $CMD <package.name>   (find names with: tv packages <filter>)"
    exit 1
  fi
}

usage() {
  cat <<EOF
tv — adb shortcuts for the TV at $TV

  connect              connect to the TV (accept the prompt on the TV)
  disconnect           disconnect from the TV
  reconnect            disconnect, restart adb, connect again
  status               show adb devices and whether the TV is authorized

  packages [filter]    list installed packages, optionally filtered (e.g. tv packages tcl)
  apps                 list apps you installed (third-party only)
  disabled             list disabled packages
  removed              list packages removed for user 0 (restorable)

  remove <pkg>         uninstall for user 0 (keeps it on the system; logged to tv-removed.log)
  restore <pkg>        bring back a removed package
  disable <pkg>        freeze a package without removing it
  enable <pkg>         unfreeze a package
  launcher             show which app is the current home launcher

  home | back          press the Home / Back button
  settings             open the TV's Settings
  screenshot           save a screenshot to ~/Desktop
  mirror               mirror and control the TV screen (needs scrcpy)
  install <file.apk>   sideload an APK
  shell                open a shell on the TV
  reboot               restart the TV
EOF
}

CMD="$1"
shift

if [ -z "$CMD" ]; then
  CMDS="connect disconnect reconnect status packages apps disabled removed launcher home back settings screenshot mirror shell reboot help"
  if command -v fzf >/dev/null; then
    CMD=$(printf '%s\n' $CMDS | fzf --prompt="tv> " --height=40% --reverse)
  else
    select c in $CMDS; do CMD="$c"; break; done
  fi
  [ -z "$CMD" ] && exit 0
fi

case "$CMD" in
  connect)
    adb connect "$TV"
    sleep 1
    if adb devices | grep -q "^$TV[[:space:]]*unauthorized"; then
      echo "Accept the 'Allow USB debugging?' prompt on the TV, then run: tv status"
    fi
    ;;
  disconnect)
    adb disconnect "$TV"
    ;;
  reconnect)
    adb disconnect "$TV" >/dev/null 2>&1
    adb kill-server
    adb connect "$TV"
    ;;
  status)
    adb devices -l
    STATE=$(adb devices | awk -v d="$TV" '$1==d {print $2}')
    case "$STATE" in
      device)       echo "TV is connected and authorized." ;;
      unauthorized) echo "TV is waiting for you to accept the debugging prompt." ;;
      offline)      echo "TV is offline. Try: tv reconnect" ;;
      *)            echo "TV is not connected. Try: tv connect" ;;
    esac
    ;;
  packages)
    if [ -n "$1" ]; then
      tv_adb shell pm list packages | sed 's/^package://' | grep -i "$1" | sort
    else
      tv_adb shell pm list packages | sed 's/^package://' | sort
    fi
    ;;
  apps)
    tv_adb shell pm list packages -3 | sed 's/^package://' | sort
    ;;
  disabled)
    tv_adb shell pm list packages -d | sed 's/^package://' | sort
    ;;
  removed)
    # packages present on the system but not installed for user 0
    comm -23 \
      <(tv_adb shell pm list packages -u | sed 's/^package://' | tr -d '\r' | sort) \
      <(tv_adb shell pm list packages | sed 's/^package://' | tr -d '\r' | sort)
    ;;
  remove)
    need_pkg "$1"
    if tv_adb shell pm uninstall -k --user 0 "$1"; then
      echo "$(date '+%F %T') removed $1" >> "$LOG"
      echo "Undo with: tv restore $1"
    fi
    ;;
  restore)
    need_pkg "$1"
    tv_adb shell cmd package install-existing "$1" \
      && echo "$(date '+%F %T') restored $1" >> "$LOG"
    ;;
  disable)
    need_pkg "$1"
    tv_adb shell pm disable-user --user 0 "$1" \
      && echo "$(date '+%F %T') disabled $1" >> "$LOG"
    ;;
  enable)
    need_pkg "$1"
    tv_adb shell pm enable "$1" \
      && echo "$(date '+%F %T') enabled $1" >> "$LOG"
    ;;
  launcher)
    tv_adb shell cmd package resolve-activity --brief \
      -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1
    ;;
  home)
    tv_adb shell input keyevent KEYCODE_HOME
    ;;
  back)
    tv_adb shell input keyevent KEYCODE_BACK
    ;;
  settings)
    tv_adb shell am start -a android.settings.SETTINGS >/dev/null
    ;;
  screenshot)
    OUT="$HOME/Desktop/tv-$(date +%Y%m%d-%H%M%S).png"
    tv_adb exec-out screencap -p > "$OUT" && echo "Saved $OUT"
    ;;
  mirror)
    if ! command -v scrcpy >/dev/null; then
      echo "scrcpy isn't installed. Run: brew install scrcpy"
      exit 1
    fi
    scrcpy -s "$TV"
    ;;
  install)
    [ -f "$1" ] || { echo "usage: tv install <file.apk>"; exit 1; }
    tv_adb install "$1"
    ;;
  shell)
    tv_adb shell
    ;;
  reboot)
    tv_adb reboot
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $CMD"
    echo
    usage
    exit 1
    ;;
esac
