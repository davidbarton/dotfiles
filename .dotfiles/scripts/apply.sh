#!/bin/bash

# Import useful stuff from clone script.
source "$(dirname "$(readlink -f "$0")")/clone.sh"

# Apply stash with given name.
function apply_stash {
  my_dotfiles stash apply "$(get_stash_selector "$1")"
}

# Main function for applying stashed changes.
function main {
  apply_stash "$1"
}

# Run main function if script is executed and not sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$1"
fi
