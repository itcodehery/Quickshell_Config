#!/bin/bash
echo "executed at $(date)" >> /tmp/radial_test.log
if pkill -f '[q]uickshell.*radial'; then
    exit 0
else
    quickshell -c ~/.config/quickshell/radial
fi

echo "PATH is $PATH" >> /tmp/radial_test.log
if ! command -v quickshell &> /dev/null; then
    echo "quickshell not found in PATH" >> /tmp/radial_test.log
fi
