#!/bin/bash

NATIVE_DIR=~/ezhomesteading/native
BACKEND_DIR=~/ezhomesteading/backend
WEB_DIR=~/ezhomesteading/web

INCLUDE_WEB=false

for arg in "$@"; do
  if [[ "$arg" == "--web" ]]; then
    INCLUDE_WEB=true
  fi
done

osascript <<EOF
tell application "iTerm"
  activate
  set myWindow to (create window with default profile)

  -- Tab 1: Backend nvim
  tell current session of myWindow
    write text "cd $BACKEND_DIR && nvim ."
  end tell

  -- Tab 2: Native nvim
  tell myWindow
    set tab2 to (create tab with default profile)
    tell current session of tab2
      write text "cd $NATIVE_DIR && nvim ."
    end tell
  end tell

  -- Tab 3: Native run
  tell myWindow
    set tab3 to (create tab with default profile)
    tell current session of tab3
      write text "cd $NATIVE_DIR && bunx expo start"
    end tell
  end tell

  -- Tab 4: Backend run
  tell myWindow
    set tab4 to (create tab with default profile)
    tell current session of tab4
      write text "cd $BACKEND_DIR && go run main.go"
    end tell
  end tell
EOF

if [ "$INCLUDE_WEB" = true ]; then
osascript <<EOF
tell application "iTerm"
  tell front window
    -- Tab 5: Web nvim
    set tab5 to (create tab with default profile)
    tell current session of tab5
      write text "cd $WEB_DIR && nvim ."
    end tell

    -- Tab 6: Web run
    set tab6 to (create tab with default profile)
    tell current session of tab6
      write text "cd $WEB_DIR && bun run dev"
    end tell
  end tell
end tell
EOF
fi
