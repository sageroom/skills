#!/usr/bin/env bash
# Runs inside the pane. Counts down and exits (closing the pane),
# unless the user presses any key to keep it open.
SECONDS_LEFT=5
echo ""
while [ $SECONDS_LEFT -gt 0 ]; do
  printf "\r  closing pane in %ds... press any key to keep open" "$SECONDS_LEFT"
  if read -r -s -n 1 -t 1 2>/dev/null; then
    printf "\r%-60s\r" ""
    echo "  pane kept open — type 'exit' to close"
    exit 1
  fi
  (( SECONDS_LEFT-- ))
done
printf "\r%-60s\r" ""
exit 0
