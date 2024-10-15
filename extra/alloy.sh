#!/usr/bin/env bash

# Update Env Vars with new paths
export PATH="$HOME/bin:$PATH"

# Execute the final run logic.
if [ -n "$DISABLE_ALLOY_AGENT" ]; then
  echo "The Alloy Agent has been disabled. Unset the DISABLE_ALLOY_AGENT or set missing environment variables."
elif [ ! -f "$HOME/config.alloy" ]; then
  echo "No config.alloy file found. Skipping running the Alloy agent."
elif ! command -v alloy &> /dev/null; then
  echo "The Alloy Agent binary is not available. Skipping running the Alloy agent."
else
  bash -c "alloy run $HOME/config.alloy 2>&1 &"
fi
