#!/bin/bash

FILE=build/top.nplog
START_LINE=35  # Removed the space
STOP_LINE=60   # Removed the space

# Check if the file exists
if [ -e "$FILE" ]; then
    # Extract and display the lines using sed
    sed -n "${START_LINE},${STOP_LINE}p" "$FILE"
else
    echo "File does not exist."
    exit 1
fi
