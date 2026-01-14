#!/bin/bash
# run-tests.sh - Convenience script to run busted tests

# Try to find busted in common locations
BUSTED_CMD=""

if command -v busted &> /dev/null; then
    BUSTED_CMD="busted"
elif [ -f "/opt/homebrew/bin/busted" ]; then
    BUSTED_CMD="/opt/homebrew/bin/busted"
elif [ -f "/usr/local/bin/busted" ]; then
    BUSTED_CMD="/usr/local/bin/busted"
elif [ -f "$HOME/.luarocks/bin/busted" ]; then
    BUSTED_CMD="$HOME/.luarocks/bin/busted"
else
    echo "Error: busted not found!"
    echo ""
    echo "Install busted using:"
    echo "  luarocks install busted"
    echo ""
    echo "Or add it to your PATH if already installed."
    exit 1
fi

echo "Using busted: $BUSTED_CMD"
echo ""

# Run tests
if [ $# -eq 0 ]; then
    # No arguments - run all tests
    $BUSTED_CMD spec/
else
    # Pass arguments to busted
    $BUSTED_CMD "$@"
fi
