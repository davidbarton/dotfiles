#!/bin/bash

# Import useful stuff from clone script.
source "$(dirname "$(readlink -f "$0")")/clone.sh"

# Main function for setting remotes.
function main {
  track_remote "origin" "git@github.com:davidbarton/dotfiles.git"
  track_remote "backup" "git@github.com:davidbarton/dotfiles-backup.git"
  track_remote "work" "git@github.com:davidbarton/dotfiles-work.git"
  track_remote "template" "git@github.com:davidbarton/dotfiles-template.git"
}

# Run main function if script is executed and not sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
