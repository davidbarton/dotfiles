#!/bin/bash

# Import useful stuff from clone script.
source "$(dirname "$(readlink -f "$0")")/clone.sh"

# Error on unset variables.
set -u

# Main function for applying stashed changes.
function main() {
  checkout_with_backup "$1"
}

# Run main function if script is executed and not sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$1"
fi
