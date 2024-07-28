#!/bin/bash

# Import useful stuff from clone script.
source "$(dirname "$(readlink -f "$0")")/clone.sh"

# Error on unset variables.
set -u

# Backup all changes to tracked files to backup remote.
function backup_changes() {
  # Checkout git branch for backups.
  my_dotfiles checkout "$2" || dotfiles checkout -b "$2"

  # Stage and commit all changes to tracked files.
  my_dotfiles commit --all --message="Backup"

  # Push backup commit to backup remote.
  my_dotfiles push "$1" "$2"
}

# Main function for backup.
function main() {
  backup_changes "${DOTFILES_BACKUP_REMOTE}" "${DOTFILES_BACKUP_BRANCH}"
}

# Set backup remote name (if not set).
DOTFILES_BACKUP_REMOTE="${DOTFILES_BACKUP_REMOTE:-"backup"}"

# Set branch name for backups (if not set).
DOTFILES_BACKUP_BRANCH="${DOTFILES_BACKUP_BRANCH:-"backup"}"

# Run main function if script is executed and not sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
