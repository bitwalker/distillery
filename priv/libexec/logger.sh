#!/usr/bin/env bash

set -e
if [ ! -z "$DEBUG_BOOT" ]; then
    # Disable debug mode in this file
    set +x
fi

IS_TTY=false
if [ -t 1 ]; then
    if command -v tput >/dev/null; then
        IS_TTY=true
    fi
fi

if [ "$IS_TTY" = "true" ]; then
    txtrst=$(tput sgr0 || echo "\e[0m")              # Reset
    txtbld=$(tput bold || echo "\e[1m")              # Bold
    bldred=${txtbld}$(tput setaf 1 || echo "\e[31m") # Red
    bldgrn=${txtbld}$(tput setaf 2 || echo "\e[32m") # Green
    bldylw=${txtbld}$(tput setaf 3 || echo "\e[33m") # Yellow
else
    txtrst=
    txtbld=
    bldred=
    bldgrn=
    bldylw=
fi

# Log an error message in red and exit with a non-zero status
fail() {
    printf "${bldred}%s${txtrst}\n" "${*}"
    exit 1
}

# Log an informational message in yellow
notice() {
    printf "${bldylw}%s${txtrst}\n" "${*}"
}

# Log a success message in green
success() {
    printf "${bldgrn}%s${txtrst}\n" "${*}"
}

# Log an informational message
info() {
    printf "%s\n" "${*}"
}

if [ ! -z "$DEBUG_BOOT" ]; then
    # Re-enable it after
    set -x
fi
