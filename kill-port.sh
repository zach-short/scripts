#!/bin/bash
PORT=$1
PID=$(lsof -ti :$PORT)

if [ -z "$PID" ]; then
  echo "No process found on port $PORT"
else
  echo "Killing PID $PID on port $PORT"
  kill -9 $PID
fi
