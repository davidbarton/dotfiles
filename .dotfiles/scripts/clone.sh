#!/bin/bash

# Use this script to safely checkout dotfiles git
# repository. It takes care of preserving any
# existing files that would be overwritten.

# Error on unset variables.
set -u

# Return 0 (0 is considered true in bash) if variable is set and not false.
function is_set_and_not_false() {
  if [[ -n "$1" ]] && [[ "$1" != "false" ]]; then
    return 0  # Return true
  else
    return 1  # Return false
  fi
}

# Abort the script with an error message.
function abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

# Log message if DOTFILES_QUIET is not set.
function log_message() {
  if ! is_set_and_not_false "${DOTFILES_QUIET}"; then
    printf "%s\n" "$@"
  fi
}

# Log all commands if CI environment variable is set.
function log_commands() {
  if is_set_and_not_false "${CI}"; then
    set -x
  fi
}

# Execute dotfiles command with args.
function my_dotfiles() {
  git --work-tree="${DOTFILES_WORK_TREE_PATH}" --git-dir="${DOTFILES_GIT_PATH}" "$@"
}

# Command to get reflog selector for git stash with given name.
function get_stash_selector() {
  my_dotfiles stash list | grep --max-count 1 "$1" | cut -d: -f1
}

# Function to clone dotfiles repository.
function clone_repository() {
  # Inform user about clone.
  log_message "Cloning repository ${DOTFILES_GIT_CLONE_URL}"

  # Exit with error if git is not installed.
  if ! command -v git &> /dev/null; then
    abort "Error: The git command is not installed. Aborting dotfiles clone."
  fi

  # Exit with error if git clone arguments are empty.
  if [[ -z ${DOTFILES_GIT_CLONE_URL} ]]; then
    abort "Error: Repository URL not provided. Aborting dotfiles clone."
  fi

  # Exit with error if work tree directory does not exists.
  if [[ ! -d ${DOTFILES_WORK_TREE_PATH} ]]; then
    abort "Error: Work tree directory ${DOTFILES_WORK_TREE_PATH} does not exist. Aborting dotfiles clone."
  fi

  # Exit with error if project directory already exists.
  if [[ -d ${DOTFILES_PROJECT_PATH} ]]; then
    abort "Error: Dotfiles project directory ${DOTFILES_PROJECT_PATH} already exists. Aborting dotfiles clone."
  fi

  # Jump to work tree directory.
  cd "${DOTFILES_WORK_TREE_PATH}" || abort "Error: Could not change directory to ${DOTFILES_WORK_TREE_PATH}. Aborting dotfiles clone."

  # Clone repository with --bare flag.
  git clone \
    --quiet \
    --bare \
    --branch "${DOTFILES_CLONE_BRANCH}" \
    --origin "${DOTFILES_ORIGIN}" \
    "${DOTFILES_GIT_CLONE_URL}" \
    "${DOTFILES_GIT_PATH}"

  # Don't show untracked files for "dotfiles status".
  my_dotfiles config --local status.showUntrackedFiles no
}

# Function to setup tracking remote branches.
function track_remote() {
  # Inform user about remote tracking.
  log_message "Fixing branch tracking for $1 remote"

  # Remove existing remote.
  my_dotfiles remote remove "$1" > /dev/null 2>&1

  # Re-add origin remote. It now has proper branch tracking.
  my_dotfiles remote add "$1" "$2" > /dev/null 2>&1

  # Fetch all branches.
  my_dotfiles fetch --all --quiet
}

# Function to checkout git files. Tries to backup any conflicts.
function checkout_with_backup() {
  # Inform user about backup.
  log_message "Trying to checkout $* branch"

  # Try to quietly checkout files from repository. Run backup if checkout failed.
  if ! my_dotfiles checkout "$@" > /dev/null 2>&1; then
    # Inform user about backup.
    log_message "Backing up conflicting files to ${DOTFILES_BACKUP_PATH}"

    # Save list of conflict files for backup.
    local backup_files
    backup_files=$(
      my_dotfiles checkout "$@" 2>&1 \
        | grep -E "^\s+.+$" \
        | xargs -I{} printf "%s\n" {}
    )

    # Create backup directory structure.
    printf "%s\n" "${backup_files}" \
      | xargs -I{} dirname "${DOTFILES_BACKUP_PATH}"/{} \
      | xargs -I{} mkdir -p {}

    # Move existing files to backup directory.
    printf "%s\n" "${backup_files}" \
      | xargs -I{} mv "${DOTFILES_WORK_TREE_PATH}"/{} "${DOTFILES_BACKUP_PATH}"/{}

    # Inform user about backed up files.
    log_message "$(
      printf "%s\n" "${backup_files}" \
        | xargs -I{} printf "  %s\n" "${DOTFILES_BACKUP_PATH}/{}"
    )"

    # Try to checkout files from repository again. Report error if checkout failed again.
    if ! my_dotfiles checkout --quiet "$@"; then
      # Inform user about backup failure.
      abort "Error: Backup of existing files failed. Aborting dotfiles checkout."
    fi

    # Restore backup files.
    restore_backup "${backup_files}"
  fi
}

# Function for restoring backup files.
function restore_backup() {
  # Inform user about restore.
  log_message "Restoring conflicting files to ${DOTFILES_WORK_TREE_PATH}"

  # Create restore directory structure.
  printf "%s\n" "$1" \
    | xargs -I{} dirname "${DOTFILES_WORK_TREE_PATH}"/{} \
    | xargs -I{} mkdir -p {}

  # Move existing files to restore directory.
  printf "%s\n" "$1" \
    | xargs -I{} mv "${DOTFILES_BACKUP_PATH}"/{} "${DOTFILES_WORK_TREE_PATH}"/{}

  # Inform user about restored files.
  log_message "$(
    printf "%s\n" "$1" \
      | xargs -I{} printf "  %s\n" "${DOTFILES_WORK_TREE_PATH}"/{}
  )"

  # Remove backup directory.
  if ! is_set_and_not_false "${DOTFILES_KEEP_BACKUP}"; then
    # Inform user about removing backup directory.
    log_message "Removing backup directory ${DOTFILES_BACKUP_PATH}"

    # Remove backup directory.
    rm -rf "${DOTFILES_BACKUP_PATH}"
  fi
}

# Function for stashing changes.
function stash_changes() {
  # Stash changes to tracked files.
  my_dotfiles stash push --quiet --no-keep-index --message "$1"

  # Get reflog selector for this stash.
  local stash_reflog_selector
  stash_reflog_selector=$(get_stash_selector "$1")

  # Continue only if new stash was created.
  if [[ -n "${stash_reflog_selector}" ]]; then
    # Inform user about stashing changes.
    log_message "Stashing changes to $1"

    # Inform user about stashed files.
    log_message "$(
      my_dotfiles stash show --include-untracked --name-only "${stash_reflog_selector}" \
        | xargs -I{} printf "  %s\n" {}
    )"

    # Print instructions how to view stashed diff and how to unstash it.
    log_message "
Show stashed changes:
    dotfiles stash show --patch ${stash_reflog_selector}

Unstash changes:
    dotfiles stash apply ${stash_reflog_selector}
"
  fi
}

# Main function for cloning dotfiles repository.
function main() {
  # Setup logging for CI environment.
  log_commands

  # Clone dotfiles repository.
  clone_repository

  # Track remote branches.
  track_remote "${DOTFILES_ORIGIN}" "${DOTFILES_GIT_CLONE_URL}"

  # Checkout files (with backup and restore if needed).
  checkout_with_backup "${DOTFILES_CHECKOUT_BRANCH}"

  # Stash changes to any tracked files.
  stash_changes "${DOTFILES_BACKUP_NAME}"

  # Inform user about success.
  log_message "Succesfully cloned dotfiles repository"
}

# Set CI environment variable to false (if not set).
CI="${CI:-"false"}"

# Set QUIET flag to false (if not set).
DOTFILES_QUIET="${DOTFILES_QUIET:-"false"}"

# Set git clone arguments to first script argument.
DOTFILES_GIT_CLONE_URL="$1"

# Set path for git work tree directory (if not set).
DOTFILES_WORK_TREE_PATH="${DOTFILES_WORK_TREE_PATH:-"${HOME}"}"

# Set dotfiles project directory path (if not set).
DOTFILES_PROJECT_PATH="${DOTFILES_PROJECT_PATH:-"${DOTFILES_WORK_TREE_PATH}/.dotfiles"}"

# Set path for bare git repository (if not set).
DOTFILES_GIT_PATH="${DOTFILES_GIT_PATH:-"${DOTFILES_PROJECT_PATH}/.git"}"

# Set origin remote name (if not set).
DOTFILES_ORIGIN="${DOTFILES_ORIGIN:-"origin"}"

# Set branch name to be used during git clone command (if not set).
DOTFILES_CLONE_BRANCH="${DOTFILES_CLONE_BRANCH:-"init"}"

# Set branch name to checkout after cloned (if not set).
DOTFILES_CHECKOUT_BRANCH="${DOTFILES_CHECKOUT_BRANCH:-"main"}"

# Set backup path prefix (if not set).
DOTFILES_BACKUP_PREFIX="${DOTFILES_BACKUP_PREFIX:-"dotfiles_backup_"}"

# Set backup filename (if not set).
DOTFILES_BACKUP_NAME="${DOTFILES_BACKUP_NAME:-"${DOTFILES_BACKUP_PREFIX}$(date -u +"%Y%m%d%H%M%S")"}"

# Set backup path (if not set).
DOTFILES_BACKUP_PATH="${DOTFILES_BACKUP_PATH:-"${DOTFILES_WORK_TREE_PATH}/.${DOTFILES_BACKUP_NAME}"}"

# Set keep backup flag to false (if not set).
DOTFILES_KEEP_BACKUP="${DOTFILES_KEEP_BACKUP:-"false"}"

# Run main function if script is executed and not sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
