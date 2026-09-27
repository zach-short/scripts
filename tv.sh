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
  usage [all]          apps by screen time and background time (all: include unused)

  home | back | search press the Home / Back / Search button
  settings             open the TV's Settings
  screenshot           save a screenshot to ~/Desktop
  mirror               mirror and control the TV screen (needs scrcpy)
  install <file.apk>   sideload an APK
  wallpaper [image]    copy an image to the TV for Projectivy (no image: list ones already there)
  shell                open a shell on the TV
  reboot               restart the TV
EOF
}

CMD="$1"
shift

if [ -z "$CMD" ]; then
  CMDS="connect disconnect reconnect status packages apps disabled removed usage launcher home back search settings screenshot mirror wallpaper shell reboot help"
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
  usage)
    # yearly usagestats: screen time (totalTimeUsed) and foreground-service time (totalTimeFS),
    # the second catches background work like casting that never shows on screen
    tv_adb shell dumpsys usagestats | tr -d '\r' | awk -v all="$1" '
      function secs(t,  n, a) { n = split(t, a, ":"); return n == 3 ? a[1]*3600 + a[2]*60 + a[3] : a[1]*60 + a[2] }
      function val(k,  m) { return match($0, k "=\"[^\"]*\"") ? substr($0, RSTART + length(k) + 2, RLENGTH - length(k) - 3) : "" }
      /In-memory yearly stats/ { y = 1; next }
      y && /timeRange=/ { range = val("timeRange"); next }
      y && /In-memory|^$/ { y = 0 }
      y && /package=/ {
        match($0, /package=[^ ]+/); pkg = substr($0, RSTART + 8, RLENGTH - 8)
        used = val("totalTimeUsed"); fs = val("totalTimeFS")
        last = val("lastTimeUsed"); comp = val("lastTimeComponentUsed")
        if (last ~ /^1969/) last = "-"; if (comp ~ /^1969/) comp = "-"
        if (all == "all" || secs(used) > 0 || secs(fs) > 0)
          printf "%d\t%-10s %-10s %-19s %-19s %s\n", secs(used), used, fs, last, comp, pkg
      }
      END { print "since " range > "/dev/stderr" }' \
    | sort -t$'\t' -k1,1nr | cut -f2- \
    | { printf "%-10s %-10s %-19s %-19s %s\n" SCREEN BACKGROUND LAST_ON_SCREEN LAST_ACTIVE PACKAGE; cat; }
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
  search)
    tv_adb shell input keyevent KEYCODE_SEARCH
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
  wallpaper)
    WALL_DIR="/sdcard/Pictures/Wallpapers"
    if [ -z "$1" ]; then
      echo "Images on the TV in $WALL_DIR:"
      tv_adb shell ls -1 "$WALL_DIR" 2>/dev/null || echo "  (none yet — run: tv wallpaper <image>)"
      exit 0
    fi
    [ -f "$1" ] || { echo "No such file: $1"; exit 1; }
    # warn when the image is smaller than 1080p; it will look soft on a 4K panel
    W=$(sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth/ {print $2}')
    H=$(sips -g pixelHeight "$1" 2>/dev/null | awk '/pixelHeight/ {print $2}')
    if [ -n "$W" ] && { [ "$W" -lt 1920 ] || [ "$H" -lt 1080 ]; }; then
      echo "Note: image is ${W}x${H}; 1920x1080 or 3840x2160 looks best."
    fi
    NAME=$(basename "$1")
    tv_adb shell mkdir -p "$WALL_DIR"
    tv_adb push "$1" "$WALL_DIR/$NAME" || exit 1
    # ask the media scanner to index it so file pickers can see it
    tv_adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
      -d "file://$WALL_DIR/$NAME" >/dev/null 2>&1
    echo "In Projectivy: gear icon (Projectivy settings) → Appearance → Wallpaper → Launcher wallpaper → Media file (Premium) → Pictures/Wallpapers/$NAME"
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
